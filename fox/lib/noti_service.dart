import 'dart:io' show Platform;
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class NotiService {
  // Singleton — stessa istanza in tutta l'app
  static final NotiService _instance = NotiService._internal();
  factory NotiService() => _instance;
  NotiService._internal();

  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Coda per serializzare schedule/cancel ed evitare race tra chiamate concorrenti
  Future<void> _pending = Future.value();

  bool get isInitialized => _isInitialized;

  Future<void> initNotifications() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));

      // Android initialization
      const initSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization
      const initSettingIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: initSettingsAndroid,
        iOS: initSettingIOS,
      );

      // Request Android notification permission (API 33+)
      if (Platform.isAndroid) {
        final androidPlugin =
            notificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission();
      }

      await notificationsPlugin.initialize(initSettings);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize notifications: $e');
    }
  }

  NotificationDetails notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_channel_id',
        'Daily Notifications',
        channelDescription: 'Daily Notification Channel',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
  }) async {
    try {
      await notificationsPlugin.show(id, title, body, notificationDetails());
    } catch (e) {
      debugPrint('Failed to show notification: $e');
    }
  }

  /// Quanti giorni in avanti schedulare i promemoria a ogni chiamata.
  /// La finestra viene rinnovata a ogni apertura dell'app; 7 giorni coprono
  /// anche chi non riapre l'app per una settimana (21 notifiche, ben sotto
  /// il limite iOS di 64 pending).
  static const int _daysAhead = 7;

  /// Schedula i promemoria per i prossimi [_daysAhead] giorni.
  /// Se l'utente ha già valutato la giornata ([hasEntryToday]), quelle di
  /// oggi vengono saltate e si parte da domani, così il promemoria arriva
  /// anche se l'app non viene riaperta. Le notifiche sono schedulate con
  /// date esplicite (niente repeat su ora/minuto: su iOS quel trigger
  /// ignorerebbe il giorno e scatterebbe comunque oggi).
  ///
  /// Le stringhe localizzate vengono estratte sincronamente da [context]
  /// prima di qualsiasi operazione asincrona.
  Future<void> scheduleAllNotifications(BuildContext context, {required bool hasEntryToday}) {
    // Estraiamo le stringhe localizzate sincronamente prima degli await
    final l10n = AppLocalizations.of(context);

    // Serializziamo le chiamate: una schedulazione in corso deve completare
    // prima che una cancellazione (o ri-schedulazione) successiva esegua,
    // altrimenti cancelAll può intrecciarsi con gli zonedSchedule precedenti
    // lasciando notifiche attive anche a giornata già valutata.
    _pending = _pending.then((_) async {
      // Partiamo sempre da uno stato pulito, così la chiamata è idempotente
      await cancelNotificationsAll();

      if (l10n == null) {
        debugPrint('NotiService: AppLocalizations not available yet, skipping schedule');
        return;
      }

      final slots = [
        (hour: 18, minute: 0, body: l10n.notificationBody),
        (hour: 21, minute: 0, body: l10n.notificationBody1),
        (hour: 23, minute: 30, body: l10n.notificationBody2),
      ];

      // A giornata già valutata si parte da domani
      final firstDay = hasEntryToday ? 1 : 0;
      for (var day = firstDay; day < _daysAhead; day++) {
        for (var slot = 0; slot < slots.length; slot++) {
          final s = slots[slot];
          await _scheduleAt(day * slots.length + slot, day, s.hour, s.minute,
              l10n.notificationTitle, s.body);
        }
      }
    });
    return _pending;
  }

  /// Helper interno: schedula una notifica one-shot tra [daysFromNow] giorni
  /// alle [hour]:[minute]. Se l'orario risulta già passato (solo possibile
  /// con daysFromNow == 0) la salta.
  Future<void> _scheduleAt(
      int id, int daysFromNow, int hour, int minute, String title, String body) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = tz.TZDateTime(
          tz.local, now.year, now.month, now.day + daysFromNow, hour, minute);
      if (scheduledDate.isBefore(now)) return;

      await notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('Failed to schedule notification $id: $e');
    }
  }

  Future<void> cancelNotificationsAll() async {
    await notificationsPlugin.cancelAll();
  }

  Future<void> cancelNotifications() async {
    await notificationsPlugin.cancel(0);
  }

  Future<void> cancelNotifications1() async {
    await notificationsPlugin.cancel(1);
  }

  Future<void> cancelNotifications2() async {
    await notificationsPlugin.cancel(2);
  }
}

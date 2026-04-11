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

  /// Schedula o cancella le notifiche in base a [hasEntryToday].
  /// Se l'utente ha già valutato la giornata, tutte le notifiche vengono
  /// cancellate. Altrimenti vengono schedate normalmente.
  ///
  /// Le stringhe localizzate vengono estratte sincronamente da [context]
  /// prima di qualsiasi operazione asincrona.
  Future<void> scheduleAllNotifications(BuildContext context, {required bool hasEntryToday}) async {
    if (hasEntryToday) {
      // L'utente ha già valutato → cancella tutte le notifiche per oggi
      await cancelNotificationsAll();
      return;
    }

    // Estraiamo le stringhe localizzate sincronamente prima degli await
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      debugPrint('NotiService: AppLocalizations not available yet, skipping schedule');
      return;
    }

    await _scheduleAt(0, 18, 00, l10n.notificationTitle, l10n.notificationBody);
    await _scheduleAt(1, 21, 00, l10n.notificationTitle, l10n.notificationBody1);
    await _scheduleAt(2, 23, 30, l10n.notificationTitle, l10n.notificationBody2);
  }

  /// Helper interno: schedula una notifica per [hour]:[minute] senza bisogno di BuildContext.
  Future<void> _scheduleAt(int id, int hour, int minute, String title, String body) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
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

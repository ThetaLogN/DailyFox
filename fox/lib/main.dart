import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'package:daily_fox/noti_service.dart';
import 'package:daily_fox/widget_bitmap.dart';
import 'home_page.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:daily_fox/helpers/database_helper.dart';
import 'package:daily_fox/helpers/purchase_helper.dart';

//>^-^<
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await NotiService().initNotifications();
  await DatabaseHelper().cleanDuplicatedEntries();

  // Ascolta gli acquisti per tutta la vita dell'app: le transazioni consegnate
  // in ritardo vanno completate, altrimenti lo store le ripropone a ogni avvio.
  await PurchaseHelper.instance.init();

  // Load theme preference
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDark');
  if (isDark != null) {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // Pre-initialize widget shared preferences for App Group on first run/upgrade
  // Usa la versione come chiave per forzare la re-inizializzazione ad ogni aggiornamento
  const currentVersion = '1.0.5+16';
  final lastInitVersion = prefs.getString('widget_init_version');
  if (lastInitVersion != currentVersion) {
    try {
      // Se l'utente ha già dati salvati, usa quelli; altrimenti valori di default
      final existingRating = prefs.getInt('rating') ?? 7;
      final existingEmoji = prefs.getString('emoji') ?? '🦊';
      final existingKeyword = prefs.getString('keyword') ?? 'DailyFox';
      await WidgetService.saveAndUpdateWidget(
        rating: existingRating,
        emoji: existingEmoji,
        keyword: existingKeyword,
      );
      await prefs.setString('widget_init_version', currentVersion);
    } catch (e) {
      debugPrint('Error pre-initializing widget data: $e');
    }
  }

  // Initialize platform channel for widget
  WidgetChannelHandler.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('it'),
            Locale('fr'),
            Locale('de'),
            Locale('zh'),
            Locale('ru'),
            Locale('ja'),
            Locale('es'),
          ],
          title: 'DailyFox',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: currentMode,
          home: const HomePage(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class WidgetChannelHandler {
  static const platform = MethodChannel('com.example.dailyfox/widget');

  static void initialize() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'getWidgetBitmap') {
        final args = call.arguments as Map;
        final rating = args['rating'] as int? ?? 7;
        final animationPhase = args['animationPhase'] as int? ?? 0;

        final image = await widgetToImage(rating, animationPhase);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        return byteData!.buffer.asUint8List();
      }
      throw PlatformException(code: 'Unimplemented');
    });
  }
}

Future<void> saveRating(int rating) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('rating', rating);
}

Future<int> getRating() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('rating') ?? 7;
}

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

/// Colore base da cui Material genera l'intera palette.
///
/// Un solo punto: cambiarlo qui ritinge testi, interruttori, cursori e barre
/// di avanzamento di tutta l'app.
const Color _seedColor = Color(0xFFE8792B);

/// Arancio dei comandi.
///
/// Non si usa il `primary` generato da Material: partendo da un arancio vivo
/// lo scurisce fino al marrone per garantire il contrasto col bianco. Questo
/// resta arancione e tiene comunque 4,1:1 sul testo bianco.
const Color _primaryLight = Color(0xFFC2571B);
const Color _primaryDark = Color(0xFFFF9D5C);

/// Superfici quasi neutre.
///
/// Material tinge ogni superficie col seme: con un arancio saturo card e
/// dialog diventavano rosa. Qui resta un accenno di calore, non una tinta.
ColorScheme _scheme(Brightness brightness) {
  final base = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
  );

  if (brightness == Brightness.light) {
    return base.copyWith(
      primary: _primaryLight,
      onPrimary: Colors.white,
      surface: const Color(0xFFFCFBFA),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF7F5F3),
      surfaceContainer: const Color(0xFFF2F0ED),
      surfaceContainerHigh: const Color(0xFFECE9E6),
      surfaceContainerHighest: const Color(0xFFE6E3DF),
    );
  }

  return base.copyWith(
    primary: _primaryDark,
    onPrimary: const Color(0xFF3A1B05),
    surface: const Color(0xFF161514),
    surfaceContainerLowest: const Color(0xFF0F0E0D),
    surfaceContainerLow: const Color(0xFF1C1B19),
    surfaceContainer: const Color(0xFF201F1D),
    surfaceContainerHigh: const Color(0xFF2A2926),
    surfaceContainerHighest: const Color(0xFF353330),
  );
}

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
          // Colore base arancio: è già quello dell'app — la volpe, la card
          // dello slancio, il cursore del voto, la stella. L'indaco di prima
          // era un residuo, e faceva uscire testi viola nei punti che
          // ereditano `primary` senza chiederlo, come i TextButton.
          theme: ThemeData(
            colorScheme: _scheme(Brightness.light),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: _scheme(Brightness.dark),
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

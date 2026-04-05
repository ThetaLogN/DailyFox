import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:ui' as ui;
import 'package:DailyFox/noti_service.dart';
import 'package:DailyFox/widget_bitmap.dart';
import 'homePage.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Background entry point for WorkManager
/*void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    const platform = MethodChannel('com.example.dailyfox/widget');
    final prefs = await SharedPreferences.getInstance();
    final rating = prefs.getInt('rating') ?? 7;
    final animationPhase =
        (DateTime.now().millisecondsSinceEpoch ~/ 5000 % 6).toInt();

    try {
      final image = await widgetToImage(rating, animationPhase);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      await platform.invokeMethod('updateWidget', {
        'rating': rating,
        'animationPhase': animationPhase,
        'bitmap': bytes,
      });
    } catch (e) {
      debugPrint('Error updating widget: $e');
    }

    return true;
  });
}*/

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await NotiService().initNotifications();

  // Load theme preference
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDark');
  if (isDark != null) {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
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

import 'package:daily_fox/models/diary_entry.dart';
import 'package:daily_fox/widgets/monthly_stats_chart.dart';
import 'package:daily_fox/widgets/mood_chart.dart';
import 'package:daily_fox/widgets/weekday_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

List<DiaryEntry> _entries(int days) {
  final today = DateTime.now();
  return List.generate(days, (i) {
    final date = DateTime(today.year, today.month, today.day - i);
    return DiaryEntry(
      id: i,
      rating: 1 + (i % 10),
      emoji: '🦊',
      keyword: 'test',
      date: date.toIso8601String(),
      slancio: true,
    );
  });
}

Widget _host(Widget child, Locale locale) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        // Card stretta: è dove i traboccamenti si manifestano per primi, e le
        // etichette dei filtri cambiano lunghezza con la lingua.
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  // Un traboccamento del layout fa fallire il test: è la guardia che serve,
  // perché `flutter analyze` non lo vede e a occhio sfugge un pixel.
  group('Stats charts fit on a narrow screen', () {
    for (final entry in {
      'MoodChart': (List<DiaryEntry> e) => MoodChart(entries: e),
      'WeekdayChart': (List<DiaryEntry> e) => WeekdayChart(entries: e),
      'MonthlyStatsChart': (List<DiaryEntry> e) => MonthlyStatsChart(entries: e),
    }.entries) {
      testWidgets('${entry.key} renders in every locale', (tester) async {
        tester.view.physicalSize = const Size(320 * 3, 700 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        for (final locale in AppLocalizations.supportedLocales) {
          await tester.pumpWidget(_host(entry.value(_entries(40)), locale));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull,
              reason: '${entry.key} trabocca in ${locale.languageCode}');
        }
      });
    }

    testWidgets('they also render with no entries at all', (tester) async {
      for (final chart in [
        MoodChart(entries: const []),
        WeekdayChart(entries: const []),
        MonthlyStatsChart(entries: const []),
      ]) {
        await tester.pumpWidget(_host(chart, const Locale('it')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      }
    });
  });
}

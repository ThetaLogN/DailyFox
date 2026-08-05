import 'package:daily_fox/models/diary_entry.dart';
import 'package:daily_fox/widgets/year_heatmap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Entry finte distribuite all'indietro a partire da oggi.
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
      slancio: i.isEven,
    );
  });
}

Widget _host(List<DiaryEntry> entries, {Locale locale = const Locale('it')}) {
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
      body: SingleChildScrollView(child: YearHeatmap(entries: entries)),
    ),
  );
}

void main() {
  group('YearHeatmap', () {
    // Un grafico che sborda lancia in test: è la guardia più utile qui.
    testWidgets('renders a full year without overflowing', (tester) async {
      await tester.pumpWidget(_host(_entries(400)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(YearHeatmap), findsOneWidget);
    });

    testWidgets('renders with no entries at all', (tester) async {
      await tester.pumpWidget(_host([]));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('it'),
        theme: ThemeData.dark(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: YearHeatmap(entries: _entries(90))),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in every supported locale', (tester) async {
      for (final locale in AppLocalizations.supportedLocales) {
        await tester.pumpWidget(_host(_entries(60), locale: locale));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'overflow o eccezione in ${locale.languageCode}');
      }
    });

    test('shows a full year plus the current week', () {
      expect(YearHeatmap.weeks, 53);
    });
  });
}

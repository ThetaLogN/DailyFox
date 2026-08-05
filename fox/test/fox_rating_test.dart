import 'package:daily_fox/home_page.dart';
import 'package:daily_fox/models/diary_entry.dart';
import 'package:flutter_test/flutter_test.dart';

DiaryEntry _entry(String date, int rating) => DiaryEntry(
      rating: rating,
      emoji: '🦊',
      keyword: 'test',
      date: date,
      slancio: true,
    );

void main() {
  group('WidgetService.foxRatingFrom', () {
    test('averages only the last three ratings', () {
      // I primi due voti alti non devono pesare: contano 4, 6 e 8.
      final entries = [
        _entry('2026-07-20', 10),
        _entry('2026-07-21', 10),
        _entry('2026-07-22', 4),
        _entry('2026-07-23', 6),
        _entry('2026-07-24', 8),
      ];

      expect(WidgetService.foxRatingFrom(entries), 6);
    });

    test('uses everything available below three entries', () {
      expect(
        WidgetService.foxRatingFrom([
          _entry('2026-07-23', 3),
          _entry('2026-07-24', 6),
        ]),
        5, // 4.5 arrotondato
      );
    });

    test('a single entry is its own average', () {
      expect(WidgetService.foxRatingFrom([_entry('2026-07-24', 2)]), 2);
    });

    test('falls back to a neutral fox with no entries', () {
      expect(WidgetService.foxRatingFrom([]), 7);
    });

    test('rounds to the nearest whole rating', () {
      // 7 + 8 + 8 = 23 / 3 = 7.67 → 8
      final entries = [
        _entry('2026-07-22', 7),
        _entry('2026-07-23', 8),
        _entry('2026-07-24', 8),
      ];

      expect(WidgetService.foxRatingFrom(entries), 8);
    });

    // La finestra scorre sulla coda della lista, che il database restituisce
    // ordinata per data: una giornata recuperata a posteriori non deve
    // scavalcare quelle davvero recenti.
    test('reads the window from the end of a date-ordered list', () {
      final entries = [
        _entry('2026-07-01', 1), // recuperata dopo, ma vecchia
        _entry('2026-07-22', 9),
        _entry('2026-07-23', 9),
        _entry('2026-07-24', 9),
      ];

      expect(WidgetService.foxRatingFrom(entries), 9);
    });

    test('the window is three days', () {
      expect(WidgetService.foxAverageWindow, 3);
    });
  });
}

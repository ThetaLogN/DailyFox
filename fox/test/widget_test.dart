import 'package:flutter_test/flutter_test.dart';
import 'package:daily_fox/models/diary_entry.dart';
import 'package:daily_fox/models/badge.dart';
import 'package:daily_fox/helpers/badge_helper.dart';
import 'package:daily_fox/helpers/streak_helper.dart';

void main() {
  group('DiaryEntry Model Tests', () {
    test('should convert to Map correctly', () {
      final entry = DiaryEntry(
        id: 1,
        rating: 8,
        emoji: '🦊',
        keyword: 'felice',
        date: '2026-06-04',
        slancio: true,
      );

      final map = entry.toMap();

      expect(map['id'], 1);
      expect(map['rating'], 8);
      expect(map['emoji'], '🦊');
      expect(map['keyword'], 'felice');
      expect(map['date'], '2026-06-04');
      expect(map['slancio'], 1);
    });

    test('should construct from Map correctly', () {
      final map = {
        'id': 2,
        'rating': 5,
        'emoji': '😐',
        'keyword': 'normale',
        'date': '2026-06-03',
        'slancio': 0,
      };

      final entry = DiaryEntry.fromMap(map);

      expect(entry.id, 2);
      expect(entry.rating, 5);
      expect(entry.emoji, '😐');
      expect(entry.keyword, 'normale');
      expect(entry.date, '2026-06-03');
      expect(entry.slancio, false);
    });

    test('carries the photo file name through a map round-trip', () {
      final entry = DiaryEntry(
        id: 3,
        rating: 7,
        emoji: '🦊',
        keyword: 'mare',
        date: '2026-07-30',
        slancio: true,
        photoPath: '2026-07-30_1753900000000.jpg',
      );

      final restored = DiaryEntry.fromMap(entry.toMap());

      expect(entry.toMap()['photo_path'], '2026-07-30_1753900000000.jpg');
      expect(restored.photoPath, '2026-07-30_1753900000000.jpg');
    });

    // Le giornate senza foto sono la norma, non un caso d'errore: la colonna
    // esiste dalla versione 3 del database e sulle entry vecchie è NULL.
    test('a day without a photo stays null', () {
      final entry = DiaryEntry(
        rating: 5,
        emoji: '🙂',
        keyword: 'test',
        date: '2026-07-30',
        slancio: false,
      );

      expect(entry.photoPath, isNull);
      expect(entry.toMap()['photo_path'], isNull);
      expect(DiaryEntry.fromMap(entry.toMap()).photoPath, isNull);
    });

    test('reads an entry saved before the photo column existed', () {
      // Mappa senza la chiave `photo_path`, com'era prima della migrazione.
      final legacy = {
        'id': 9,
        'rating': 6,
        'emoji': '😐',
        'keyword': 'vecchia',
        'date': '2026-01-01',
        'slancio': 1,
      };

      expect(DiaryEntry.fromMap(legacy).photoPath, isNull);
    });

  });

  group('DailyBadge Model Tests', () {
    test('should convert to Map correctly', () {
      final badge = DailyBadge(
        id: 'streak_3',
        emoji: '🔥',
        name: 'Novizio',
        description: 'Raggiungi uno streak di 3 giorni',
        requiredStreak: 3,
        unlockCount: 1,
      );

      final map = badge.toMap();

      expect(map['id'], 'streak_3');
      expect(map['emoji'], '🔥');
      expect(map['name'], 'Novizio');
      expect(map['description'], 'Raggiungi uno streak di 3 giorni');
      expect(map['requiredStreak'], 3);
      expect(map['unlockCount'], 1);
      expect(badge.isUnlocked, true);
    });

    test('should construct from Map correctly', () {
      final map = {
        'id': 'streak_7',
        'emoji': '👑',
        'name': 'Settimanale',
        'description': 'Raggiungi uno streak di 7 giorni',
        'requiredStreak': 7,
        'unlockCount': 0,
      };

      final badge = DailyBadge.fromMap(map);

      expect(badge.id, 'streak_7');
      expect(badge.emoji, '👑');
      expect(badge.name, 'Settimanale');
      expect(badge.description, 'Raggiungi uno streak di 7 giorni');
      expect(badge.requiredStreak, 7);
      expect(badge.unlockCount, 0);
      expect(badge.isUnlocked, false);
    });

    test('copyWith should update fields correctly', () {
      final badge = DailyBadge(
        id: 'streak_3',
        emoji: '🔥',
        name: 'Novizio',
        description: 'Raggiungi uno streak di 3 giorni',
        requiredStreak: 3,
        unlockCount: 0,
      );

      final updated = badge.copyWith(unlockCount: 2);

      expect(updated.unlockCount, 2);
      expect(updated.isUnlocked, true);
      expect(updated.id, badge.id);
    });
  });

  group('Badge Milestone Ladder Tests', () {
    test('thresholds are the expected ascending ladder', () {
      final thresholds =
          BadgeHelper.allBadges.map((b) => b.requiredStreak).toList();

      expect(thresholds, [1, 3, 7, 14, 30, 60, 100, 150, 200, 250, 365]);
    });

    test('thresholds are strictly ascending', () {
      final thresholds =
          BadgeHelper.allBadges.map((b) => b.requiredStreak).toList();

      for (var i = 1; i < thresholds.length; i++) {
        expect(thresholds[i], greaterThan(thresholds[i - 1]));
      }
    });

    // La guardia che conta davvero: nessun utente deve restare mesi senza una
    // ricompensa, com'era col vecchio salto 100 → 365 (265 giorni).
    test('no milestone is more than 115 days after the previous one', () {
      final thresholds =
          BadgeHelper.allBadges.map((b) => b.requiredStreak).toList();

      for (var i = 1; i < thresholds.length; i++) {
        expect(thresholds[i] - thresholds[i - 1], lessThanOrEqualTo(115),
            reason: 'too long without a reward after ${thresholds[i - 1]} days');
      }
    });

    test('every badge has a unique id and emoji', () {
      final ids = BadgeHelper.allBadges.map((b) => b.id).toList();
      final emojis = BadgeHelper.allBadges.map((b) => b.emoji).toList();

      expect(ids.toSet().length, ids.length);
      expect(emojis.toSet().length, emojis.length);
    });

    test('nextBadge returns the closest locked milestone', () {
      expect(BadgeHelper.nextBadge(0)?.requiredStreak, 1);
      expect(BadgeHelper.nextBadge(100)?.requiredStreak, 150);
      expect(BadgeHelper.nextBadge(200)?.requiredStreak, 250);
      expect(BadgeHelper.nextBadge(365), isNull);
    });
  });

  group('progressToNextBadge Tests', () {
    test('measures progress from the last milestone reached', () {
      // 120 giorni: 20 su 50 nell'intervallo 100 → 150.
      expect(BadgeHelper.progressToNextBadge(120), closeTo(0.4, 0.001));
      // 260 giorni: 10 su 115 nell'intervallo 250 → 365.
      expect(BadgeHelper.progressToNextBadge(260), closeTo(10 / 115, 0.001));
    });

    test('resets to zero right after unlocking a badge', () {
      expect(BadgeHelper.progressToNextBadge(100), 0.0);
      expect(BadgeHelper.progressToNextBadge(250), 0.0);
    });

    test('behaves like absolute progress below the first milestone', () {
      expect(BadgeHelper.progressToNextBadge(0), 0.0);
    });

    test('is full once every badge is unlocked', () {
      expect(BadgeHelper.progressToNextBadge(365), 1.0);
      expect(BadgeHelper.progressToNextBadge(500), 1.0);
    });
  });

  group('Streak Freeze Tests', () {
    final today = DateTime(2026, 7, 26);

    /// Costruisce l'insieme dei giorni valutati a partire dagli offset
    /// (0 = oggi, 1 = ieri, ...) rispetto a [today].
    Set<String> rated(List<int> offsets) => offsets
        .map((o) => StreakHelper.dayKey(DateTime(2026, 7, 26 - o)))
        .toSet();

    test('counts an unbroken chain as before', () {
      final status = StreakHelper.fromRatedDays(rated([0, 1, 2, 3]), today);

      expect(status.days, 4);
      expect(status.isFrozen, false);
    });

    test('is not frozen when only today is still unrated', () {
      final status = StreakHelper.fromRatedDays(rated([1, 2, 3]), today);

      expect(status.days, 3);
      expect(status.isFrozen, false);
    });

    test('freezes the streak when yesterday was skipped', () {
      // Ieri (offset 1) manca: la catena sopravvive ma oggi è l'ultima chance.
      final status = StreakHelper.fromRatedDays(rated([2, 3, 4]), today);

      expect(status.days, 3);
      expect(status.isFrozen, true);
    });

    test('unfreezes and grows once today is rated', () {
      final status = StreakHelper.fromRatedDays(rated([0, 2, 3, 4]), today);

      expect(status.days, 4);
      expect(status.isFrozen, false);
    });

    test('loses the streak after two consecutive skipped days', () {
      // Ieri e l'altro ieri mancano entrambi.
      final status = StreakHelper.fromRatedDays(rated([3, 4, 5]), today);

      expect(status.days, 0);
      expect(status.isFrozen, false);
    });

    test('bridges a single gap inside the chain', () {
      // Il giorno 3 manca ma non spezza: 5 giorni valutati, il buco non conta.
      final status =
          StreakHelper.fromRatedDays(rated([0, 1, 2, 4, 5, 6]), today);

      expect(status.days, 6);
      expect(status.isFrozen, false);
    });

    test('stops at two consecutive gaps inside the chain', () {
      // I giorni 3 e 4 mancano entrambi: si conta solo fino al giorno 2.
      final status = StreakHelper.fromRatedDays(rated([0, 1, 2, 5, 6]), today);

      expect(status.days, 3);
      expect(status.isFrozen, false);
    });

    test('a frozen chain can still be bridged further back', () {
      // Ieri saltato (congelato) e un altro buco al giorno 4.
      final status = StreakHelper.fromRatedDays(rated([2, 3, 5, 6]), today);

      expect(status.days, 4);
      expect(status.isFrozen, true);
    });

    test('duplicate entries on the same day do not inflate the streak', () {
      final days = rated([0, 1, 2]);

      expect(StreakHelper.fromRatedDays(days, today).days, 3);
    });

    test('no rated days at all means no streak', () {
      final status = StreakHelper.fromRatedDays(<String>{}, today);

      expect(status.days, 0);
      expect(status.isFrozen, false);
    });

    test('crosses a month boundary correctly', () {
      final firstOfMonth = DateTime(2026, 8, 1);
      final days = {
        StreakHelper.dayKey(DateTime(2026, 8, 1)),
        StreakHelper.dayKey(DateTime(2026, 7, 31)),
        StreakHelper.dayKey(DateTime(2026, 7, 30)),
      };

      expect(StreakHelper.fromRatedDays(days, firstOfMonth).days, 3);
    });
  });
}

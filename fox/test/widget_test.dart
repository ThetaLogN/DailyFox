import 'package:flutter_test/flutter_test.dart';
import 'package:daily_fox/models/diary_entry.dart';
import 'package:daily_fox/models/badge.dart';

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
}

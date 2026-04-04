/// Rappresenta un badge sbloccabile in DailyFox.
class DailyBadge {
  final String id;
  final String emoji;
  final String name;
  final String description;
  final int requiredStreak;
  final int unlockCount;

  bool get isUnlocked => unlockCount > 0;

  DailyBadge({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
    required this.requiredStreak,
    this.unlockCount = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'emoji': emoji,
        'name': name,
        'description': description,
        'requiredStreak': requiredStreak,
        'unlockCount': unlockCount,
      };

  factory DailyBadge.fromMap(Map<String, dynamic> map) => DailyBadge(
        id: map['id'],
        emoji: map['emoji'],
        name: map['name'],
        description: map['description'],
        requiredStreak: map['requiredStreak'],
        unlockCount: map['unlockCount'] ?? (map['isUnlocked'] == true ? 1 : 0),
      );

  DailyBadge copyWith({int? unlockCount}) => DailyBadge(
        id: id,
        emoji: emoji,
        name: name,
        description: description,
        requiredStreak: requiredStreak,
        unlockCount: unlockCount ?? this.unlockCount,
      );
}

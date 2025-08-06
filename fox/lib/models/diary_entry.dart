class DiaryEntry {
  final int? id;
  final int rating;
  final String emoji;
  final String? keyword;
  final String date;
  final bool slancio;

  DiaryEntry({
    this.id,
    required this.rating,
    required this.emoji,
    required this.keyword,
    required this.date,
    required this.slancio,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rating': rating,
      'emoji': emoji,
      'keyword': keyword,
      'date': date,
      'slancio': slancio ? 1 : 0,
    };
  }

  factory DiaryEntry.fromMap(Map<String, dynamic> map) {
    return DiaryEntry(
      id: map['id'],
      rating: map['rating'],
      emoji: map['emoji'],
      keyword: map['keyword'],
      date: map['date'],
      slancio: map['slancio'] == 1,
    );
  }
}

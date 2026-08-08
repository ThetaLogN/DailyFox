class DiaryEntry {
  final int? id;
  final int rating;
  final String emoji;
  final String? keyword;
  final String date;
  final bool slancio;

  /// Nome del file della foto del giorno, non il percorso completo.
  ///
  /// Su iOS il contenitore dell'app cambia UUID a ogni aggiornamento: un
  /// percorso assoluto salvato oggi punterebbe al vuoto dopo il prossimo
  /// update. Il percorso si ricostruisce a ogni lettura con
  /// `PhotoHelper.resolve`.
  final String? photoPath;

  DiaryEntry({
    this.id,
    required this.rating,
    required this.emoji,
    required this.keyword,
    required this.date,
    required this.slancio,
    this.photoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rating': rating,
      'emoji': emoji,
      'keyword': keyword,
      'date': date,
      'slancio': slancio ? 1 : 0,
      'photo_path': photoPath,
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
      photoPath: map['photo_path'],
    );
  }
}

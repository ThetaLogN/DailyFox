import 'database_helper.dart';

/// Esito del calcolo dello slancio.
class StreakStatus {
  /// Giorni effettivamente valutati nella catena. I giorni congelati non
  /// contano nel totale, ma non lo azzerano.
  final int days;

  /// True quando la catena sopravvive solo grazie al congelamento: ieri è
  /// stato saltato e valutare oggi è l'ultima occasione per non perderla.
  final bool isFrozen;

  const StreakStatus({required this.days, required this.isFrozen});

  static const empty = StreakStatus(days: 0, isFrozen: false);
}

class StreakHelper {
  /// Chiave `YYYY-MM-DD` usata per confrontare i giorni ignorando l'orario.
  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Sposta [from] di [days] giorni restando a mezzanotte.
  /// Usa l'aritmetica sul campo `day` invece di `Duration` così l'ora legale
  /// (giorni da 23 o 25 ore) non fa scivolare la data.
  static DateTime _shift(DateTime from, int days) =>
      DateTime(from.year, from.month, from.day - days);

  /// Calcola lo slancio a partire dai giorni valutati (chiavi [dayKey]).
  ///
  /// Un singolo giorno saltato viene **congelato**: non conta nel totale ma
  /// non spezza la catena. Due giorni saltati di fila la spezzano.
  static StreakStatus fromRatedDays(Set<String> ratedDays, DateTime today) {
    if (ratedDays.isEmpty) return StreakStatus.empty;

    final start = DateTime(today.year, today.month, today.day);

    // Cerca il giorno valutato più recente entro la finestra di tolleranza:
    // offset 0 = oggi, 1 = ieri (oggi semplicemente non è ancora stato
    // valutato), 2 = l'altro ieri (ieri è saltato → catena congelata).
    // Oltre, i giorni saltati consecutivi sono due e lo slancio è perso.
    var offset = 0;
    while (offset <= 2 && !ratedDays.contains(dayKey(_shift(start, offset)))) {
      offset++;
    }
    if (offset > 2) return StreakStatus.empty;

    // Risale la catena dall'ancora, scavalcando i buchi di un solo giorno.
    var cursor = _shift(start, offset);
    var days = 0;
    while (ratedDays.contains(dayKey(cursor))) {
      days++;
      final previous = _shift(cursor, 1);
      if (ratedDays.contains(dayKey(previous))) {
        cursor = previous;
        continue;
      }
      final bridged = _shift(cursor, 2);
      if (ratedDays.contains(dayKey(bridged))) {
        cursor = bridged;
        continue;
      }
      break;
    }

    return StreakStatus(days: days, isFrozen: offset == 2);
  }

  /// Legge le entry con slancio dal database e ne calcola lo stato.
  static Future<StreakStatus> calculate() async {
    final entries = await DatabaseHelper().getAllEntriesWithSlancioTrue();
    final ratedDays = entries.map((e) => dayKey(DateTime.parse(e.date))).toSet();
    return fromRatedDays(ratedDays, DateTime.now());
  }
}

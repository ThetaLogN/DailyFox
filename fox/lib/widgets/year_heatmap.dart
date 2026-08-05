import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../models/diary_entry.dart';

/// Un anno di valutazioni in una griglia: una colonna per settimana, una riga
/// per giorno della settimana. Scorre in orizzontale e si apre sulla settimana
/// corrente.
///
/// La scala colore è **sequenziale a una tinta** (rosso, chiaro → scuro): il
/// voto è una grandezza, e una rampa arcobaleno la renderebbe illeggibile
/// perché il lettore non saprebbe quale colore viene "prima".
class YearHeatmap extends StatefulWidget {
  final List<DiaryEntry> entries;

  const YearHeatmap({super.key, required this.entries});

  /// Settimane mostrate: un anno pieno più la settimana in corso.
  static const int weeks = 53;

  @override
  State<YearHeatmap> createState() => _YearHeatmapState();
}

class _YearHeatmapState extends State<YearHeatmap> {
  static const double _cell = 12;
  static const double _gap = 3;
  static const double _column = _cell + _gap;

  /// Rampa chiara, dal voto più basso al più alto.
  ///
  /// Rosso a tinta singola, chiaro → scuro. Il fondo scala è a 2,20:1 sulla
  /// superficie: più chiaro di così si confonderebbe con le celle dei giorni
  /// non valutati, che è proprio l'equivoco da evitare.
  static const List<Color> _lightRamp = [
    Color(0xFFEA9695),
    Color(0xFFDD6866),
    Color(0xFFCF4645),
    Color(0xFFAB3130),
    Color(0xFF7F2120),
  ];

  /// Rampa scura: gli stessi gradini ri-scelti sulla superficie scura, non un
  /// ribaltamento automatico di quella chiara. Il fondo scala è a 2,15:1.
  static const List<Color> _darkRamp = [
    Color(0xFF93292A),
    Color(0xFFC03D3C),
    Color(0xFFE05C5B),
    Color(0xFFEC918F),
    Color(0xFFF4BCBB),
  ];

  static const Color _emptyLight = Color(0xFFEDECE8);
  static const Color _emptyDark = Color(0xFF2A2A28);

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Apre sulla settimana corrente: è quella che interessa.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  List<Color> _ramp(BuildContext context) =>
      _isDark(context) ? _darkRamp : _lightRamp;

  Color _emptyColor(BuildContext context) =>
      _isDark(context) ? _emptyDark : _emptyLight;

  /// Voto 1-10 → uno dei cinque passi, seguendo le stesse fasce delle etichette
  /// testuali dell'app (pessimo / brutto / nella media / buono / ottimo).
  Color _colorFor(BuildContext context, int rating) {
    final ramp = _ramp(context);
    if (rating <= 2) return ramp[0];
    if (rating <= 4) return ramp[1];
    if (rating <= 6) return ramp[2];
    if (rating <= 8) return ramp[3];
    return ramp[4];
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Il lunedì della settimana più vecchia mostrata.
  DateTime _gridStart(DateTime today) {
    final startOfToday = DateTime(today.year, today.month, today.day);
    final monday = startOfToday.subtract(
      Duration(days: startOfToday.weekday - DateTime.monday),
    );
    return DateTime(
      monday.year,
      monday.month,
      monday.day - (YearHeatmap.weeks - 1) * 7,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    final byDay = <String, DiaryEntry>{};
    for (final e in widget.entries) {
      byDay[_dayKey(DateTime.parse(e.date))] = e;
    }

    final today = DateTime.now();
    final start = _gridStart(today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWeekdayLabels(context, l10n),
            const SizedBox(width: 6),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMonthLabels(context, start),
                    const SizedBox(height: 4),
                    _buildGrid(context, byDay, start, today),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildLegend(context, l10n, cs),
      ],
    );
  }

  /// Solo lunedì, mercoledì e venerdì: etichettarli tutti e sette affollerebbe
  /// la colonna senza aggiungere informazione.
  Widget _buildWeekdayLabels(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    final formatter = DateFormat.E(l10n.localeName);
    // Un lunedì qualsiasi, serve solo a ricavare i nomi localizzati.
    final monday = DateTime(2026, 1, 5);

    return SizedBox(
      // Allinea con la griglia, che ha sopra le etichette dei mesi.
      height: 7 * _column + 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(height: 20),
          for (var i = 0; i < 7; i++)
            SizedBox(
              height: _column,
              child: i.isEven && i != 6
                  ? Text(
                      formatter.format(monday.add(Duration(days: i))),
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.1,
                        color: cs.onSurfaceVariant,
                      ),
                    )
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _buildMonthLabels(BuildContext context, DateTime start) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final formatter = DateFormat.MMM(l10n.localeName);

    final labels = <Widget>[];
    var lastMonth = -1;

    for (var week = 0; week < YearHeatmap.weeks; week++) {
      final monday = DateTime(start.year, start.month, start.day + week * 7);
      final isNewMonth = monday.month != lastMonth;
      lastMonth = monday.month;

      labels.add(SizedBox(
        width: _column,
        child: isNewMonth
            ? Text(
                formatter.format(monday),
                style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                overflow: TextOverflow.visible,
                softWrap: false,
              )
            : null,
      ));
    }

    return SizedBox(height: 16, child: Row(children: labels));
  }

  Widget _buildGrid(
    BuildContext context,
    Map<String, DiaryEntry> byDay,
    DateTime start,
    DateTime today,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final startOfToday = DateTime(today.year, today.month, today.day);
    final dateFormat = DateFormat.yMMMd(l10n.localeName);

    return Row(
      children: [
        for (var week = 0; week < YearHeatmap.weeks; week++)
          Column(
            children: [
              for (var day = 0; day < 7; day++)
                Builder(builder: (context) {
                  final date = DateTime(
                    start.year,
                    start.month,
                    start.day + week * 7 + day,
                  );
                  // I giorni futuri della settimana in corso non esistono.
                  if (date.isAfter(startOfToday)) {
                    return const SizedBox(width: _column, height: _column);
                  }

                  final entry = byDay[_dayKey(date)];
                  final isToday = date == startOfToday;

                  return Padding(
                    padding: const EdgeInsets.only(right: _gap, bottom: _gap),
                    child: Tooltip(
                      message: entry == null
                          ? '${dateFormat.format(date)} · ${l10n.heatmapNoEntry}'
                          : '${dateFormat.format(date)} · ${entry.rating}/10 ${entry.emoji}',
                      child: Container(
                        width: _cell,
                        height: _cell,
                        decoration: BoxDecoration(
                          color: entry == null
                              ? _emptyColor(context)
                              : _colorFor(context, entry.rating),
                          borderRadius: BorderRadius.circular(3),
                          border: isToday
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5,
                                )
                              : null,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
      ],
    );
  }

  Widget _buildLegend(
      BuildContext context, AppLocalizations l10n, ColorScheme cs) {
    final ramp = _ramp(context);

    Widget swatch(Color color) => Container(
          width: 11,
          height: 11,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        );

    final labelStyle = TextStyle(fontSize: 10, color: cs.onSurfaceVariant);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 14,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.heatmapLegendLow, style: labelStyle),
            const SizedBox(width: 6),
            for (final color in ramp) swatch(color),
            const SizedBox(width: 6),
            Text(l10n.heatmapLegendHigh, style: labelStyle),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch(_emptyColor(context)),
            const SizedBox(width: 6),
            Text(l10n.heatmapLegendEmpty, style: labelStyle),
          ],
        ),
      ],
    );
  }

}

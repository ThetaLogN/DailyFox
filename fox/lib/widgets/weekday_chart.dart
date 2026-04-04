import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../models/diary_entry.dart';

class WeekdayChart extends StatelessWidget {
  final List<DiaryEntry> entries;

  const WeekdayChart({super.key, required this.entries});

  /// Calcola rating medio per giorno della settimana.
  /// Indice 0 = Lunedì, 6 = Domenica (ISO weekday: 1=Mon, 7=Sun).
  List<({double avg, int count})> get _byWeekday {
    final sums = List.filled(7, 0.0);
    final counts = List.filled(7, 0);

    for (final e in entries) {
      final d = DateTime.tryParse(e.date);
      if (d == null) continue;
      final idx = d.weekday - 1; // 0=Mon, 6=Sun
      sums[idx] += e.rating;
      counts[idx]++;
    }

    return List.generate(7, (i) {
      final avg = counts[i] > 0 ? sums[i] / counts[i] : 0.0;
      return (avg: avg, count: counts[i]);
    });
  }

  int get _bestDayIndex {
    final data = _byWeekday;
    int best = 0;
    for (int i = 1; i < 7; i++) {
      if (data[i].avg > data[best].avg) best = i;
    }
    return data[best].count > 0 ? best : -1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final data = _byWeekday;
    final bestIdx = _bestDayIndex;
    final hasData = data.any((d) => d.count > 0);

    final dayLabels = _dayLabels(context);

    if (!hasData) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(
          l10n.statsNoData,
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        ),
      );
    }

    return Column(
      children: [
        ClipRect(
          child: SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
              maxY: 10,
              minY: 0,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 2,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          dayLabels[idx],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: idx == bestIdx
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: idx == bestIdx
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 2,
                    reservedSize: 28,
                    getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: false,
                    reservedSize: 8,
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIdx, rod, rodIdx) {
                    final d = data[group.x];
                    if (d.count == 0) return null;
                    return BarTooltipItem(
                      '${rod.toY.toStringAsFixed(1)}\n${d.count} ${l10n.statsEntries}',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
              barGroups: List.generate(7, (i) {
                final d = data[i];
                final isActive = d.count > 0;
                final isBest = i == bestIdx;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: d.avg,
                      color: isBest
                          ? cs.primary
                          : isActive
                              ? cs.primary.withValues(alpha: 0.4)
                              : cs.outlineVariant.withValues(alpha: 0.2),
                      width: 28,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6)),
                    ),
                  ],
                );
              }),
              ),
            ),
          ),
        ),
        if (bestIdx >= 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '${l10n.statsBestDayLabel}: ${_fullDayLabels(context)[bestIdx]} (${data[bestIdx].avg.toStringAsFixed(1)})',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<String> _dayLabels(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final labels = {
      'it': ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'],
      'es': ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'],
      'fr': ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'],
      'de': ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
      'ja': ['月', '火', '水', '木', '金', '土', '日'],
      'ru': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
      'zh': ['一', '二', '三', '四', '五', '六', '日'],
    };
    return labels[locale] ?? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  }

  List<String> _fullDayLabels(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final labels = {
      'it': ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'],
      'es': ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'],
      'fr': ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'],
      'de': ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'],
      'ja': ['月曜日', '火曜日', '水曜日', '木曜日', '金曜日', '土曜日', '日曜日'],
      'ru': ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'],
      'zh': ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'],
    };
    return labels[locale] ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  }
}

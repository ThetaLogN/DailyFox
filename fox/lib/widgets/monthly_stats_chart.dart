import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../models/diary_entry.dart';

class MonthlyStatsChart extends StatelessWidget {
  final List<DiaryEntry> entries;
  final int monthsBack;

  const MonthlyStatsChart({
    super.key,
    required this.entries,
    this.monthsBack = 12,
  });

  List<({String label, String key, double avg, int count})> get _monthlyData {
    final now = DateTime.now();
    final result = <({String label, String key, double avg, int count})>[];

    for (int i = monthsBack - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      final label = DateFormat('MMM\nyy').format(month);

      final monthEntries = entries.where((e) => e.date.startsWith(key)).toList();
      final avg = monthEntries.isEmpty
          ? 0.0
          : monthEntries.map((e) => e.rating).reduce((a, b) => a + b) /
              monthEntries.length;

      result.add((label: label, key: key, avg: avg, count: monthEntries.length));
    }
    return result;
  }

  int get _bestMonthIndex {
    final data = _monthlyData;
    int best = -1;
    for (int i = 0; i < data.length; i++) {
      if (data[i].count > 0 && (best == -1 || data[i].avg > data[best].avg)) {
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final data = _monthlyData;
    final bestIdx = _bestMonthIndex;
    final hasData = data.any((d) => d.count > 0);

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
        // Chart wrappato in ClipRect per evitare overflow laterale
        ClipRect(
          child: SizedBox(
            height: 200,
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
                      reservedSize: 36,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= data.length) return const SizedBox();
                        // Mostra etichette alternate per evitare sovrapposizioni
                        if (monthsBack > 6 && idx % 2 != 0) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            data[idx].label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
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
                      reservedSize: 12, // spazio extra per l'ultima barra
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, __) {
                      final d = data[group.x];
                      if (d.count == 0) return null;
                      final label = DateFormat('MMMM yyyy')
                          .format(DateTime.parse('${d.key}-01'));
                      return BarTooltipItem(
                        '$label\n${l10n.statsAverageRating}: ${rod.toY.toStringAsFixed(1)}\n${d.count} ${l10n.statsEntries}',
                        const TextStyle(color: Colors.white, fontSize: 11),
                      );
                    },
                  ),
                ),
                barGroups: List.generate(data.length, (i) {
                  final d = data[i];
                  final isEmpty = d.count == 0;
                  final isBest = i == bestIdx;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: d.avg,
                        // Larghezza ridotta per 12 mesi, più ampia per range brevi
                        width: monthsBack <= 6 ? 26 : 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        gradient: isEmpty
                            ? null
                            : LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isBest
                                    ? [cs.primary, cs.primary.withValues(alpha: 0.7)]
                                    : [
                                        cs.primary.withValues(alpha: 0.5),
                                        cs.primary.withValues(alpha: 0.2),
                                      ],
                              ),
                        color: isEmpty
                            ? cs.outlineVariant.withValues(alpha: 0.15)
                            : null,
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),

        // Badge mese migliore
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
                    '${l10n.statsBestDayLabel}: '
                    '${DateFormat('MMMM yyyy').format(DateTime.parse('${data[bestIdx].key}-01'))} '
                    '(${data[bestIdx].avg.toStringAsFixed(1)})',
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
}

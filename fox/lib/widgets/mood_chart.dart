import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../models/diary_entry.dart';

enum MoodChartRange { week, month, threeMonths }

class MoodChart extends StatefulWidget {
  final List<DiaryEntry> entries;

  const MoodChart({super.key, required this.entries});

  @override
  State<MoodChart> createState() => _MoodChartState();
}

class _MoodChartState extends State<MoodChart> {
  MoodChartRange _range = MoodChartRange.week;

  List<DiaryEntry> get _filteredEntries {
    final now = DateTime.now();
    final cutoff = switch (_range) {
      MoodChartRange.week => now.subtract(const Duration(days: 7)),
      MoodChartRange.month => now.subtract(const Duration(days: 30)),
      MoodChartRange.threeMonths => now.subtract(const Duration(days: 90)),
    };

    final filtered = widget.entries.where((e) {
      final d = DateTime.tryParse(e.date);
      return d != null && d.isAfter(cutoff);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return filtered;
  }

  double get _average {
    final entries = _filteredEntries;
    if (entries.isEmpty) return 0;
    return entries.map((e) => e.rating).reduce((a, b) => a + b) / entries.length;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final entries = _filteredEntries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Range selector
        Row(
          children: [
            _chip(l10n.statsWeekFilter, MoodChartRange.week, cs),
            const SizedBox(width: 8),
            _chip(l10n.statsMonthFilter, MoodChartRange.month, cs),
            const SizedBox(width: 8),
            _chip(l10n.statsThreeMonthFilter, MoodChartRange.threeMonths, cs),
            const Spacer(),
            if (entries.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${l10n.statsAverageRating}: ${_average.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Chart
        if (entries.isEmpty)
          _emptyState(l10n, cs)
        else
          SizedBox(
            height: 200,
            child: LineChart(
              _buildChartData(entries, cs),
              duration: const Duration(milliseconds: 400),
            ),
          ),
      ],
    );
  }

  Widget _chip(String label, MoodChartRange range, ColorScheme cs) {
    final selected = _range == range;
    return GestureDetector(
      onTap: () => setState(() => _range = range),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _emptyState(AppLocalizations l10n, ColorScheme cs) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      child: Text(
        l10n.statsNoData,
        textAlign: TextAlign.center,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
      ),
    );
  }

  LineChartData _buildChartData(List<DiaryEntry> entries, ColorScheme cs) {
    final spots = <FlSpot>[];
    for (var i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].rating.toDouble()));
    }

    return LineChartData(
      minY: 0,
      maxY: 10,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 2,
        getDrawingHorizontalLine: (v) => FlLine(
          color: cs.outlineVariant.withValues(alpha: 0.4),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
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
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: entries.length <= 14,
            reservedSize: 22,
            getTitlesWidget: (value, _) {
              final idx = value.toInt();
              if (idx < 0 || idx >= entries.length) return const SizedBox();
              final d = DateTime.tryParse(entries[idx].date);
              if (d == null) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat('d/M').format(d),
                  style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
            final idx = spot.x.toInt();
            final entry = (idx >= 0 && idx < entries.length) ? entries[idx] : null;
            return LineTooltipItem(
              entry != null ? '${entry.rating}' : spot.y.toStringAsFixed(1),
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            );
          }).toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          color: cs.primary,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: entries.length <= 30,
            getDotPainter: (spot, percent, bar, idx) => FlDotCirclePainter(
              radius: 4,
              color: cs.primary,
              strokeWidth: 2,
              strokeColor: cs.surface,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cs.primary.withValues(alpha: 0.25),
                cs.primary.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

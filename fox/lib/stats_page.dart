import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../helpers/database_helper.dart';
import '../models/diary_entry.dart';
import '../widgets/mood_chart.dart';
import '../widgets/keywords_chart.dart';
import '../widgets/emoji_chart.dart';
import '../widgets/weekday_chart.dart';
import '../widgets/monthly_stats_chart.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  List<DiaryEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await DatabaseHelper().getAllEntries();
    entries.sort((a, b) => a.date.compareTo(b.date));
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          l10n.statsPageTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outlineVariant),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEntries,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Riepilogo rapido
                  _buildSummaryRow(l10n, cs),
                  const SizedBox(height: 20),

                  // 1. Grafico andamento umore
                  _buildSection(
                    title: l10n.statsMoodTrend,
                    icon: Icons.show_chart,
                    color: cs.primary,
                    cs: cs,
                    child: MoodChart(entries: _entries),
                  ),
                  const SizedBox(height: 16),

                  // 2. Parole chiave più usate
                  _buildSection(
                    title: l10n.statsTopKeywords,
                    icon: Icons.label_outline,
                    color: const Color(0xFF6366F1),
                    cs: cs,
                    child: KeywordsChart(entries: _entries),
                  ),
                  const SizedBox(height: 16),

                  // 3. Emoji più usate
                  _buildSection(
                    title: l10n.statsTopEmojis,
                    icon: Icons.emoji_emotions_outlined,
                    color: const Color(0xFFEC4899),
                    cs: cs,
                    child: EmojiChart(entries: _entries),
                  ),
                  const SizedBox(height: 16),

                  // 4. Giorno migliore della settimana
                  _buildSection(
                    title: l10n.statsBestDay,
                    icon: Icons.calendar_today_outlined,
                    color: const Color(0xFF10B981),
                    cs: cs,
                    child: WeekdayChart(entries: _entries),
                  ),
                  const SizedBox(height: 16),

                  // 4. Confronto mensile
                  _buildSection(
                    title: l10n.statsMonthlyComparison,
                    icon: Icons.bar_chart,
                    color: const Color(0xFFF59E0B),
                    cs: cs,
                    child: MonthlyStatsChart(entries: _entries),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryRow(AppLocalizations l10n, ColorScheme cs) {
    final total = _entries.length;
    final avg = total > 0
        ? (_entries.map((e) => e.rating).reduce((a, b) => a + b) / total)
        : 0.0;

    // Keyword unica più usata
    final kwCounts = <String, int>{};
    for (final e in _entries) {
      final kw = (e.keyword ?? '').trim();
      if (kw.isNotEmpty) kwCounts[kw] = (kwCounts[kw] ?? 0) + 1;
    }
    final topKw = kwCounts.isEmpty
        ? '—'
        : (kwCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;

    return Row(
      children: [
        _summaryCard(Icons.my_library_books_rounded, total.toString(), l10n.statsEntries, cs),
        const SizedBox(width: 10),
        _summaryCard(Icons.star_rounded, avg.toStringAsFixed(1), l10n.statsAverageRating, cs),
        const SizedBox(width: 10),
        _summaryCard(Icons.abc_rounded, topKw, l10n.statsTopKeywords, cs),
      ],
    );
  }

  Widget _summaryCard(IconData iconData, String value, String label, ColorScheme cs) {
    return Expanded(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(iconData, size: 28, color: cs.primary),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: cs.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required ColorScheme cs,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

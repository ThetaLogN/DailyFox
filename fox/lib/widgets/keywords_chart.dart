import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../models/diary_entry.dart';

class KeywordsChart extends StatelessWidget {
  final List<DiaryEntry> entries;
  final int topN;

  const KeywordsChart({super.key, required this.entries, this.topN = 8});

  Map<String, int> get _topKeywords {
    final counts = <String, int>{};
    for (final e in entries) {
      final kw = (e.keyword ?? '').trim().toLowerCase();
      if (kw.isNotEmpty) counts[kw] = (counts[kw] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(topN));
  }

  static const List<Color> _palette = [
    Color(0xFF6366F1), // indigo
    Color(0xFFF59E0B), // amber
    Color(0xFF10B981), // emerald
    Color(0xFFEF4444), // red
    Color(0xFF8B5CF6), // violet
    Color(0xFF06B6D4), // cyan
    Color(0xFFF97316), // orange
    Color(0xFFEC4899), // pink
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final keywords = _topKeywords;

    if (keywords.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(
          l10n.statsNoKeywords,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        ),
      );
    }

    final maxCount = keywords.values.first;

    return Column(
      children: keywords.entries.indexed.map((record) {
        final i = record.$1;
        final entry = record.$2;
        final color = _palette[i % _palette.length];
        final frac = entry.value / maxCount;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              // Keyword chip
              SizedBox(
                width: 110,
                child: Text(
                  _capitalize(entry.key),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Progress bar
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: frac),
                    duration: Duration(milliseconds: 400 + i * 60),
                    curve: Curves.easeOut,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 10,
                      backgroundColor: cs.outlineVariant.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Conteggio
              Text(
                '${entry.value}×',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

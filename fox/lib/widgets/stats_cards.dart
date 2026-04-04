import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/diary_entry.dart';
import '../helpers/database_helper.dart';

/// Card statistica singola riutilizzabile.
class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String value;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 120,
        height: 160,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mostra 4 statistiche (valutazioni totali, media, mese corrente, migliore)
/// con una singola query al database.
class StatsCards extends StatelessWidget {
  const StatsCards({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<List<DiaryEntry>>(
      future: DatabaseHelper().getAllEntries(),
      builder: (context, snapshot) {
        // Valori di default finché i dati non arrivano
        final entries = snapshot.data ?? [];
        final now = DateTime.now();

        final total = entries.length;

        final avg = entries.isEmpty
            ? 0.0
            : entries.map((e) => e.rating).reduce((a, b) => a + b) /
                entries.length;

        final thisMonth = entries.where((e) {
          final d = DateTime.parse(e.date);
          return d.year == now.year && d.month == now.month;
        }).length;

        final best = entries.isEmpty
            ? 0
            : entries.map((e) => e.rating).reduce((a, b) => a > b ? a : b);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: l10n.valutazioni,
                      icon: Icons.star_rounded,
                      color: Colors.blue,
                      value: snapshot.hasData ? '$total' : '--',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: l10n.media,
                      icon: Icons.trending_up,
                      color: Colors.green,
                      value: snapshot.hasData && entries.isNotEmpty
                          ? avg.toStringAsFixed(1)
                          : '--',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: l10n.thisM,
                      icon: Icons.calendar_month,
                      color: Colors.orange,
                      value: snapshot.hasData ? '$thisMonth' : '--',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: l10n.best,
                      icon: Icons.emoji_events,
                      color: Colors.purple,
                      value: snapshot.hasData && entries.isNotEmpty
                          ? '$best'
                          : '--',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

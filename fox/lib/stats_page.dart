import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../helpers/database_helper.dart';
import '../helpers/home_sections.dart';
import '../models/diary_entry.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  List<DiaryEntry> _entries = [];
  bool _isLoading = true;

  /// Sezioni replicate nella schermata principale.
  Set<HomeSection> _inHome = {};

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await DatabaseHelper().getAllEntries();
    entries.sort((a, b) => a.date.compareTo(b.date));
    final inHome = await HomeSection.load();
    setState(() {
      _entries = entries;
      _inHome = inHome;
      _isLoading = false;
    });
  }

  Future<void> _setInHome(HomeSection section, bool value) async {
    await HomeSection.setEnabled(section, value);
    setState(() {
      value ? _inHome.add(section) : _inHome.remove(section);
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

                  // Una sezione per ogni voce del registro, nello stesso
                  // ordine in cui compaiono in home.
                  for (final section in HomeSection.values) ...[
                    _buildSection(section: section, cs: cs),
                    const SizedBox(height: 16),
                  ],

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
    required HomeSection section,
    required ColorScheme cs,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final title = section.title(l10n);
    final icon = section.icon;
    final color = section.accent;
    final child = section.build(_entries);

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
            const SizedBox(height: 4),
            _buildHomeToggle(section, cs, l10n),
          ],
        ),
      ),
    );
  }

  /// Replica la sezione nella schermata principale dell'app.
  Widget _buildHomeToggle(
      HomeSection section, ColorScheme cs, AppLocalizations l10n) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        l10n.sectionHomeToggle,
        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
      ),
      value: _inHome.contains(section),
      // Un solo colore per tutti gli interruttori: è un comando, non
      // un'informazione. L'accento della sezione identifica il grafico e
      // resta all'intestazione; usarlo anche qui farebbe sembrare i sei
      // interruttori sei cose diverse.
      activeColor: cs.primary,
      onChanged: (value) => _setInHome(section, value),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/diary_entry.dart';
import '../widgets/emoji_chart.dart';
import '../widgets/keywords_chart.dart';
import '../widgets/monthly_stats_chart.dart';
import '../widgets/mood_chart.dart';
import '../widgets/weekday_chart.dart';
import '../widgets/year_heatmap.dart';

/// Le sezioni della pagina statistiche che si possono replicare nella
/// schermata principale.
///
/// Registro unico: chiave di preferenza, titolo, icona, colore e widget stanno
/// insieme, così la pagina statistiche e la home non possono divergere.
/// Aggiungere una sezione significa aggiungere una voce qui, e basta.
enum HomeSection {
  year('show_year_heatmap'),
  mood('show_mood_chart'),
  keywords('show_keywords_chart'),
  emojis('show_emoji_chart'),
  weekday('show_weekday_chart'),
  monthly('show_monthly_chart');

  const HomeSection(this.prefKey);

  /// Chiave in SharedPreferences. Quella della griglia annuale è rimasta
  /// invariata: cambiarla azzererebbe la scelta di chi l'aveva già attivata.
  final String prefKey;

  String title(AppLocalizations l10n) => switch (this) {
        HomeSection.year => l10n.heatmapTitle,
        HomeSection.mood => l10n.statsMoodTrend,
        HomeSection.keywords => l10n.statsTopKeywords,
        HomeSection.emojis => l10n.statsTopEmojis,
        HomeSection.weekday => l10n.statsBestDay,
        HomeSection.monthly => l10n.statsMonthlyComparison,
      };

  IconData get icon => switch (this) {
        HomeSection.year => Icons.grid_on,
        HomeSection.mood => Icons.show_chart,
        HomeSection.keywords => Icons.label_outline,
        HomeSection.emojis => Icons.emoji_emotions_outlined,
        HomeSection.weekday => Icons.calendar_today_outlined,
        HomeSection.monthly => Icons.bar_chart,
      };

  /// Colore dell'intestazione. Identifica la sezione, non un valore: resta lo
  /// stesso in entrambe le schermate.
  Color get accent => switch (this) {
        HomeSection.year => const Color(0xFFCF4645),
        HomeSection.mood => const Color(0xFF6366F1),
        HomeSection.keywords => const Color(0xFF8B5CF6),
        HomeSection.emojis => const Color(0xFFEC4899),
        HomeSection.weekday => const Color(0xFF10B981),
        HomeSection.monthly => const Color(0xFFF59E0B),
      };

  Widget build(List<DiaryEntry> entries) => switch (this) {
        HomeSection.year => YearHeatmap(entries: entries),
        HomeSection.mood => MoodChart(entries: entries),
        HomeSection.keywords => KeywordsChart(entries: entries),
        HomeSection.emojis => EmojiChart(entries: entries),
        HomeSection.weekday => WeekdayChart(entries: entries),
        HomeSection.monthly => MonthlyStatsChart(entries: entries),
      };

  /// Le sezioni attivate per la home, osservabile.
  ///
  /// La home ci si aggancia direttamente invece di rileggere le preferenze al
  /// ritorno da una schermata: l'interruttore sta nelle statistiche, che si
  /// aprono dal calendario, e legare l'aggiornamento a un preciso percorso di
  /// navigazione lo rendeva fragile — bastava uscire in un altro modo perché
  /// la home restasse indietro fino al riavvio dell'app.
  static final ValueNotifier<Set<HomeSection>> enabledNotifier =
      ValueNotifier(<HomeSection>{});

  /// Legge le preferenze e aggiorna [enabledNotifier]. Da chiamare all'avvio.
  static Future<Set<HomeSection>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = HomeSection.values
        .where((s) => prefs.getBool(s.prefKey) ?? false)
        .toSet();
    enabledNotifier.value = enabled;
    return enabled;
  }

  static Future<void> setEnabled(HomeSection section, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(section.prefKey, value);

    // Nuovo insieme, non mutazione: ValueNotifier confronta per identità e
    // mutando quello esistente non notificherebbe nessuno.
    final next = Set<HomeSection>.from(enabledNotifier.value);
    value ? next.add(section) : next.remove(section);
    enabledNotifier.value = next;
  }
}

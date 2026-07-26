import 'package:flutter/foundation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/badge.dart';

class BadgeHelper {
  static const String _prefsKey = 'unlocked_badges';

  /// Tutti i badge con dati base (emoji, id, milestone).
  /// Name e description sono fallback in inglese — usare [localizedName] e
  /// [localizedDescription] per i testi localizzati.
  static List<DailyBadge> get allBadges => [
        DailyBadge(
          id: 'first_step',
          emoji: '🌱',
          name: 'First Step',
          description: 'You recorded your first momentum day!',
          requiredStreak: 1,
        ),
        DailyBadge(
          id: 'on_fire',
          emoji: '🔥',
          name: 'On Fire',
          description: '3 consecutive momentum days. You\'re doing great!',
          requiredStreak: 3,
        ),
        DailyBadge(
          id: 'rising_star',
          emoji: '⭐',
          name: 'Rising Star',
          description: 'A full week of momentum. Fantastic!',
          requiredStreak: 7,
        ),
        DailyBadge(
          id: 'consistent',
          emoji: '🌙',
          name: 'Consistent',
          description: 'Two consecutive weeks! Consistency is your strength.',
          requiredStreak: 14,
        ),
        DailyBadge(
          id: 'champion',
          emoji: '🏆',
          name: 'Champion',
          description: 'A full month of momentum! You\'re a true champion.',
          requiredStreak: 30,
        ),
        DailyBadge(
          id: 'diamond',
          emoji: '💎',
          name: 'Diamond',
          description: '60 consecutive days. You\'re as precious as a diamond!',
          requiredStreak: 60,
        ),
        DailyBadge(
          id: 'fox_elite',
          emoji: '🦊',
          name: 'Fox Elite',
          description: '100 momentum days! You\'ve entered the fox elite.',
          requiredStreak: 100,
        ),
        DailyBadge(
          id: 'unstoppable',
          emoji: '🌊',
          name: 'Unstoppable',
          description: '150 momentum days. Nothing can stop you!',
          requiredStreak: 150,
        ),
        DailyBadge(
          id: 'skyrocket',
          emoji: '🚀',
          name: 'Skyrocket',
          description: '200 momentum days. You\'re headed for the stars!',
          requiredStreak: 200,
        ),
        DailyBadge(
          id: 'mythic',
          emoji: '🔮',
          name: 'Mythic',
          description: '250 momentum days. Your streak is now the stuff of myth.',
          requiredStreak: 250,
        ),
        DailyBadge(
          id: 'legend',
          emoji: '👑',
          name: 'Legend',
          description: '365 momentum days. You are an absolute legend!',
          requiredStreak: 365,
        ),
      ];

  /// Restituisce il nome localizzato del badge dato il suo [id].
  static String localizedName(String id, AppLocalizations l10n) {
    switch (id) {
      case 'first_step':  return l10n.badgeNameFirstStep;
      case 'on_fire':     return l10n.badgeNameOnFire;
      case 'rising_star': return l10n.badgeNameRisingStar;
      case 'consistent':  return l10n.badgeNameConsistent;
      case 'champion':    return l10n.badgeNameChampion;
      case 'diamond':     return l10n.badgeNameDiamond;
      case 'fox_elite':   return l10n.badgeNameFoxElite;
      case 'unstoppable': return l10n.badgeNameUnstoppable;
      case 'skyrocket':   return l10n.badgeNameSkyrocket;
      case 'mythic':      return l10n.badgeNameMythic;
      case 'legend':      return l10n.badgeNameLegend;
      default:            return id;
    }
  }

  /// Restituisce la descrizione localizzata del badge dato il suo [id].
  static String localizedDescription(String id, AppLocalizations l10n) {
    switch (id) {
      case 'first_step':  return l10n.badgeDescFirstStep;
      case 'on_fire':     return l10n.badgeDescOnFire;
      case 'rising_star': return l10n.badgeDescRisingStar;
      case 'consistent':  return l10n.badgeDescConsistent;
      case 'champion':    return l10n.badgeDescChampion;
      case 'diamond':     return l10n.badgeDescDiamond;
      case 'fox_elite':   return l10n.badgeDescFoxElite;
      case 'unstoppable': return l10n.badgeDescUnstoppable;
      case 'skyrocket':   return l10n.badgeDescSkyrocket;
      case 'mythic':      return l10n.badgeDescMythic;
      case 'legend':      return l10n.badgeDescLegend;
      default:            return '';
    }
  }

  /// Carica i badge con lo stato di sblocco salvato nelle preferences.
  static Future<List<DailyBadge>> loadBadges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unlockedList = prefs.getStringList(_prefsKey) ?? [];

      final countMap = <String, int>{};
      for (final id in unlockedList) {
        countMap[id] = (countMap[id] ?? 0) + 1;
      }

      return allBadges.map((badge) {
        return badge.copyWith(unlockCount: countMap[badge.id] ?? 0);
      }).toList();
    } catch (e) {
      debugPrint('Error loading badges: $e');
      return allBadges;
    }
  }

  /// Controlla quali badge vengono sbloccati con il nuovo streak.
  /// Restituisce solo i badge **appena sbloccati**.
  static Future<List<DailyBadge>> checkAndUnlockBadges(int currentStreak) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unlockedList = prefs.getStringList(_prefsKey) ?? [];
      final newlyUnlocked = <DailyBadge>[];

      for (final badge in allBadges) {
        if (currentStreak == badge.requiredStreak) {
          unlockedList.add(badge.id);
          
          final currentCount = unlockedList.where((id) => id == badge.id).length;
          newlyUnlocked.add(badge.copyWith(unlockCount: currentCount));
        }
      }

      if (newlyUnlocked.isNotEmpty) {
        await prefs.setStringList(_prefsKey, unlockedList);
        debugPrint('New badges unlocked: ${newlyUnlocked.map((b) => b.id).join(', ')}');
      }

      return newlyUnlocked;
    } catch (e) {
      debugPrint('Error checking badges: $e');
      return [];
    }
  }

  /// Recupera i badge sui dati passati.
  /// Se l'utente aggiorna l'app e ha già un [currentStreak] alto, sblocca
  /// retroattivamente i badge che gli spettano ma che non aveva ancora
  /// (basandosi solo sullo slancio *attuale* e non quello storico).
  static Future<void> backfillBadges(int currentStreak) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unlockedList = prefs.getStringList(_prefsKey) ?? [];
      bool changed = false;

      for (final badge in allBadges) {
        if (currentStreak >= badge.requiredStreak && !unlockedList.contains(badge.id)) {
          unlockedList.add(badge.id);
          changed = true;
          debugPrint('Retroactively unlocked missing badge: ${badge.id}');
        }
      }

      if (changed) {
        await prefs.setStringList(_prefsKey, unlockedList);
      }
    } catch (e) {
      debugPrint('Error backfilling badges: $e');
    }
  }

  /// Il badge più vicino a essere sbloccato (dato lo streak corrente).
  static DailyBadge? nextBadge(int currentStreak) {
    final locked = allBadges.where((b) => b.requiredStreak > currentStreak);
    if (locked.isEmpty) return null;
    return locked.reduce((a, b) => a.requiredStreak < b.requiredStreak ? a : b);
  }

  /// Progresso (0..1) verso il prossimo badge, misurato dalla soglia del badge
  /// già raggiunto invece che da zero: così la barra avanza ogni giorno anche
  /// negli intervalli lunghi (es. 250 → 365).
  static double progressToNextBadge(int currentStreak) {
    final next = nextBadge(currentStreak);
    if (next == null) return 1.0;

    final reached = allBadges
        .where((b) => b.requiredStreak <= currentStreak)
        .fold<int>(0, (m, b) => b.requiredStreak > m ? b.requiredStreak : m);

    final span = next.requiredStreak - reached;
    if (span <= 0) return 1.0;

    return ((currentStreak - reached) / span).clamp(0.0, 1.0);
  }

  /// Reset completo (utile per debug/test).
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

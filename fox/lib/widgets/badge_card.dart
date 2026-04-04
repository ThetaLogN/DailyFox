import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../helpers/badge_helper.dart';
import '../models/badge.dart';

class BadgeCard extends StatelessWidget {
  final DailyBadge badge;
  final bool showDescription;

  const BadgeCard({
    super.key,
    required this.badge,
    this.showDescription = true,
  });

  Color get _cardColor => badge.isUnlocked ? _colorForId(badge.id) : Colors.grey.shade200;

  Color _colorForId(String id) {
    switch (id) {
      case 'first_step':  return Colors.green.shade100;
      case 'on_fire':     return Colors.orange.shade100;
      case 'rising_star': return Colors.yellow.shade100;
      case 'consistent':  return Colors.indigo.shade100;
      case 'champion':    return Colors.amber.shade100;
      case 'diamond':     return Colors.cyan.shade100;
      case 'fox_elite':   return Colors.deepOrange.shade100;
      case 'legend':      return Colors.purple.shade100;
      default:            return Colors.blue.shade100;
    }
  }

  Color get _accentColor => badge.isUnlocked ? _accentForId(badge.id) : Colors.grey.shade400;

  Color _accentForId(String id) {
    switch (id) {
      case 'first_step':  return Colors.green;
      case 'on_fire':     return Colors.deepOrange;
      case 'rising_star': return Colors.amber.shade700;
      case 'consistent':  return Colors.indigo;
      case 'champion':    return Colors.orange.shade800;
      case 'diamond':     return Colors.cyan.shade700;
      case 'fox_elite':   return Colors.deepOrange.shade700;
      case 'legend':      return Colors.purple;
      default:            return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final localizedName = badge.isUnlocked
        ? BadgeHelper.localizedName(badge.id, l10n)
        : '';
    final localizedDesc = BadgeHelper.localizedDescription(badge.id, l10n);

    return Card(
      elevation: badge.isUnlocked ? 3 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: badge.isUnlocked
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_cardColor, _cardColor.withValues(alpha: 0.6)],
                )
              : LinearGradient(
                  colors: [cs.surfaceContainerHighest, cs.surfaceContainerHighest],
                ),
          border: badge.isUnlocked
              ? Border.all(color: _accentColor.withValues(alpha: 0.4), width: 1.5)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Emoji con overlay lucchetto
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Text(
                    badge.emoji,
                    style: TextStyle(
                      fontSize: 44,
                      color: badge.isUnlocked ? null : Colors.transparent,
                      shadows: badge.isUnlocked
                          ? [Shadow(color: _accentColor.withValues(alpha: 0.3), blurRadius: 8)]
                          : null,
                    ),
                  ),
                  if (!badge.isUnlocked) ...[
                    Text(badge.emoji, style: TextStyle(fontSize: 44, color: Colors.grey.shade400)),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock, color: Colors.white, size: 22),
                    ),
                  ],
                  if (badge.unlockCount > 1)
                    Positioned(
                      top: -8,
                      right: -16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accentColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          'x${badge.unlockCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Nome badge
              Text(
                localizedName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: badge.isUnlocked ? _accentColor : cs.onSurfaceVariant,
                ),
              ),

              // Milestone
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badge.isUnlocked
                      ? _accentColor.withValues(alpha: 0.15)
                      : cs.outlineVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${badge.requiredStreak} ${badge.requiredStreak == 1 ? l10n.day : l10n.days}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badge.isUnlocked ? _accentColor : cs.onSurfaceVariant,
                  ),
                ),
              ),

              // Descrizione
              if (showDescription && badge.isUnlocked) ...[
                const SizedBox(height: 8),
                Text(
                  localizedDesc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

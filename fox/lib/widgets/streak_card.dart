import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Card animata che mostra lo streak giornaliero dell'utente.
/// La visibilità è guidata da [scaleAnimation] e [opacityAnimation].
class StreakCard extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;

  /// Lo slancio sopravvive solo grazie al giorno congelato: valutare oggi è
  /// l'ultima occasione per non perderlo.
  final bool isFrozen;

  final Animation<double> scaleAnimation;
  final Animation<double> opacityAnimation;
  final Animation<double> fireAnimation;

  const StreakCard({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
    required this.scaleAnimation,
    required this.opacityAnimation,
    required this.fireAnimation,
    this.isFrozen = false,
  });

  String _getStreakMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (isFrozen) return l10n.streakFrozenMessage;
    if (currentStreak == 0) return l10n.startS;
    if (currentStreak == 1) return l10n.first;
    if (currentStreak < 7) return l10n.continua;
    if (currentStreak < 30) return l10n.incredibile;
    return l10n.legend;
  }

  /// Blu/ciano quando lo slancio è congelato, arancio/rosso quando è vivo.
  List<Color> get _gradientColors => isFrozen
      ? [
          Colors.blue.withValues(alpha: 0.8),
          Colors.cyan.withValues(alpha: 0.6),
        ]
      : [
          Colors.orange.withValues(alpha: 0.8),
          Colors.red.withValues(alpha: 0.6),
        ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedBuilder(
        animation: Listenable.merge([scaleAnimation, opacityAnimation]),
        builder: (context, child) {
          if (opacityAnimation.value < 0.1) {
            return const SizedBox.shrink();
          }
          return Transform.scale(
            scale: scaleAnimation.value,
            child: Opacity(
              opacity: opacityAnimation.value,
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _gradientColors,
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.slancioDay,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      '$currentStreak',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      currentStreak == 1
                                          ? l10n.day
                                          : l10n.days,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (isFrozen) ...[
                                      const SizedBox(width: 8),
                                      const Text('❄️',
                                          style: TextStyle(fontSize: 20)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Record',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '$bestStreak',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStreakMessage(context),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';
import '../helpers/badge_helper.dart';
import '../models/badge.dart';

class BadgeUnlockDialog extends StatefulWidget {
  final DailyBadge badge;

  const BadgeUnlockDialog({super.key, required this.badge});

  @override
  State<BadgeUnlockDialog> createState() => _BadgeUnlockDialogState();
}

class _BadgeUnlockDialogState extends State<BadgeUnlockDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _emojiAnimation;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _emojiAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _confettiController.play();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final localizedName = BadgeHelper.localizedName(widget.badge.id, l10n);
    final localizedDesc = BadgeHelper.localizedDescription(widget.badge.id, l10n);
    final daysLabel = widget.badge.requiredStreak == 1 ? l10n.day : l10n.days;

    return Material(
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Dialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 16,
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.amber.shade50, Colors.orange.shade50],
                        ),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock_open, color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.badgeUnlocked,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
      
                          const SizedBox(height: 24),
      
                          // Emoji animata
                          Transform.scale(
                            scale: _emojiAnimation.value,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  widget.badge.emoji,
                                  style: const TextStyle(fontSize: 52),
                                ),
                              ),
                            ),
                          ),
      
                          const SizedBox(height: 20),
      
                          // Nome badge localizzato
                          Text(
                            localizedName,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
      
                          const SizedBox(height: 8),
      
                          // Milestone
                          Text(
                            '${widget.badge.requiredStreak} $daysLabel',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
      
                          const SizedBox(height: 12),
      
                          // Descrizione localizzata
                          Text(
                            localizedDesc,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: cs.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
      
                          const SizedBox(height: 28),
      
                          // Bottoni
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    final shareText = l10n.shareBadgeText(
                                      localizedName, 
                                      widget.badge.emoji, 
                                      widget.badge.requiredStreak
                                    );
                                    Share.share(shareText);
                                  },
                                  icon: const Icon(Icons.ios_share, size: 18),
                                  label: Text(
                                    l10n.shareBadgeButton,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.amber.shade700,
                                    side: BorderSide(color: Colors.amber.shade700, width: 2),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    l10n.badgeUnlockedButton,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Confetti explosion
          Padding(
            padding: const EdgeInsets.only(top: 150.0), // Approximate distance to the badge circle
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.2,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
                Colors.amber,
                Colors.red,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mostra i dialog di sblocco in sequenza.
Future<void> showBadgeUnlockDialogs(
    BuildContext context, List<DailyBadge> newBadges) async {
  for (final badge in newBadges) {
    if (!context.mounted) break;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => BadgeUnlockDialog(badge: badge),
    );
    await Future.delayed(const Duration(milliseconds: 300));
  }
}

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../helpers/purchase_helper.dart';

/// Dialog "offri un caffè allo sviluppatore".
///
/// Il prezzo mostrato viene sempre da `ProductDetails.price`, già formattato e
/// localizzato dallo store: scriverlo a mano sarebbe sbagliato fuori dall'area
/// euro.
class CoffeeDialog extends StatefulWidget {
  const CoffeeDialog({super.key});

  @override
  State<CoffeeDialog> createState() => _CoffeeDialogState();
}

class _CoffeeDialogState extends State<CoffeeDialog> {
  final PurchaseHelper _purchases = PurchaseHelper.instance;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _purchases.status.addListener(_onStatusChanged);
    _purchases.loadProduct();
  }

  void _onStatusChanged() {
    if (_purchases.status.value == CoffeeStatus.thanks) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _purchases.status.removeListener(_onStatusChanged);
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // Lo Stack si dimensiona sul primo figlio (la Column). Il confetti è
      // Positioned apposta: i figli posizionati non contribuiscono alla
      // dimensione dello Stack, e riceve così vincoli finiti. Lasciato libero
      // dentro AlertDialog.content il suo LayoutBuilder pretenderebbe altezza
      // infinita e il dialog non si disegnerebbe affatto.
      content: Stack(
        alignment: Alignment.topCenter,
        children: [
          ValueListenableBuilder<CoffeeStatus>(
            valueListenable: _purchases.status,
            builder: (context, status, _) {
              return status == CoffeeStatus.thanks
                  ? _buildThanks(context, l10n)
                  : _buildOffer(context, l10n, status);
            },
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                particleDrag: 0.05,
                emissionFrequency: 0.05,
                numberOfParticles: 30,
                gravity: 0.2,
                shouldLoop: false,
                colors: const [
                  Colors.brown,
                  Colors.orange,
                  Colors.amber,
                  Colors.deepOrange,
                  Colors.pink,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffer(
      BuildContext context, AppLocalizations l10n, CoffeeStatus status) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('☕', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text(
          l10n.coffeeTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.coffeeDialogBody,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _buildAction(context, l10n, status),
      ],
    );
  }

  /// Riquadro di avviso usato dagli stati "non disponibile" ed "errore".
  /// Un messaggio dentro un contenitore tenue si legge meglio del solo testo
  /// rosso in mezzo al dialog, e non allarma più del necessario.
  Widget _buildNotice(
    BuildContext context, {
    required IconData icon,
    required String message,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(
      BuildContext context, AppLocalizations l10n, CoffeeStatus status) {
    final cs = Theme.of(context).colorScheme;

    switch (status) {
      case CoffeeStatus.loading:
      case CoffeeStatus.pending:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(),
        );

      case CoffeeStatus.unavailable:
        return _buildNotice(
          context,
          icon: Icons.info_outline,
          message: l10n.coffeeUnavailable,
          background: cs.surfaceContainerHighest,
          foreground: cs.onSurfaceVariant,
        );

      case CoffeeStatus.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNotice(
              context,
              icon: Icons.error_outline,
              message: l10n.coffeeError,
              background: cs.errorContainer,
              foreground: cs.onErrorContainer,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _purchases.reset,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.coffeeRetry),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: Colors.brown,
                  side: BorderSide(
                    color: Colors.brown.withValues(alpha: 0.4),
                  ),
                  // Stessa forma a pillola del bottone d'acquisto, così i due
                  // stati del dialog non sembrano disegnati da mani diverse.
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );

      case CoffeeStatus.ready:
      case CoffeeStatus.thanks:
        return ValueListenableBuilder<ProductDetails?>(
          valueListenable: _purchases.product,
          builder: (context, product, _) {
            if (product == null) {
              return const SizedBox.shrink();
            }
            return SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _purchases.buyCoffee,
                icon: const Icon(Icons.coffee),
                // Il prezzo arriva localizzato dallo store.
                label: Text('${l10n.coffeeButton}  ·  ${product.price}'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.brown,
                  foregroundColor: Colors.white,
                ),
              ),
            );
          },
        );
    }
  }

  Widget _buildThanks(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🦊', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text(
          l10n.coffeeThanksTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.coffeeThanksBody,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.dialogButtonOK),
        ),
        // Il caffè è consumabile: si può offrire quante volte si vuole.
        // `reset` riporta il dialog al bottone d'acquisto senza chiuderlo.
        TextButton.icon(
          onPressed: _purchases.reset,
          icon: const Icon(Icons.coffee, size: 18),
          label: Text(l10n.coffeeAgainButton),
        ),
      ],
    );
  }
}

/// Apre il dialog del caffè.
Future<void> showCoffeeDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (_) => const CoffeeDialog(),
  );
}

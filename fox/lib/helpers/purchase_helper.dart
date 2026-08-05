import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Id del prodotto consumabile "offri un caffè".
///
/// Tutto minuscolo e in reverse-DNS: Google Play rifiuta gli id con maiuscole,
/// Apple li accetta comunque. Deve combaciare con quello creato su App Store
/// Connect e Play Console, altrimenti lo store non restituisce nulla.
const String coffeeProductId = 'com.giorgiomartucci.dailyfox.coffee';

/// Chiave SharedPreferences: quanti caffè ha già offerto l'utente.
const String coffeeCountKey = 'coffee_count';

enum CoffeeStatus {
  /// Prodotto in caricamento dallo store.
  loading,

  /// Prodotto disponibile, si può acquistare.
  ready,

  /// Store non raggiungibile o prodotto non configurato.
  unavailable,

  /// Acquisto in corso (foglio di pagamento aperto, o "chiedi di acquistare").
  pending,

  /// Acquisto andato a buon fine.
  thanks,

  /// Acquisto fallito. L'annullamento dell'utente non finisce qui.
  error,
}

/// Superficie minima dello store usata da [PurchaseHelper].
///
/// Esiste solo per poter iniettare un fake nei test: [InAppPurchase] ha un
/// costruttore privato e non è sostituibile.
abstract class StoreGateway {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Future<bool> buyConsumable({required PurchaseParam purchaseParam});
  Future<void> completePurchase(PurchaseDetails purchase);
}

/// Implementazione reale, che delega al plugin.
class _PluginStoreGateway implements StoreGateway {
  final InAppPurchase _iap = InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _iap.queryProductDetails(identifiers);

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam}) =>
      _iap.buyConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);
}

/// Gestisce l'acquisto consumabile "offri un caffè".
///
/// Non c'è nulla da sbloccare, quindi niente verifica della ricevuta lato
/// server e niente ripristino acquisti: il caffè è una mancia, non un
/// contenuto.
class PurchaseHelper {
  PurchaseHelper({StoreGateway? gateway})
      : _store = gateway ?? _PluginStoreGateway();

  static final PurchaseHelper instance = PurchaseHelper();

  final StoreGateway _store;

  /// Stato osservabile dalla UI, sullo stile di `themeNotifier` in main.dart.
  final ValueNotifier<CoffeeStatus> status =
      ValueNotifier(CoffeeStatus.loading);

  /// Dettagli del prodotto: da qui si legge il prezzo **già localizzato dallo
  /// store**. Non va mai scritto a mano nel codice.
  final ValueNotifier<ProductDetails?> product = ValueNotifier(null);

  /// Quanti caffè ha offerto l'utente in totale.
  final ValueNotifier<int> coffeeCount = ValueNotifier(0);

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// True tra la pressione del bottone e l'esito.
  ///
  /// Serve a distinguere l'acquisto appena avviato dall'utente da una vecchia
  /// transazione che lo store ripropone all'avvio: solo il primo deve far
  /// comparire il ringraziamento, altrimenti il dialog resterebbe bloccato lì
  /// e il caffè non sarebbe più riacquistabile.
  bool _awaitingPurchase = false;

  /// Da chiamare in `main()` prima di `runApp`.
  ///
  /// L'ascolto dura quanto l'app, non quanto il dialog: una transazione
  /// consegnata in ritardo (pagamento interrotto, "chiedi di acquistare"
  /// approvato più tardi) arriva all'avvio successivo, e se nessuno la completa
  /// lo store continua a riconsegnarla a ogni lancio, per sempre.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    coffeeCount.value = prefs.getInt(coffeeCountKey) ?? 0;

    _subscription = _store.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (Object e) {
        debugPrint('Purchase stream error: $e');
        status.value = CoffeeStatus.error;
      },
    );
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          status.value = CoffeeStatus.pending;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (_awaitingPurchase) {
            // Caffè appena offerto: conta e ringrazia.
            _awaitingPurchase = false;
            await _registerCoffee();
            status.value = CoffeeStatus.thanks;
          } else if (purchase.status == PurchaseStatus.purchased) {
            // Pagamento differito ("chiedi di acquistare") approvato mentre
            // l'app era chiusa: è denaro reale, va contato. Niente dialog da
            // aggiornare, però: qui non c'è nessuna schermata aperta.
            await _registerCoffee();
          } else {
            // Vecchia transazione riproposta dallo store: va solo completata.
            debugPrint('Replayed coffee transaction, ignored');
          }
        case PurchaseStatus.error:
          _awaitingPurchase = false;
          debugPrint('Purchase error: ${purchase.error}');
          status.value = CoffeeStatus.error;
        case PurchaseStatus.canceled:
          // L'utente ha chiuso il foglio di pagamento: non è un errore da
          // mostrare, si torna semplicemente al bottone.
          _awaitingPurchase = false;
          status.value =
              product.value != null ? CoffeeStatus.ready : CoffeeStatus.unavailable;
      }

      // Chiude ogni transazione conclusa, qualunque sia l'esito.
      //
      // Volutamente NON si guarda `pendingCompletePurchase`: con StoreKit 2 il
      // plugin lo definisce come `status == purchased`, quindi resta falso per
      // le transazioni `restored`. Fidarsene le lascerebbe aperte per sempre, e
      // una transazione aperta viene riconsegnata al posto di un nuovo
      // acquisto: il foglio di pagamento non comparirebbe mai più.
      if (purchase.status != PurchaseStatus.pending) {
        try {
          await _store.completePurchase(purchase);
        } catch (e) {
          debugPrint('Error completing purchase: $e');
        }
      }
    }
  }

  Future<void> _registerCoffee() async {
    final prefs = await SharedPreferences.getInstance();
    final updated = (prefs.getInt(coffeeCountKey) ?? 0) + 1;
    await prefs.setInt(coffeeCountKey, updated);
    coffeeCount.value = updated;
  }

  /// Interroga lo store per il prodotto. Da chiamare all'apertura del dialog.
  Future<void> loadProduct() async {
    // Riparte sempre da zero: il caffè è consumabile, riaprendo il dialog si
    // deve poter offrire di nuovo invece di rivedere il ringraziamento.
    status.value = CoffeeStatus.loading;

    try {
      if (!await _store.isAvailable()) {
        status.value = CoffeeStatus.unavailable;
        return;
      }

      final response = await _store.queryProductDetails({coffeeProductId});

      if (response.productDetails.isEmpty) {
        // Prodotto non configurato sullo store, non ancora propagato, oppure
        // manca il contratto Paid Apps su App Store Connect.
        debugPrint('Coffee product not found: ${response.notFoundIDs}');
        status.value = CoffeeStatus.unavailable;
        return;
      }

      product.value = response.productDetails.first;
      status.value = CoffeeStatus.ready;
    } catch (e) {
      debugPrint('Error loading coffee product: $e');
      status.value = CoffeeStatus.unavailable;
    }
  }

  /// Avvia l'acquisto. L'esito arriva su [status] tramite il purchaseStream.
  Future<void> buyCoffee() async {
    final details = product.value;
    if (details == null) return;

    try {
      _awaitingPurchase = true;
      status.value = CoffeeStatus.pending;
      // Consumabile: `autoConsume` resta al default true così Android lo
      // consuma da sé e il caffè si può offrire più di una volta.
      await _store.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
    } catch (e) {
      _awaitingPurchase = false;
      debugPrint('Error buying coffee: $e');
      status.value = CoffeeStatus.error;
    }
  }

  /// Riporta il dialog allo stato acquistabile dopo un errore.
  void reset() {
    status.value =
        product.value != null ? CoffeeStatus.ready : CoffeeStatus.unavailable;
  }

  void dispose() {
    _subscription?.cancel();
  }
}

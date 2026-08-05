import 'dart:async';

import 'package:daily_fox/helpers/purchase_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Store finto pilotabile dai test.
class FakeStore implements StoreGateway {
  FakeStore({this.available = true, this.productFound = true});

  final bool available;
  final bool productFound;

  final _controller = StreamController<List<PurchaseDetails>>.broadcast();
  final List<PurchaseDetails> completed = [];
  int buyCalls = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
      Set<String> identifiers) async {
    if (!productFound) {
      return ProductDetailsResponse(
        productDetails: [],
        notFoundIDs: identifiers.toList(),
      );
    }
    return ProductDetailsResponse(
      productDetails: [
        ProductDetails(
          id: coffeeProductId,
          title: 'Un caffè',
          description: 'Offri un caffè allo sviluppatore',
          price: '1,99 €',
          rawPrice: 1.99,
          currencyCode: 'EUR',
        ),
      ],
      notFoundIDs: [],
    );
  }

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam}) async {
    buyCalls++;
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
  }

  /// Simula una consegna dallo store.
  void deliver(PurchaseDetails purchase) => _controller.add([purchase]);

  Future<void> dispose() => _controller.close();
}

PurchaseDetails _purchase(
  PurchaseStatus status, {
  bool pendingComplete = true,
}) {
  return PurchaseDetails(
    productID: coffeeProductId,
    verificationData: PurchaseVerificationData(
      localVerificationData: '',
      serverVerificationData: '',
      source: 'test',
    ),
    transactionDate: null,
    status: status,
  )..pendingCompletePurchase = pendingComplete;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PurchaseHelper', () {
    test('loads the product and exposes the store-localized price', () async {
      final store = FakeStore();
      final helper = PurchaseHelper(gateway: store);
      await helper.init();

      await helper.loadProduct();

      expect(helper.status.value, CoffeeStatus.ready);
      expect(helper.product.value?.price, '1,99 €');
      await store.dispose();
    });

    test('reports unavailable when the product is not configured', () async {
      final store = FakeStore(productFound: false);
      final helper = PurchaseHelper(gateway: store);
      await helper.init();

      await helper.loadProduct();

      expect(helper.status.value, CoffeeStatus.unavailable);
      expect(helper.product.value, isNull);
      await store.dispose();
    });

    test('reports unavailable when the store is unreachable', () async {
      final store = FakeStore(available: false);
      final helper = PurchaseHelper(gateway: store);
      await helper.init();

      await helper.loadProduct();

      expect(helper.status.value, CoffeeStatus.unavailable);
      await store.dispose();
    });

    // Il test che conta: una transazione mai completata viene riconsegnata
    // dallo store a ogni avvio dell'app, per sempre.
    test('always completes a delivered purchase', () async {
      final store = FakeStore();
      final helper = PurchaseHelper(gateway: store);
      await helper.init();
      await helper.loadProduct();

      await helper.buyCoffee();
      store.deliver(_purchase(PurchaseStatus.purchased));
      await pumpEventQueue();

      expect(store.completed, hasLength(1));
      expect(helper.status.value, CoffeeStatus.thanks);
      await store.dispose();
    });

    test('completes even a failed purchase', () async {
      final store = FakeStore();
      final helper = PurchaseHelper(gateway: store);
      await helper.init();

      store.deliver(_purchase(PurchaseStatus.error));
      await pumpEventQueue();

      expect(store.completed, hasLength(1));
      expect(helper.status.value, CoffeeStatus.error);
      await store.dispose();
    });

    test('counts every coffee so it can be offered again', () async {
      final store = FakeStore();
      final helper = PurchaseHelper(gateway: store);
      await helper.init();

      store.deliver(_purchase(PurchaseStatus.purchased));
      await pumpEventQueue();
      store.deliver(_purchase(PurchaseStatus.purchased));
      await pumpEventQueue();

      expect(helper.coffeeCount.value, 2);
      expect(
        SharedPreferences.getInstance()
            .then((p) => p.getInt(coffeeCountKey)),
        completion(2),
      );
      await store.dispose();
    });

    test('a cancelled payment is not surfaced as an error', () async {
      final store = FakeStore();
      final helper = PurchaseHelper(gateway: store);
      await helper.init();
      await helper.loadProduct();

      store.deliver(_purchase(PurchaseStatus.canceled));
      await pumpEventQueue();

      expect(helper.status.value, CoffeeStatus.ready);
      await store.dispose();
    });

    test('a pending purchase keeps the dialog waiting', () async {
      final store = FakeStore();
      final helper = PurchaseHelper(gateway: store);
      await helper.init();

      store.deliver(_purchase(PurchaseStatus.pending, pendingComplete: false));
      await pumpEventQueue();

      expect(helper.status.value, CoffeeStatus.pending);
      expect(store.completed, isEmpty);
      await store.dispose();
    });

    test('buyCoffee does nothing until the product is loaded', () async {
      final store = FakeStore();
      final helper = PurchaseHelper(gateway: store);
      await helper.init();

      await helper.buyCoffee();

      expect(store.buyCalls, 0);
      await store.dispose();
    });

    test('buyCoffee starts the purchase once the product is ready', () async {
      final store = FakeStore();
      final helper = PurchaseHelper(gateway: store);
      await helper.init();
      await helper.loadProduct();

      await helper.buyCoffee();

      expect(store.buyCalls, 1);
      expect(helper.status.value, CoffeeStatus.pending);
      await store.dispose();
    });

    test('reopening the dialog makes the coffee buyable again', () async {
      final store = FakeStore();
      final helper = PurchaseHelper(gateway: store);
      await helper.init();
      await helper.loadProduct();

      await helper.buyCoffee();
      store.deliver(_purchase(PurchaseStatus.purchased));
      await pumpEventQueue();
      expect(helper.status.value, CoffeeStatus.thanks);

      // Riapertura del dialog: il consumabile va riofferto, non si deve
      // restare bloccati sul ringraziamento.
      await helper.loadProduct();

      expect(helper.status.value, CoffeeStatus.ready);
      await store.dispose();
    });

    // Lo store ripropone le vecchie transazioni all'avvio. Se venissero
    // scambiate per un nuovo caffè, il dialog si aprirebbe già ringraziando e
    // il caffè non sarebbe più offribile.
    test('a replayed transaction does not fake a new purchase', () async {
      final store = FakeStore();
      final helper = PurchaseHelper(gateway: store);
      await helper.init();
      await helper.loadProduct();

      store.deliver(_purchase(PurchaseStatus.restored));
      await pumpEventQueue();

      expect(helper.status.value, CoffeeStatus.ready);
      expect(helper.coffeeCount.value, 0);
      expect(store.completed, hasLength(1));
      await store.dispose();
    });

    // Con StoreKit 2 `pendingCompletePurchase` è vero solo per `purchased`:
    // fidarsene lascerebbe le transazioni `restored` aperte per sempre, e una
    // transazione aperta viene riconsegnata al posto di un nuovo acquisto.
    test('completes a transaction even when it claims nothing is pending',
        () async {
      final store = FakeStore();
      final helper = PurchaseHelper(gateway: store);
      await helper.init();

      store.deliver(
          _purchase(PurchaseStatus.restored, pendingComplete: false));
      await pumpEventQueue();

      expect(store.completed, hasLength(1));
      await store.dispose();
    });

    test('a restore following a real tap is thanked', () async {
      final store = FakeStore();
      final helper = PurchaseHelper(gateway: store);
      await helper.init();
      await helper.loadProduct();

      await helper.buyCoffee();
      // Lo StoreKit di test riporta l'acquisto appena fatto come `restored`.
      store.deliver(_purchase(PurchaseStatus.restored));
      await pumpEventQueue();

      expect(helper.status.value, CoffeeStatus.thanks);
      expect(helper.coffeeCount.value, 1);
      await store.dispose();
    });

    // Il caffè è consumabile: dal ringraziamento si deve poterne offrire un
    // altro senza chiudere il dialog.
    test('can be offered again from the thank-you screen', () async {
      final store = FakeStore();
      final helper = PurchaseHelper(gateway: store);
      await helper.init();
      await helper.loadProduct();

      await helper.buyCoffee();
      store.deliver(_purchase(PurchaseStatus.purchased));
      await pumpEventQueue();
      expect(helper.status.value, CoffeeStatus.thanks);

      helper.reset();
      expect(helper.status.value, CoffeeStatus.ready);

      await helper.buyCoffee();
      store.deliver(_purchase(PurchaseStatus.purchased));
      await pumpEventQueue();

      expect(helper.status.value, CoffeeStatus.thanks);
      expect(helper.coffeeCount.value, 2);
      expect(store.buyCalls, 2);
      await store.dispose();
    });

    test('a deferred payment approved later is still counted', () async {
      final store = FakeStore();
      final helper = PurchaseHelper(gateway: store);
      await helper.init();

      // Nessun tap in questa sessione: l'app è stata riaperta dopo
      // l'approvazione di "chiedi di acquistare".
      store.deliver(_purchase(PurchaseStatus.purchased));
      await pumpEventQueue();

      expect(helper.coffeeCount.value, 1);
      await store.dispose();
    });
  });
}

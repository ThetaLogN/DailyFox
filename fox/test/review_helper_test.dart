import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:daily_fox/helpers/review_helper.dart';

/// Doppio di prova: conta le richieste invece di aprire il messaggio di
/// sistema, che nei test non esiste.
class _FakeReview implements InAppReview {
  _FakeReview({this.available = true, this.throwOnRequest = false});

  final bool available;
  final bool throwOnRequest;
  int requests = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    requests++;
    if (throwOnRequest) throw Exception('richiesta fallita');
  }

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ReviewHelper non chiede nulla prima del settimo giorno', () async {
    final fake = _FakeReview();
    ReviewHelper.review = fake;

    for (var streak = 0; streak < 7; streak++) {
      expect(await ReviewHelper.maybeAsk(streak), isFalse);
    }
    expect(fake.requests, 0);
  });

  test('ReviewHelper chiede al settimo giorno', () async {
    final fake = _FakeReview();
    ReviewHelper.review = fake;

    expect(await ReviewHelper.maybeAsk(7), isTrue);
    expect(fake.requests, 1);
  });

  test('ReviewHelper chiede una sola volta', () async {
    final fake = _FakeReview();
    ReviewHelper.review = fake;

    await ReviewHelper.maybeAsk(7);
    // Giorni successivi: lo slancio cresce, la richiesta non si ripete.
    expect(await ReviewHelper.maybeAsk(8), isFalse);
    expect(await ReviewHelper.maybeAsk(30), isFalse);
    expect(fake.requests, 1);
  });

  test('ReviewHelper non insiste se la richiesta fallisce', () async {
    // Il flag va messo prima di chiedere: se `requestReview` esplode, il
    // messaggio non deve tornare a ogni salvataggio successivo.
    final fake = _FakeReview(throwOnRequest: true);
    ReviewHelper.review = fake;

    expect(await ReviewHelper.maybeAsk(7), isFalse);
    expect(await ReviewHelper.maybeAsk(8), isFalse);
    expect(fake.requests, 1);
  });

  test('ReviewHelper resta zitto dove il servizio non esiste', () async {
    final fake = _FakeReview(available: false);
    ReviewHelper.review = fake;

    expect(await ReviewHelper.maybeAsk(7), isFalse);
    expect(fake.requests, 0);

    // E il flag non viene consumato: se in futuro il servizio c'è, si chiede.
    ReviewHelper.review = _FakeReview();
    expect(await ReviewHelper.maybeAsk(7), isTrue);
  });
}

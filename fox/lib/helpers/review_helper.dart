import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chiede una recensione dopo il settimo giorno di slancio.
///
/// Il momento è scelto: a sette giorni chi usa l'app ha già deciso se gli
/// piace, e lo si chiede subito dopo una celebrazione invece che all'avvio,
/// quando interromperebbe qualcosa.
///
/// **Il sistema può non mostrare nulla.** iOS limita il messaggio a tre volte
/// per 365 giorni e non dice se l'ha mostrato né cosa ha risposto l'utente:
/// `requestReview` non restituisce niente. Quindi qui non si può sapere se una
/// recensione è stata scritta, e nessuna funzione dell'app deve dipenderne.
class ReviewHelper {
  ReviewHelper._();

  /// Giorni di slancio dopo i quali si chiede.
  static const int requiredStreak = 7;

  /// Segna che la richiesta è già partita, per non riproporla.
  static const String _askedKey = 'review_requested';

  /// Il vero servizio, sostituibile nei test.
  @visibleForTesting
  static InAppReview review = InAppReview.instance;

  /// Chiede la recensione se è il momento. Da chiamare a celebrazione finita.
  ///
  /// Restituisce true se la richiesta è stata inoltrata al sistema — che è
  /// cosa diversa dall'averla mostrata all'utente.
  static Future<bool> maybeAsk(int streak) async {
    if (streak < requiredStreak) return false;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedKey) ?? false) return false;

    try {
      if (!await review.isAvailable()) return false;

      // Il segno va messo prima di chiedere, non dopo.
      //
      // `requestReview` non torna indietro se qualcosa va storto: segnando
      // dopo, un errore lascerebbe il flag a falso e il messaggio
      // ricomparirebbe a ogni salvataggio successivo. Chiedere una volta di
      // meno è meglio che tempestare di richieste chi non ha risposto.
      await prefs.setBool(_askedKey, true);
      await review.requestReview();
      return true;
    } catch (e) {
      debugPrint('Error requesting review: $e');
      return false;
    }
  }
}

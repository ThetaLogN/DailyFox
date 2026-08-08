import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Gestisce le foto del giorno: scelta, salvataggio ed eliminazione.
///
/// Nel database viene salvato **solo il nome del file**, mai il percorso
/// assoluto. Su iOS il contenitore dell'app ha un UUID che cambia a ogni
/// aggiornamento e reinstallazione: un percorso assoluto salvato oggi punta al
/// vuoto dopo il prossimo update dell'App Store, e tutte le foto sparirebbero
/// insieme senza alcun errore visibile. Il percorso va ricostruito a ogni
/// lettura con [resolve].
class PhotoHelper {
  PhotoHelper._();

  /// Sottocartella dei documenti dove vivono le foto.
  static const String _folder = 'photos';

  /// Lato lungo massimo. Una foto da 12 megapixel al giorno riempirebbe il
  /// telefono nel giro di un anno: il ridimensionamento non è un dettaglio.
  static const double _maxWidth = 1600;
  static const int _quality = 85;

  static final ImagePicker _picker = ImagePicker();

  /// La cartella delle foto, creata se non esiste.
  static Future<Directory> _photosDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final dir = Directory('${documents.path}/$_folder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Nome file → file assoluto, ricalcolato ogni volta.
  static Future<File> resolve(String fileName) async {
    final documents = await getApplicationDocumentsDirectory();
    return File('${documents.path}/$_folder/$fileName');
  }

  /// Nome file per una data, con marca temporale.
  ///
  /// Volutamente **non** deterministico: con un nome fisso, sostituire una foto
  /// riscriverebbe lo stesso percorso e Flutter continuerebbe a mostrare quella
  /// vecchia, che resta nella cache delle immagini. Un nome nuovo a ogni scatto
  /// aggira il problema alla radice; la vecchia va cancellata da chi chiama.
  static String fileNameFor(String dateKey) =>
      '${dateKey}_${DateTime.now().millisecondsSinceEpoch}.jpg';

  /// Apre fotocamera o galleria, ridimensiona e salva.
  /// Restituisce il nome del file, o null se l'utente annulla.
  static Future<String?> pickAndSave(ImageSource source, String dateKey) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: _maxWidth,
        imageQuality: _quality,
        // Servono solo i pixel, non i metadati.
        //
        // Con `true` (il valore predefinito) su iOS il pacchetto chiede anche
        // il permesso alla libreria foto per leggere i dati EXIF — pure
        // scattando con la fotocamera — e tiene in memoria più del necessario.
        // Meno permessi richiesti e meno memoria occupata mentre la fotocamera
        // è aperta, che è il momento in cui iOS decide se chiudere l'app.
        requestFullMetadata: false,
      );
      if (picked == null) return null;

      final dir = await _photosDirectory();
      final fileName = fileNameFor(dateKey);
      final destination = File('${dir.path}/$fileName');

      // `pickImage` restituisce un file nella cache, che iOS può ripulire
      // quando vuole: va copiato nei documenti, non referenziato.
      await destination.writeAsBytes(await picked.readAsBytes());

      return fileName;
    } catch (e) {
      debugPrint('Error picking photo: $e');
      return null;
    }
  }

  /// Elimina il file. Da chiamare quando una foto viene rimossa, altrimenti i
  /// file orfani si accumulano invisibili.
  static Future<void> delete(String fileName) async {
    try {
      final file = await resolve(fileName);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting photo: $e');
    }
  }

  /// True se il file esiste davvero: un nome nel database non garantisce che
  /// la foto ci sia ancora.
  static Future<bool> exists(String fileName) async {
    final file = await resolve(fileName);
    return file.exists();
  }
}

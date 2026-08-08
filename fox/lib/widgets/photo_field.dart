import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';

import '../helpers/photo_helper.dart';

/// L'immagine di una foto salvata.
///
/// Il database contiene il nome del file, non il percorso: va risolto a ogni
/// lettura, perché il contenitore dell'app cambia con gli aggiornamenti.
class PhotoImage extends StatelessWidget {
  final String fileName;
  final double radius;

  const PhotoImage(
    this.fileName, {
    super.key,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: FutureBuilder<File>(
        future: PhotoHelper.resolve(fileName),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(height: 160, width: double.infinity);
          }
          // Larghezza piena e altezza proporzionale alla foto: niente riquadro
          // fisso, quindi né bande né ritagli — si vede solo la foto, con le
          // sue proporzioni.
          return Image.file(
            snapshot.data!,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            // Il file può mancare: un nome nel database non garantisce che la
            // foto ci sia ancora.
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

/// Campo per scegliere la foto del giorno: un riquadro da toccare se vuoto,
/// l'anteprima con Sostituisci e Rimuovi se una foto c'è già.
///
/// Condiviso tra calendario e home, così le due schermate non divergono.
class PhotoField extends StatelessWidget {
  /// Nome del file attuale, o null se il giorno non ha foto.
  final String? fileName;

  /// Chiave del giorno (`YYYY-MM-DD`), usata per nominare il file.
  final String dateKey;

  final ValueChanged<String> onPicked;
  final VoidCallback onRemoved;

  const PhotoField({
    super.key,
    required this.fileName,
    required this.dateKey,
    required this.onPicked,
    required this.onRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final current = fileName;

    if (current == null) {
      return InkWell(
        onTap: () async {
          final picked = await pickPhoto(context, dateKey);
          if (picked != null) onPicked(picked);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 90,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined,
                  size: 22, color: cs.onSurfaceVariant),
              const SizedBox(height: 6),
              Text(
                l10n.photoAdd,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    // Due gesti distinti: la foto si apre toccandola, il menu sta dietro alla
    // X in alto a destra. Così l'azione più frequente — guardarla — è quella
    // immediata, e sostituire o rimuovere richiede un tocco mirato.
    return Column(
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            GestureDetector(
              onTap: () => showPhotoFullScreen(context, current),
              child: PhotoImage(current),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => _showPhotoActions(context),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 24, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

extension on PhotoField {
  /// Foglio con Sostituisci e Rimuovi, aperto toccando la foto.
  ///
  /// Stessa forma del foglio con cui si sceglie fotocamera o galleria: due
  /// azioni sullo stesso oggetto meritano lo stesso gesto.
  Future<void> _showPhotoActions(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(l10n.photoReplace),
              onTap: () => Navigator.pop(context, 'replace'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: cs.error),
              title: Text(l10n.photoRemove, style: TextStyle(color: cs.error)),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    );

    if (action == 'remove') {
      onRemoved();
      return;
    }
    if (action == 'replace' && context.mounted) {
      final picked = await pickPhoto(context, dateKey);
      if (picked != null) onPicked(picked);
    }
  }
}

/// Foglio di scelta fotocamera/galleria. Restituisce il nome del file salvato,
/// o null se l'utente annulla.
Future<String?> pickPhoto(BuildContext context, String dateKey) async {
  final l10n = AppLocalizations.of(context)!;

  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.photoTakePhoto),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.photoChooseFromGallery),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );

  if (source == null) return null;
  return PhotoHelper.pickAndSave(source, dateKey);
}

/// Apre la foto a schermo intero, con pizzico per ingrandire.
void showPhotoFullScreen(BuildContext context, String fileName) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      // Si chiude toccando: a schermo intero non c'è altro da fare, e un
      // pulsante di chiusura sarebbe l'unico elemento sopra la foto.
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: FutureBuilder<File>(
            future: PhotoHelper.resolve(fileName),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }
              return InteractiveViewer(
                maxScale: 4,
                child: Image.file(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

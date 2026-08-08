import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../models/diary_entry.dart';
import '../helpers/database_helper.dart';
import '../helpers/photo_helper.dart';
import 'widgets/photo_field.dart';
import 'home_page.dart' show WidgetService;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'stats_page.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, DiaryEntry> _entries = {};
  bool _isLoading = true;

  /// Origine della numerazione delle pagine. In UTC di proposito: la
  /// differenza fra due date locali attraversa i cambi di ora legale e vale
  /// 23 o 25 ore, quindi `inDays` sbaglierebbe di un giorno due volte l'anno.
  static final DateTime _pageEpoch = DateTime.utc(2015, 1, 1);
  static final DateTime _firstCalendarDay = DateTime.utc(2020, 1, 1);
  static final DateTime _lastCalendarDay = DateTime.utc(2030, 12, 31);

  /// Data → numero di pagina.
  int _pageIndexFor(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day).difference(_pageEpoch).inDays;

  /// Numero di pagina → data locale.
  DateTime _dayForPageIndex(int index) {
    final utc = _pageEpoch.add(Duration(days: index));
    return DateTime(utc.year, utc.month, utc.day);
  }

  /// Il numero totale di pagine copre l'intero intervallo consentito dal calendario,
  /// permettendo di navigare anche sui giorni futuri per visualizzarne lo stato.
  int get _pageCount => _pageIndexFor(_lastCalendarDay) + 1;

  late final PageController _pageController;

  /// Serve a distinguere lo scorrimento dell'utente dai salti che facciamo
  /// noi quando tocca una data sul calendario, che non devono rimbalzare.
  bool _isJumpingPage = false;

  /// Serve a misurare quanto spazio occupa davvero il calendario.
  final GlobalKey _calendarKey = GlobalKey();

  /// Posizione di riposo del foglio, come frazione dell'altezza disponibile.
  ///
  /// Calcolata, non fissata: il foglio deve iniziare esattamente dove finisce
  /// il calendario, e l'altezza del calendario cambia col mese — cinque o sei
  /// righe di giorni. Un valore fisso coinciderebbe solo per certi mesi.
  double _sheetRestFraction = 0.5;

  /// Muove il foglio da fuori, per riallinearlo quando cambia il mese.
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  /// Rimisura il calendario e aggiorna la posizione di riposo.
  void _measureCalendar(double availableHeight) {
    final box = _calendarKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || availableHeight <= 0) return;

    // Quanto resta sotto il calendario.
    //
    // I 6 punti sottratti fanno salire il foglio *dentro* il margine di 16
    // della card, che è spazio vuoto: i giorni restano tutti visibili. Vanno
    // tolti qui e non dal margine, che è lo stesso dei lati e sbilancerebbe
    // la card se lo si accorciasse solo in basso.
    final fraction =
        (1 - (box.size.height - 6) / availableHeight).clamp(0.15, 0.85);

    // Solo se cambia davvero: altrimenti ogni frame chiederebbe un rebuild.
    if ((fraction - _sheetRestFraction).abs() <= 0.005) return;

    // Il foglio va spostato a mano se stava riposando sul bordo vecchio.
    //
    // Cambiare `minChildSize` non basta: `copyWith` riporta il foglio alla
    // nuova posizione solo finché non è mai stato toccato, poi si limita a
    // ricacciarlo dentro i limiti. Su un mese più alto quindi resterebbe dove
    // stava, scollegato dal calendario. Se invece l'utente lo ha alzato per
    // leggere una giornata, va lasciato dov'è: non gli si strappa di mano.
    final wasResting = !_sheetController.isAttached ||
        (_sheetController.size - _sheetRestFraction).abs() < 0.02;

    setState(() => _sheetRestFraction = fraction);

    if (wasResting) {
      // Dopo il frame: prima devono valere i limiti nuovi. Senza animazione,
      // così il bordo segue quello del calendario che si sta già animando.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_sheetController.isAttached) _sheetController.jumpTo(fraction);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _pageController = PageController(initialPage: _pageIndexFor(_selectedDay!));
    _loadEntries();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    try {
      final entries = await DatabaseHelper().getAllEntries();
      final entriesMap = <String, DiaryEntry>{};
      for (var entry in entries) {
        final date = DateTime.parse(entry.date);
        final dateKey = _getDateKey(date);
        entriesMap[dateKey] = entry;
      }
      setState(() {
        _entries = entriesMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading entries: $e');
    }
  }

  /// Lo scorrimento ha portato su un altro giorno: il calendario sopra segue,
  /// anche quando si cambia mese.
  void _onDayPageChanged(int index) {
    if (_isJumpingPage) return;
    final day = _dayForPageIndex(index);
    setState(() {
      _selectedDay = day;
      _focusedDay = day;
    });
  }

  /// Porta lo scorrimento sul giorno toccato sul calendario.
  ///
  /// Senza animazione di proposito: la data è già stata scelta con il dito
  /// sulla griglia, far volare le pagine intermedie sarebbe solo attesa.
  void _jumpToDay(DateTime day) {
    if (!_pageController.hasClients) return;
    _isJumpingPage = true;
    _pageController.jumpToPage(_pageIndexFor(day));
    _isJumpingPage = false;
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Color _getRatingColor(int rating) {
    if (rating <= 3) return Colors.red;
    if (rating <= 5) return Colors.orange;
    if (rating <= 7) return Colors.yellow[700]!;
    return Colors.green;
  }

  String _getRatingText(int rating) {
    final l10n = AppLocalizations.of(context)!;
    if (rating <= 2) return l10n.ratingTextTerrible;
    if (rating <= 4) return l10n.ratingTextBad;
    if (rating <= 6) return l10n.ratingTextAverage;
    if (rating <= 8) return l10n.ratingTextGood;
    return l10n.ratingTextGreat;
  }

  String _getFormattedDate(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final formatter = DateFormat('d MMMM yyyy', l10n.localeName);
    return formatter.format(date);
  }

  /// Permette di aggiungere o modificare entry per oggi e per i giorni passati.
  /// I giorni futuri non sono modificabili.
  bool _canAddEntry(DateTime date) {
    final today = DateTime.now();
    final dateOnly = DateTime(date.year, date.month, date.day);
    final todayOnly = DateTime(today.year, today.month, today.day);

    // I giorni futuri non sono modificabili
    if (dateOnly.isAfter(todayOnly)) return false;

    // Se è oggi, permette la modifica solo dopo le 18:00
    if (dateOnly == todayOnly) {
      return today.hour >= 18;
    }

    // I giorni passati sono sempre modificabili
    return true;
  }

  void _showAddEntryDialog(DateTime date) {
    // Modificare una giornata deve partire da com'era.
    //
    // Prima il dialog ripartiva sempre da 5 e 😊 anche su un giorno già
    // registrato: chi voleva correggere solo la parola si ritrovava il voto
    // azzerato senza accorgersene, e salvando lo perdeva davvero.
    final existing = _entries[_getDateKey(date)];

    int selectedRating = existing?.rating ?? 5;
    String selectedEmoji = existing?.emoji ?? '😊';
    String keyword = existing?.keyword ?? '';
    final TextEditingController keywordController =
        TextEditingController(text: keyword);
    bool showEmojiPicker = false;
    // La foto già presente va riproposta, altrimenti salvare la giornata la
    // farebbe sparire.
    String? photoFileName = existing?.photoPath;
    // Se l'utente la sostituisce o la rimuove, il file vecchio va cancellato
    // solo a salvataggio confermato: annullando il dialog deve restare.
    String? photoToDelete;

    showDialog(
      context: context,
      // Non si chiude toccando fuori.
      //
      // Serve soprattutto tornando dalla fotocamera: il dialog spariva e la
      // foto appena scattata andava persa, perché nessuno restava ad ascoltare
      // il risultato. In generale un modulo con dati non salvati non deve
      // svanire per un tocco a vuoto — per uscire ci sono la X e Annulla.
      barrierDismissible: false,
      builder: (BuildContext context) {
        final l10n = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              existing == null
                                  ? '${l10n.addedit}${_getFormattedDate(date)}'
                                  : '${l10n.modificaValutazione} — '
                                      '${_getFormattedDate(date)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Rating
                            Text(
                              l10n.ratingCardTitle,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: selectedRating.toDouble(),
                                    min: 1,
                                    max: 10,
                                    divisions: 9,
                                    label: '$selectedRating',
                                    // Segue il colore del voto, come il
                                    // riquadro accanto: qui il colore è
                                    // informativo e non un comando.
                                    activeColor:
                                        _getRatingColor(selectedRating),
                                    thumbColor: _getRatingColor(selectedRating),
                                    onChanged: (value) {
                                      setStateDialog(() {
                                        selectedRating = value.round();
                                      });
                                    },
                                  ),
                                ),
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: _getRatingColor(selectedRating),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$selectedRating',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Emoji
                            Text(
                              l10n.emojiLabel,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setStateDialog(() {
                                      showEmojiPicker = !showEmojiPicker;
                                    });
                                  },
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color:
                                              theme.colorScheme.outlineVariant),
                                    ),
                                    child: Center(
                                      child: Text(
                                        selectedEmoji,
                                        style: const TextStyle(fontSize: 30),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            if (showEmojiPicker)
                              Container(
                                height: 250,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: theme.colorScheme.outlineVariant),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: EmojiPicker(
                                    onEmojiSelected: (category, emoji) {
                                      setStateDialog(() {
                                        selectedEmoji = emoji.emoji;
                                        showEmojiPicker = false;
                                      });
                                    },
                                    config: Config(
                                      height: 256,
                                      checkPlatformCompatibility: true,
                                      emojiViewConfig: EmojiViewConfig(
                                        emojiSizeMax: 28,
                                        backgroundColor:
                                            theme.colorScheme.surface,
                                        columns: 7,
                                      ),
                                      skinToneConfig: const SkinToneConfig(),
                                      categoryViewConfig: CategoryViewConfig(
                                        indicatorColor: theme.primaryColor,
                                        iconColorSelected: theme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 16),

                            // Keyword
                            Text(
                              l10n.keywordCardTitle,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: keywordController,
                              decoration: InputDecoration(
                                hintText: l10n.keywordHintText,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (value) {
                                // setStateDialog serve al pulsante di
                                // salvataggio, che si accende solo con la
                                // parola scritta.
                                setStateDialog(() => keyword = value);
                              },
                            ),

                            const SizedBox(height: 16),

                            // Foto del giorno, facoltativa
                            Text(
                              l10n.photoOfTheDay,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            PhotoField(
                              fileName: photoFileName,
                              dateKey: _getDateKey(date),
                              onPicked: (picked) => setStateDialog(() {
                                photoToDelete ??= photoFileName;
                                photoFileName = picked;
                              }),
                              onRemoved: () => setStateDialog(() {
                                photoToDelete ??= photoFileName;
                                photoFileName = null;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Actions
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            // Contornato come gli altri comandi del dialog,
                            // ma in tono secondario: annullare non è l'azione
                            // da mettere in evidenza accanto al salvataggio.
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  theme.colorScheme.onSurfaceVariant,
                              side: BorderSide(
                                  color: theme.colorScheme.outlineVariant),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(l10n.annulla),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            // Spento finché manca la parola, come in home:
                            // mostra da sé che manca qualcosa invece di
                            // accettare il tocco e poi rimproverare.
                            onPressed: keyword.trim().isEmpty
                                ? null
                                : () async {
                                    await _saveEntry(date, selectedRating,
                                        selectedEmoji, keyword, photoFileName);
                                    // Solo ora il file vecchio è davvero orfano.
                                    if (photoToDelete != null &&
                                        photoToDelete != photoFileName) {
                                      await PhotoHelper.delete(photoToDelete!);
                                    }
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                  },
                            // Colore stabile, non quello del voto.
                            //
                            // Prima usava `_getRatingColor(selectedRating)`:
                            // con voti bassi il pulsante diventava rosso, e un
                            // "Salva" rosso legge come un'azione distruttiva;
                            // con voti 6-7 diventava giallo, e il testo bianco
                            // sopra era quasi illeggibile. Il colore del voto
                            // resta dov'è informativo — il riquadro accanto al
                            // cursore — e non dove è un comando.
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(existing == null
                                ? l10n.saveButtonNew
                                : l10n.saveButtonUpdate),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveEntry(DateTime date, int rating, String emoji,
      String keyword, String? photoPath) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final dateKey = _getDateKey(date);
      final existingEntry = _entries[dateKey];

      final entry = DiaryEntry(
        id: existingEntry?.id,
        date: existingEntry?.date ?? dateKey,
        rating: rating,
        emoji: emoji,
        keyword: keyword.isNotEmpty ? keyword : null,
        slancio: existingEntry?.slancio ?? false,
        photoPath: photoPath,
      );

      if (existingEntry?.id != null) {
        await DatabaseHelper().updateEntry(entry);
      } else {
        await DatabaseHelper().insertEntry(entry);
      }
      await _loadEntries();
      // Anche una modifica fatta da qui cambia la media: senza questa chiamata
      // la volpe e il widget restavano fermi all'ultimo salvataggio dalla home.
      await WidgetService.refreshFromDatabase();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.snackBarUpdatedSuccess),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.snackBarSaveError),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCalendarCell(DateTime day, bool isToday, bool isSelected) {
    final dateKey = _getDateKey(day);
    final entry = _entries[dateKey];
    final hasEntry = entry != null;

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Su fondo quasi nero una velatura al 30% resta smorta: in tema scuro
    // serve più opacità perché il colore del voto si veda.
    final tint = isDark ? 0.45 : 0.30;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: hasEntry
            ? _getRatingColor(entry.rating).withValues(alpha: tint)
            : (isToday ? cs.primary.withValues(alpha: 0.12) : null),
        border: Border.all(
          color: isSelected
              ? cs.primary
              : (isToday
                  ? cs.primary.withValues(alpha: 0.5)
                  : Colors.transparent),
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 4,
            left: 6,
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                // Il numero deve restare leggibile su entrambi i temi: prima
                // era grigio scuro fisso, invisibile sulla cella notturna.
                color: hasEntry
                    ? cs.onSurface
                    : (isToday ? cs.primary : cs.onSurfaceVariant),
              ),
            ),
          ),
          if (hasEntry)
            Positioned(
              bottom: 2,
              right: 2,
              child: Text(
                entry.emoji,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          if (hasEntry)
            Positioned(
              bottom: 2,
              left: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getRatingColor(entry.rating),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayDetails(DateTime day) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final dateKey = _getDateKey(day);
    final entry = _entries[dateKey];

    if (entry == null) {
      final canAdd = _canAddEntry(day);
      return Card(
        margin: const EdgeInsets.all(16),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          // Larghezza piena: dentro lo SingleChildScrollView i vincoli
          // orizzontali sono liberi, quindi la card si restringeva sul figlio
          // più largo — il pulsante — e non si allineava col calendario sopra.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: double.infinity),
              Icon(Icons.calendar_today, size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                l10n.noEntryMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getFormattedDate(day),
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (canAdd)
                // Senza icona a sinistra: `ElevatedButton.icon` ne riserva lo
                // spazio e centra il gruppo icona+testo, così l'etichetta da
                // sola risultava spostata a destra dentro il pulsante.
                ElevatedButton(
                  onPressed: () => _showAddEntryDialog(day),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(l10n.addreting, textAlign: TextAlign.center),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Text(
                        l10n.notedit,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getRatingColor(entry.rating).withValues(alpha: 0.1),
              _getRatingColor(entry.rating).withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          _getRatingColor(entry.rating).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getFormattedDate(day),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getRatingColor(entry.rating),
                      ),
                    ),
                  ),
                  if (_canAddEntry(day))
                    IconButton(
                      onPressed: () => _showAddEntryDialog(day),
                      icon: const Icon(Icons.edit),
                      tooltip: l10n.modificaValutazione,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: _getRatingColor(entry.rating),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _getRatingColor(entry.rating)
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${entry.rating}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.outlineVariant, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        entry.emoji,
                        style: const TextStyle(fontSize: 35),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getRatingText(entry.rating),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _getRatingColor(entry.rating),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.dayRatingLabel(
                              _getRatingText(entry.rating).toLowerCase()),
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (entry.keyword != null && entry.keyword!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.label_outline,
                              size: 18, color: cs.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(
                            l10n.keywordCardTitle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.keyword!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Foto del giorno, se c'è. Toccandola si apre a schermo intero.
              if (entry.photoPath != null) ...[
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => showPhotoFullScreen(context, entry.photoPath!),
                  child: PhotoImage(entry.photoPath!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          l10n.calendarTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outlineVariant),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Statistiche',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEntries,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              // Misura dopo il layout: prima il calendario non ha una taglia.
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _measureCalendar(constraints.maxHeight));

              return Stack(
                children: [
                  // Il calendario resta in alto; il foglio gli scorre sopra.
                  //
                  // L'altezza va lasciata illimitata, e non è un dettaglio.
                  //
                  // `TableCalendarBase` fa `constraints.hasBoundedHeight ?
                  // constraints.maxHeight : altezzaCalcolata`: con un limite
                  // qualsiasi si prende tutto lo schermo, lasciando un vuoto
                  // sotto l'ultima settimana e falsando la misura del foglio.
                  // Solo senza limite riporta l'altezza vera delle sue righe.
                  UnconstrainedBox(
                    constrainedAxis: Axis.horizontal,
                    alignment: Alignment.topCenter,
                    child: Card(
                      key: _calendarKey,
                      margin: const EdgeInsets.all(16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TableCalendar<DiaryEntry>(
                          // Il calendario resta fermo: niente scorrimento proprio.
                          //
                          // I suoi gesti si sovrapponevano a quelli del foglio e
                          // dello scorrimento tra i giorni, e il mese cambiava per
                          // sbaglio. Per cambiare mese restano le frecce.
                          availableGestures: AvailableGestures.none,
                          // L'altezza cambia di colpo, non animata.
                          //
                          // `TableCalendarBase` anima la propria altezza a
                          // ogni cambio di numero di righe. La misura del
                          // foglio parte subito dopo il frame e leggeva
                          // l'altezza vecchia: non trovando differenze si
                          // fermava, e passando da un mese di cinque righe a
                          // uno di sei il foglio restava alto, coprendo
                          // l'ultima settimana. Senza animazione una misura
                          // sola è già quella definitiva.
                          formatAnimationDuration: Duration.zero,
                          firstDay: _firstCalendarDay,
                          lastDay: _lastCalendarDay,
                          focusedDay: _focusedDay,
                          calendarFormat: _calendarFormat,
                          selectedDayPredicate: (day) {
                            return isSameDay(_selectedDay, day);
                          },
                          onDaySelected: (selectedDay, focusedDay) {
                            if (!isSameDay(_selectedDay, selectedDay)) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                              _jumpToDay(selectedDay);
                            }
                          },
                          onFormatChanged: (format) {
                            if (_calendarFormat != format) {
                              setState(() {
                                _calendarFormat = format;
                              });
                            }
                          },
                          onPageChanged: (focusedDay) {
                            setState(() {
                              _focusedDay = focusedDay;
                            });
                          },
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, day, focusedDay) {
                              return _buildCalendarCell(day, false, false);
                            },
                            todayBuilder: (context, day, focusedDay) {
                              return _buildCalendarCell(day, true, false);
                            },
                            selectedBuilder: (context, day, focusedDay) {
                              return _buildCalendarCell(
                                  day, isSameDay(day, DateTime.now()), true);
                            },
                          ),
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            leftChevronVisible: true,
                            rightChevronVisible: true,
                          ),
                          calendarStyle: CalendarStyle(
                            outsideDaysVisible: false,
                            weekendTextStyle:
                                TextStyle(color: cs.onSurfaceVariant),
                            defaultTextStyle: TextStyle(color: cs.onSurface),
                            cellMargin: const EdgeInsets.all(4),
                            cellPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Foglio trascinabile: sale sopra il calendario per leggere la
                  // giornata, torna al 40% per rivedere il mese.
                  DraggableScrollableSheet(
                    // Niente chiave qui, di proposito.
                    //
                    // Ricrearlo a ogni misura distruggeva il `PageView` dei
                    // giorni una ventina di volte durante l'animazione del
                    // calendario, e la giornata mostrata finiva sbagliata.
                    // Non serve: `_replaceExtent` riporta il foglio alla nuova
                    // posizione da solo, e se l'utente lo ha già trascinato lo
                    // lascia dov'è invece di strapparglielo di mano.
                    controller: _sheetController,
                    initialChildSize: _sheetRestFraction,
                    minChildSize: _sheetRestFraction,
                    // Trascinando in alto copre quasi tutto il corpo: una
                    // giornata con foto e parola chiave lunga non stava nel
                    // 90% e restava tagliata in fondo. Resta un filo di
                    // calendario scoperto, così si vede che c'è sotto.
                    maxChildSize: 0.98,
                    // Si aggancia alle due posizioni invece di fermarsi ovunque.
                    //
                    // `snapSizes` è omesso di proposito: quando manca, Flutter
                    // usa `minChildSize` e `maxChildSize`, che qui sono già le
                    // due posizioni volute. Elencarle a mano rischia soltanto di
                    // violare l'assert che le vuole strettamente crescenti.
                    snap: true,
                    builder: (context, scrollController) {
                      final cs = Theme.of(context).colorScheme;
                      return Container(
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Maniglia: senza, non si capisce che si trascina.
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: cs.outlineVariant,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Expanded(
                              // Le card dei giorni scorrono con il dito, non
                              // cambiano a gesto finito: si vede la giornata
                              // accanto entrare mentre quella corrente esce.
                              child: PageView.builder(
                                controller: _pageController,
                                itemCount: _pageCount,
                                onPageChanged: _onDayPageChanged,
                                itemBuilder: (context, index) {
                                  // Il controller del foglio va agganciato a
                                  // ogni pagina, non a una sola.
                                  //
                                  // È lui a muovere il foglio: senza aggancio
                                  // non lo si alza da nessun punto, nemmeno
                                  // dalla maniglia. Che durante lo scorrimento
                                  // orizzontale le pagine agganciate siano due
                                  // è previsto: `_replaceExtent` cicla su
                                  // tutte le posizioni.
                                  return SingleChildScrollView(
                                    controller: scrollController,
                                    padding: const EdgeInsets.only(bottom: 24),
                                    child: _buildDayDetails(
                                        _dayForPageIndex(index)),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            }),
    );
  }
}

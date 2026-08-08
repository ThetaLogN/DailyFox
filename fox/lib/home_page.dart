import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:daily_fox/calendar_page.dart';
import 'package:daily_fox/main.dart';
import 'package:daily_fox/noti_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';
import '../helpers/database_helper.dart';
import '../helpers/badge_helper.dart';
import '../helpers/streak_helper.dart';
import '../helpers/review_helper.dart';
import '../helpers/purchase_helper.dart';
import '../helpers/home_sections.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'widgets/streak_card.dart';
import 'widgets/stats_cards.dart';
import 'widgets/countdown_header.dart';
import 'widgets/badge_unlock_dialog.dart';
import 'widgets/coffee_dialog.dart';
import 'widgets/photo_field.dart';
import '../helpers/photo_helper.dart';
import 'badges_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _rating = 5;
  String _emoji = '🙂';
  String _keyword = '';
  bool _showEmojiPicker = false;

  /// Foto di oggi: nome del file, non percorso.
  String? _photoFileName;

  /// Preferenza `show_photo_field`: chi non usa le foto può togliere il campo
  /// dalla home. Il calendario resta comunque il posto da cui aggiungerle, e
  /// le foto già salvate non vengono toccate.
  final ValueNotifier<bool> _showPhotoField = ValueNotifier(true);

  /// File da cancellare a salvataggio confermato, quando la foto viene
  /// sostituita o rimossa. Non prima: chi cambia idea senza salvare non deve
  /// perdere quella vecchia.
  String? _photoToDelete;
  bool _hasEntryToday = false;
  bool _entryLoaded = false;
  bool _isLoading = true;
  DiaryEntry? _todayEntry;
  final TextEditingController _keywordController = TextEditingController();
  late AnimationController _saveAnimationController;
  late Animation<double> _saveAnimation;

  // Streak
  int _currentStreak = 0;
  int _bestStreak = 0;

  /// Tutte le entry, per la heatmap annuale in home.
  List<DiaryEntry> _allEntries = [];

  bool _isStreakFrozen = false;
  late AnimationController _streakAnimationController;
  late AnimationController _fireAnimationController;
  late Animation<double> _streakScaleAnimation;
  late Animation<double> _streakOpacityAnimation;
  late Animation<double> _fireAnimation;

  Timer? _countdownTimer;
  Duration _timeUntilRating = Duration.zero;

  @override
  void initState() {
    super.initState();

    _saveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _saveAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _saveAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _streakAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fireAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _streakScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _streakAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _streakOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _streakAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _fireAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fireAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _loadTodayEntry();
    _loadStreakData();
    _updateCountdown();
    _startCountdownTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies è il primo punto in cui AppLocalizations.of(context)
    // è garantito disponibile. Ri-schedula le notifiche quando la lingua cambia.
    _scheduleNotificationsIfNeeded();
  }

  /// Schedula le notifiche in base allo stato attuale dell'entry di oggi.
  /// Sicuro da chiamare più volte — si basa sullo stato _hasEntryToday corrente.
  void _scheduleNotificationsIfNeeded() {
    if (!mounted) return;
    // Finché non sappiamo se oggi è già stato valutato, non schedulare:
    // _hasEntryToday è ancora al default false e scheduleremmo a vuoto.
    if (!_entryLoaded) return;
    NotiService().scheduleAllNotifications(
      context,
      hasEntryToday: _hasEntryToday,
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _keywordController.dispose();
    _saveAnimationController.dispose();
    _streakAnimationController.dispose();
    _fireAnimationController.dispose();
    super.dispose();
  }

  // ── Countdown ────────────────────────────────────────────────

  bool _canRateToday() {
    return DateTime.now().hour >= 18;
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final ratingTime = DateTime(now.year, now.month, now.day, 18, 0, 0);
    setState(() {
      _timeUntilRating =
          now.isBefore(ratingTime) ? ratingTime.difference(now) : Duration.zero;
    });
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdown();
      if (_canRateToday()) {
        timer.cancel();
        _loadTodayEntry();
      }
    });
  }

  /// True quando la giornata è completa e si può salvare.
  ///
  /// In pratica gira tutta sulla parola chiave: voto ed emoji partono da un
  /// valore predefinito e non possono mai essere vuoti. Vengono citati lo
  /// stesso perché la condizione descrive cosa serve per salvare, e se un
  /// giorno perdessero il predefinito il pulsante si adeguerebbe da sé.
  bool get _canSave =>
      _keyword.trim().isNotEmpty && _emoji.isNotEmpty && _rating > 0;

  // ── Streak ───────────────────────────────────────────────────

  void _loadStreakData() async {
    final prefs = await SharedPreferences.getInstance();
    final status = await StreakHelper.calculate();
    final currentStreak = status.days;

    // Aggiorna le prefs se lo streak è sceso (es. ha saltato due giorni)
    await prefs.setInt('current_streak', currentStreak);

    final bestStreak = prefs.getInt('best_streak') ?? 0;
    await HomeSection.load();
    _showPhotoField.value = prefs.getBool('show_photo_field') ?? true;
    final allEntries = await DatabaseHelper().getAllEntries();

    // BACKFILL BADGES: Se l'utente ha aggiornato l'app,
    // garantiamo che abbia i badge che gli spettano in base allo slancio ATTUALE.
    await BadgeHelper.backfillBadges(currentStreak);

    setState(() {
      _currentStreak = currentStreak;
      _bestStreak = bestStreak;
      _isStreakFrozen = status.isFrozen;
      _allEntries = allEntries;
    });
    if (_currentStreak > 0) {
      _streakAnimationController.forward();
    }
  }

  Future<void> _updateStreak() async {
    final status = await StreakHelper.calculate();
    final newStreak = status.days;
    final prefs = await SharedPreferences.getInstance();

    final wasNewStreak = newStreak > _currentStreak;
    final isNewBest = newStreak > _bestStreak;

    setState(() {
      _currentStreak = newStreak;
      _isStreakFrozen = status.isFrozen;
      if (isNewBest) _bestStreak = newStreak;
    });

    await prefs.setInt('current_streak', _currentStreak);
    await prefs.setInt('best_streak', _bestStreak);

    if (wasNewStreak) {
      _streakAnimationController.reset();
      await _streakAnimationController.forward();
      if (_currentStreak % 7 == 0 && _currentStreak > 0) {
        _showStreakCelebration();
      }
      // Controlla nuovi badge sbloccati
      if (mounted) {
        final newBadges =
            await BadgeHelper.checkAndUnlockBadges(_currentStreak);
        if (newBadges.isNotEmpty && mounted) {
          await showBadgeUnlockDialogs(context, newBadges);
        }
      }

      // La recensione si chiede per ultima, a festeggiamenti finiti.
      //
      // Prima ci sono coriandoli e badge: sovrapporre il messaggio di sistema
      // lo farebbe chiudere per sbaglio, e iOS lo conta comunque come mostrato.
      await ReviewHelper.maybeAsk(_currentStreak);
    }
  }

  /// Le sezioni delle statistiche che l'utente ha scelto di replicare qui.
  ///
  /// Titolo, icona, colore e widget vengono dal registro [HomeSection], lo
  /// stesso da cui li prende la pagina statistiche: le due schermate non
  /// possono mostrare cose diverse.
  Widget _buildHomeSections() {
    return ValueListenableBuilder<Set<HomeSection>>(
      valueListenable: HomeSection.enabledNotifier,
      builder: (context, sections, _) {
        if (sections.isEmpty || _allEntries.isEmpty) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context)!;

        return Column(
          children: [
            for (final section in HomeSection.values)
              if (sections.contains(section))
                _buildHomeSectionCard(section, l10n),
          ],
        );
      },
    );
  }

  Widget _buildHomeSectionCard(HomeSection section, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(section.icon, size: 18, color: section.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section.title(l10n),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              section.build(_allEntries),
            ],
          ),
        ),
      ),
    );
  }

  void _showStreakCelebration() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _fireAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_fireAnimation.value * 0.1),
                  child: const Text('🔥', style: TextStyle(fontSize: 60)),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              l10n.incredibileM,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${l10n.recordD} $_currentStreak ${l10n.recordD1}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(l10n.fantastic,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Entry handling ───────────────────────────────────────────

  void _loadTodayEntry() async {
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now();
      final todayString = _getDateKey(today);
      final entries = await DatabaseHelper().getAllEntries();
      final todayEntry =
          entries.where((e) => e.date.startsWith(todayString)).firstOrNull;

      if (todayEntry != null) {
        setState(() {
          _hasEntryToday = true;
          _todayEntry = todayEntry;
          _rating = todayEntry.rating;
          _emoji = todayEntry.emoji;
          _keyword = todayEntry.keyword ?? '';
          _keywordController.text = _keyword;
          _photoFileName = todayEntry.photoPath;
          _photoToDelete = null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasEntryToday = false;
          _todayEntry = null;
          _photoFileName = null;
          _photoToDelete = null;
          _isLoading = false;
        });
      }

      // Ri-schedula/cancella le notifiche in base allo stato aggiornato
      _entryLoaded = true;
      _scheduleNotificationsIfNeeded();
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading today\'s entry: $e');
    }
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _saveEntry() async {
    final l10n = AppLocalizations.of(context)!;
    if (_keyword.trim().isEmpty) {
      _showValidationError();
      return;
    }
    await _saveAnimationController.forward();
    await _saveAnimationController.reverse();

    final entry = DiaryEntry(
        id: _todayEntry?.id,
        rating: _rating,
        emoji: _emoji,
        keyword: _keyword.trim(),
        date: DateTime.now().toIso8601String(),
        slancio: true,
        photoPath: _photoFileName);

    try {
      if (_hasEntryToday && _todayEntry != null) {
        await DatabaseHelper().updateEntry(entry);
      } else {
        await DatabaseHelper().insertEntry(entry);
      }

      await _updateStreak();

      // Solo ora la foto precedente è davvero orfana: cancellarla prima del
      // salvataggio la perderebbe anche a chi cambia idea.
      final replaced = _photoToDelete;
      if (replaced != null && replaced != _photoFileName) {
        await PhotoHelper.delete(replaced);
      }
      _photoToDelete = null;

      await WidgetService.refreshFromDatabase();

      await NotiService().cancelNotificationsAll();
      _loadTodayEntry();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(_hasEntryToday
                    ? l10n.snackBarUpdatedSuccess
                    : l10n.snackBarSavedSuccess),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Text(l10n.snackBarSaveError),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  // ── Dialog ───────────────────────────────────────────────────

  void _showResetDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding:
              const EdgeInsets.only(left: 8, top: 16, right: 24, bottom: 8),
          title: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.impostazioni,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.dialogContentModifyRating),
              const SizedBox(height: 16),
              // Riquadro informativo: i colori vengono dai ruoli del tema, non
              // dalle tinte fisse `blue.shade50/200/700`, che in tema scuro
              // producevano una macchia chiarissima dentro un dialog scuro.
              Builder(builder: (context) {
                final cs = Theme.of(context).colorScheme;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.widgets, color: cs.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.dialogWidgetReminder,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (_, ThemeMode currentMode, __) {
                  final isDark = currentMode == ThemeMode.dark ||
                      (currentMode == ThemeMode.system &&
                          Theme.of(context).brightness == Brightness.dark);
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: SwitchListTile(
                      title: Text(
                          isDark ? l10n.modalitaScura : l10n.modalitaChiara),
                      secondary:
                          Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                      value: isDark,
                      // Stesso colore di tutti gli altri interruttori dell'app,
                      // e segue il tema invece di un blu fisso.
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (value) async {
                        final prefs = await SharedPreferences.getInstance();
                        themeNotifier.value =
                            value ? ThemeMode.dark : ThemeMode.light;
                        await prefs.setBool('isDark', value);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<bool>(
                valueListenable: _showPhotoField,
                builder: (_, bool show, __) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: SwitchListTile(
                      title: Text(l10n.photoShowField),
                      // Il sottotitolo chiarisce che la foto non è mai
                      // richiesta: si legge proprio mentre si decide se
                      // tenere il campo.
                      subtitle: Text(
                        l10n.photoShowFieldHint,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      isThreeLine: false,
                      secondary: const Icon(Icons.photo_camera_outlined),
                      value: show,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (value) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('show_photo_field', value);
                        _showPhotoField.value = value;
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<int>(
                valueListenable: PurchaseHelper.instance.coffeeCount,
                builder: (_, int coffeeCount, __) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.coffee, color: Colors.brown),
                      title: Text(l10n.coffeeTitle),
                      subtitle: coffeeCount > 0
                          ? Text(l10n.coffeeSupporterSubtitle)
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showCoffeeDialog(context),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showValidationError() {
    final l10n = AppLocalizations.of(context)!;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white),
              const SizedBox(width: 12),
              Text(l10n.snackBarValidationError),
            ],
          ),
          backgroundColor: Colors.orange[600],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ── Helpers ──────────────────────────────────────────────────

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

  String _getFormattedDate() {
    final now = DateTime.now();
    final l10n = AppLocalizations.of(context)!;
    final formatter = DateFormat('EEEE, d MMMM', l10n.localeName);
    return formatter.format(now);
  }

  // ── Build ────────────────────────────────────────────────────

  Widget _buildWaitingScreen() {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          l10n.appTitleNewDay,
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
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'I tuoi Traguardi',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BadgesPage(currentStreak: _currentStreak),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showResetDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            CountdownHeader(timeUntilRating: _timeUntilRating),
            StreakCard(
              currentStreak: _currentStreak,
              bestStreak: _bestStreak,
              isFrozen: _isStreakFrozen,
              scaleAnimation: _streakScaleAnimation,
              opacityAnimation: _streakOpacityAnimation,
              fireAnimation: _fireAnimation,
            ),
            _buildHomeSections(),
            const StatsCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () {
        // Al rientro ricarichiamo slancio ed entry, che possono essere
        // cambiati dal calendario. Le sezioni in home no: quelle arrivano da
        // HomeSection.enabledNotifier e si aggiornano da sole.
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CalendarPage()),
        ).then((_) => _loadStreakData());
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _hasEntryToday
                ? [
                    _getRatingColor(_rating).withValues(alpha: 0.8),
                    _getRatingColor(_rating).withValues(alpha: 0.6),
                  ]
                : [
                    Colors.blue.withValues(alpha: 0.8),
                    Colors.blue.withValues(alpha: 0.6),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (_hasEntryToday ? _getRatingColor(_rating) : Colors.blue)
                  .withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _hasEntryToday ? Icons.check_circle : Icons.today,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getFormattedDate(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hasEntryToday
                            ? l10n.statusHeaderRated
                            : l10n.statusHeaderToday,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_hasEntryToday) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          '$_rating/10',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _keyword.isNotEmpty
                          ? _keyword
                          : l10n.statusHeaderNoKeyword,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontStyle: _keyword.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_canRateToday()) {
      return _buildWaitingScreen();
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          _hasEntryToday ? l10n.appTitleModifyDay : l10n.appTitleNewDay,
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
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'I tuoi Traguardi',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BadgesPage(currentStreak: _currentStreak),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showResetDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(),
            StreakCard(
              currentStreak: _currentStreak,
              bestStreak: _bestStreak,
              isFrozen: _isStreakFrozen,
              scaleAnimation: _streakScaleAnimation,
              opacityAnimation: _streakOpacityAnimation,
              fireAnimation: _fireAnimation,
            ),
            _buildHomeSections(),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rating card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star_rounded,
                                  color: _getRatingColor(_rating), size: 28),
                              const SizedBox(width: 12),
                              Text(
                                l10n.ratingCardTitle,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Text(
                                '$_rating',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: _getRatingColor(_rating),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getRatingText(_rating),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: _getRatingColor(_rating),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor:
                                            _getRatingColor(_rating),
                                        inactiveTrackColor: cs.outlineVariant,
                                        thumbColor: _getRatingColor(_rating),
                                        overlayColor: _getRatingColor(_rating)
                                            .withValues(alpha: 0.2),
                                        trackHeight: 6,
                                      ),
                                      child: Slider(
                                        value: _rating.toDouble(),
                                        min: 1,
                                        max: 10,
                                        divisions: 9,
                                        onChanged: (value) {
                                          setState(() {
                                            _rating = value.toInt();
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Emoji card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.mood,
                                  color: Colors.amber, size: 28),
                              const SizedBox(width: 12),
                              Text(
                                l10n.emojiCardTitle,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => setState(
                                () => _showEmojiPicker = !_showEmojiPicker),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: cs.outline, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  _emoji,
                                  style: const TextStyle(fontSize: 40),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.emojiCardTapToChange,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                          if (_showEmojiPicker) ...[
                            const SizedBox(height: 16),
                            Container(
                              height: 250,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cs.outlineVariant),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: EmojiPicker(
                                  onEmojiSelected: (category, emoji) {
                                    setState(() {
                                      _emoji = emoji.emoji;
                                      _showEmojiPicker = false;
                                    });
                                  },
                                  config: Config(
                                    height: 256,
                                    checkPlatformCompatibility: true,
                                    emojiViewConfig: EmojiViewConfig(
                                      emojiSizeMax: 28,
                                      backgroundColor: cs.surface,
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
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Keyword card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.keyboard,
                                  color: Colors.blue, size: 28),
                              const SizedBox(width: 12),
                              Text(
                                l10n.keywordCardTitle,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _keywordController,
                            decoration: InputDecoration(
                              hintText: l10n.keywordHintText,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: cs.outlineVariant),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: cs.outlineVariant),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: theme.primaryColor, width: 2),
                              ),
                              filled: true,
                              fillColor: cs.surfaceContainerLowest,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            onChanged: (value) {
                              setState(() => _keyword = value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Foto del giorno — facoltativa, e si vede.
                  // Nascondibile del tutto dalle impostazioni.
                  //
                  // Volutamente NON una Card come voto, emoji e parola chiave:
                  // quelle sono campi del modulo, e la parola chiave è pure
                  // obbligatoria. Dare a questa lo stesso rilievo la farebbe
                  // sembrare un altro passo da compiere. Niente ombra, titolo
                  // in tono secondario, icona più piccola: il posto in cui
                  // aggiungere qualcosa, non qualcosa che manca.
                  ValueListenableBuilder<bool>(
                    valueListenable: _showPhotoField,
                    builder: (context, showPhoto, _) {
                      if (!showPhoto) return const SizedBox.shrink();
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.photo_camera_outlined,
                                      color: cs.onSurfaceVariant, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    l10n.photoOfTheDay,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              PhotoField(
                                fileName: _photoFileName,
                                dateKey: _getDateKey(DateTime.now()),
                                onPicked: (picked) => setState(() {
                                  _photoToDelete ??= _photoFileName;
                                  _photoFileName = picked;
                                }),
                                onRemoved: () => setState(() {
                                  _photoToDelete ??= _photoFileName;
                                  _photoFileName = null;
                                }),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  // Save button
                  AnimatedBuilder(
                    animation: _saveAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _saveAnimation.value,
                        child: Container(
                          width: double.infinity,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            // Spento finché la giornata non è completa: il
                            // pulsante mostra da sé che manca qualcosa, invece
                            // di accettare il tocco e poi rimproverare.
                            gradient: LinearGradient(
                              colors: _canSave
                                  ? [
                                      theme.primaryColor,
                                      theme.primaryColor.withValues(alpha: 0.8),
                                    ]
                                  : [
                                      cs.surfaceContainerHighest,
                                      cs.surfaceContainerHighest,
                                    ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                // Niente ombra da spento: sporgerebbe come un
                                // pulsante premibile.
                                color: (theme.brightness == Brightness.dark ||
                                        !_canSave)
                                    ? Colors.transparent
                                    : theme.primaryColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: theme.brightness == Brightness.dark
                                ? Border.all(color: Colors.white24, width: 1.5)
                                : null,
                          ),
                          child: ElevatedButton(
                            onPressed: _canSave ? _saveEntry : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _hasEntryToday
                                      ? Icons.edit
                                      : Icons.save_rounded,
                                  color: _canSave
                                      ? Colors.white
                                      : cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _hasEntryToday
                                      ? l10n.saveButtonUpdate
                                      : l10n.saveButtonNew,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _canSave
                                        ? Colors.white
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: screenHeight * 0.05),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── WidgetService ────────────────────────────────────────────────────────────

class WidgetService {
  /// Su quante valutazioni si media l'umore della volpe.
  ///
  /// Finestra corta di proposito: la volpe deve reagire in fretta a come stanno
  /// andando i giorni, non fare la media della stagione.
  static const int foxAverageWindow = 3;

  /// Ricalcola la volpe dal database e aggiorna il widget.
  ///
  /// Unico punto in cui si decide cosa mostra la volpe: prima il calcolo stava
  /// inline nel salvataggio della home, e il calendario non lo eseguiva affatto
  /// — modificare una giornata da lì lasciava il widget fermo.
  static Future<void> refreshFromDatabase() async {
    // `getAllEntries` è ordinata per data, quindi "ultime" significa davvero
    // le più recenti e non le ultime inserite.
    final entries = await DatabaseHelper().getAllEntries();
    if (entries.isEmpty) return;

    // Emoji e parola chiave restano quelle del giorno più recente: la media
    // riguarda l'umore, non il contenuto della giornata.
    final latest = entries.last;

    await saveAndUpdateWidget(
      rating: foxRatingFrom(entries),
      emoji: latest.emoji,
      keyword: latest.keyword ?? '',
    );
  }

  /// Il voto che determina l'espressione della volpe: media delle ultime
  /// [foxAverageWindow] valutazioni, arrotondata.
  ///
  /// [entries] deve essere ordinata per data crescente, com'è quella che
  /// restituisce `DatabaseHelper.getAllEntries`.
  static int foxRatingFrom(List<DiaryEntry> entries) {
    if (entries.isEmpty) return 7;

    final recent = entries.length > foxAverageWindow
        ? entries.sublist(entries.length - foxAverageWindow)
        : entries;

    return (recent.map((e) => e.rating).reduce((a, b) => a + b) / recent.length)
        .round();
  }

  static Future<void> saveAndUpdateWidget({
    required int rating,
    required String emoji,
    required String keyword,
  }) async {
    try {
      await HomeWidget.setAppGroupId('group.com.giorgiomartucci.DailyFox');
      await HomeWidget.saveWidgetData<String>('rating', rating.toString());
      await HomeWidget.saveWidgetData('emoji', emoji);
      await HomeWidget.saveWidgetData(
          'keyword', keyword.isEmpty ? 'Today' : keyword);
      await HomeWidget.saveWidgetData(
          'lastUpdate', DateTime.now().toIso8601String());
      await HomeWidget.updateWidget(
        name: 'FoxWidget',
        iOSName: 'FoxWidget',
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('rating', rating);
      await prefs.setString('emoji', emoji);
      await prefs.setString('keyword', keyword.isEmpty ? 'Today' : keyword);
      debugPrint(
          'Widget updated: Rating $rating, Emoji $emoji, Keyword $keyword');
    } catch (e) {
      // Il widget può fallire (es. su simulatore o macOS) senza bloccare il salvataggio
      debugPrint('Error updating widget (non-critical): $e');
    }
  }
}

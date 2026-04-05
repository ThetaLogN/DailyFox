import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:DailyFox/calendarPage.dart';
import 'package:DailyFox/main.dart';
import 'package:DailyFox/noti_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';
import '../helpers/database_helper.dart';
import '../helpers/badge_helper.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'widgets/streak_card.dart';
import 'widgets/stats_cards.dart';
import 'widgets/countdown_header.dart';
import 'widgets/badge_unlock_dialog.dart';
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
  bool _hasEntryToday = false;
  bool _isLoading = true;
  DiaryEntry? _todayEntry;
  final TextEditingController _keywordController = TextEditingController();
  late AnimationController _saveAnimationController;
  late Animation<double> _saveAnimation;
  

  // Streak
  int _currentStreak = 0;
  int _bestStreak = 0;
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
    NotiService().scheduleNotification(context);
    NotiService().scheduleNotification1(context);
    NotiService().scheduleNotification2(context);
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

  // ── Streak ───────────────────────────────────────────────────

  void _loadStreakData() async {
    final prefs = await SharedPreferences.getInstance();
    final currentStreak = await _calculateStreak();
    
    // Aggiorna le prefs se lo streak è sceso (es. ha saltato un giorno)
    await prefs.setInt('current_streak', currentStreak);
    
    final bestStreak = prefs.getInt('best_streak') ?? 0;
    setState(() {
      _currentStreak = currentStreak;
      _bestStreak = bestStreak;
    });
    if (_currentStreak > 0) {
      _streakAnimationController.forward();
    }
  }

  /// Calcola lo streak consecutivo.
  /// Le entry vengono deduplicate per data prima del conteggio,
  /// in modo che più entry nello stesso giorno non spezzino lo streak.
  Future<int> _calculateStreak() async {
    final entries = await DatabaseHelper().getAllEntriesWithSlancioTrue();
    if (entries.isEmpty) return 0;

    // Raccoglie i giorni unici (senza orario)
    final Set<String> uniqueDays = {};
    for (final e in entries) {
      final d = DateTime.parse(e.date);
      uniqueDays.add(
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }

    // Ordina decrescente
    final sortedDays = uniqueDays.toList()..sort((a, b) => b.compareTo(a));

    final today = DateTime.now();
    DateTime checkDate = DateTime(today.year, today.month, today.day);

    // Se oggi non ha ancora un'entry, inizia dallo ieri
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (!uniqueDays.contains(todayKey)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    int streak = 0;
    for (final dayStr in sortedDays) {
      final dayDate = DateTime.parse(dayStr);
      final checkKey =
          '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (dayStr == checkKey) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (dayDate.isBefore(checkDate)) {
        break;
      }
    }

    return streak;
  }

  Future<void> _updateStreak() async {
    final newStreak = await _calculateStreak();
    final prefs = await SharedPreferences.getInstance();

    final wasNewStreak = newStreak > _currentStreak;
    final isNewBest = newStreak > _bestStreak;

    setState(() {
      _currentStreak = newStreak;
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
        final newBadges = await BadgeHelper.checkAndUnlockBadges(_currentStreak);
        if (newBadges.isNotEmpty && mounted) {
          await showBadgeUnlockDialogs(context, newBadges);
        }
      }
    }
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
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasEntryToday = false;
          _todayEntry = null;
          _isLoading = false;
        });
      }
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
        slancio: true);

    try {
      if (_hasEntryToday && _todayEntry != null) {
        await DatabaseHelper().updateEntry(entry);
      } else {
        await DatabaseHelper().insertEntry(entry);
      }

      await _updateStreak();

      final entries = await DatabaseHelper().getAllEntries();
      final last10 =
          entries.length > 10 ? entries.sublist(entries.length - 10) : entries;
      final averageRating = last10.isEmpty
          ? _rating
          : (last10.map((e) => e.rating).reduce((a, b) => a + b) /
                  last10.length)
              .round();

      await WidgetService.saveAndUpdateWidget(
        rating: averageRating,
        emoji: _emoji,
        keyword: _keyword,
      );

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
          titlePadding: const EdgeInsets.only(left: 8, top: 16, right: 24, bottom: 8),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.widgets,
                        color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.dialogWidgetReminder,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                      title: Text(isDark ? l10n.modalitaScura : l10n.modalitaChiara),
                      secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                      value: isDark,
                      activeColor: Colors.blue,
                      onChanged: (value) async {
                        final prefs = await SharedPreferences.getInstance();
                        themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                        await prefs.setBool('isDark', value);
                      },
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
              scaleAnimation: _streakScaleAnimation,
              opacityAnimation: _streakOpacityAnimation,
              fireAnimation: _fireAnimation,
            ),
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
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CalendarPage()),
        );
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
              color:
                  (_hasEntryToday ? _getRatingColor(_rating) : Colors.blue)
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
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
              scaleAnimation: _streakScaleAnimation,
              opacityAnimation: _streakOpacityAnimation,
              fireAnimation: _fireAnimation,
            ),
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
                                        inactiveTrackColor:
                                            cs.outlineVariant,
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
                                border: Border.all(
                                    color: cs.outline, width: 2),
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
                                border:
                                    Border.all(color: cs.outlineVariant),
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
                            gradient: LinearGradient(
                              colors: [
                                theme.primaryColor,
                                theme.primaryColor.withValues(alpha: 0.8),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: // if theme is dark add no shadow
                                    theme.brightness == Brightness.dark
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
                            onPressed: _saveEntry,
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
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _hasEntryToday
                                      ? l10n.saveButtonUpdate
                                      : l10n.saveButtonNew,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
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

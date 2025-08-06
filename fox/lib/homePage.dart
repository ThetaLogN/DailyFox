import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:DailyFox/calendarPage.dart';
import 'package:DailyFox/noti_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';
import '../helpers/database_helper.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

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
  final bool _shouldShowStreakCard = false;

  // Streak variables
  int _currentStreak = 0;
  int _bestStreak = 0;
  bool _isNewStreak = false;
  late AnimationController _streakAnimationController;
  late AnimationController _fireAnimationController;
  late Animation<double> _streakScaleAnimation;
  late Animation<double> _streakOpacityAnimation;
  late Animation<double> _fireAnimation;
  late Animation<Color?> _streakColorAnimation;
  final InAppPurchase _iap = InAppPurchase.instance;
  ProductDetails? _product;

  // Configurazione widget iOS
  static const String appGroupId = "group.foxApp";
  static const String iOSWidgetName = "FoxWidget";

  Timer? _countdownTimer;
  Duration _timeUntilRating = Duration.zero;

  @override
  void initState() {
    super.initState();

    // _loadDonationProduct();
    // _listenToPurchase();

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

    // Streak animations
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

    _streakColorAnimation = ColorTween(
      begin: Colors.orange,
      end: Colors.red,
    ).animate(
      CurvedAnimation(
        parent: _streakAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Carica i dati dell'entry di oggi se disponibili
    _loadTodayEntry();
    _loadStreakData();
    _updateCountdown();
    _startCountdownTimer();
  }

  /*Future<void> _loadDonationProduct() async {
    final response = await _iap.queryProductDetails({'fox_tip_medium'});
    if (response.productDetails.isNotEmpty) {
      setState(() {
        _product = response.productDetails.first;
      });
    }
  }*/

  /*void _listenToPurchase() {
    _iap.purchaseStream.listen((purchases) {
      for (final p in purchases) {
        if (p.status == PurchaseStatus.purchased) {
          _iap.completePurchase(p);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('🦊 Thank you for supporting DailyFox!')),
          );
        }
      }
    });
  }*/

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    NotiService().scheduleNotification(context);
    NotiService().scheduleNotification1(context);
    NotiService().scheduleNotification2(context);
  }

  bool _canRateToday() {
    final now = DateTime.now();
    return now.hour >= 18;
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final ratingTime = DateTime(now.year, now.month, now.day, 18, 0, 0);

    if (now.isBefore(ratingTime)) {
      setState(() {
        _timeUntilRating = ratingTime.difference(now);
      });
    } else {
      setState(() {
        _timeUntilRating = Duration.zero;
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdown();

      // Se è ora di valutare, ferma il timer e ricarica la pagina
      if (_canRateToday()) {
        timer.cancel();
        _loadTodayEntry(); // Ricarica per mostrare la schermata di valutazione
      }
    });
  }

  Widget _buildWaitingScreen() {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          l10n.appTitleNewDay,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey[200],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showResetDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header con countdown
            _buildCountdownHeader(),

            // Streak card
            _buildStreakCard(),

            // Statistiche
            _buildStatsCards(),

            // Messaggio motivazionale
            // _buildMotivationalCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownHeader() {
    final l10n = AppLocalizations.of(context)!;
    final hours = _timeUntilRating.inHours;
    final minutes = _timeUntilRating.inMinutes % 60;
    final seconds = _timeUntilRating.inSeconds % 60;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CalendarPage()),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.indigo.withOpacity(0.8),
              Colors.purple.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.schedule,
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
                        l10n.endDay,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    l10n.timer,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTimeUnit(hours.toString().padLeft(2, '0'), 'Ore'),
                      _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'Min'),
                      _buildTimeUnit(seconds.toString().padLeft(2, '0'), 'Sec'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard(
                l10n.valutazioni,
                FutureBuilder<List<DiaryEntry>>(
                  future: DatabaseHelper().getAllEntries(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Text(
                        '${snapshot.data!.length}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      );
                    }
                    return const Text('--');
                  },
                ),
                Icons.star_rounded,
                Colors.blue,
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard(
                l10n.media,
                FutureBuilder<List<DiaryEntry>>(
                  future: DatabaseHelper().getAllEntries(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      final avg = snapshot.data!
                              .map((e) => e.rating)
                              .reduce((a, b) => a + b) /
                          snapshot.data!.length;
                      return Text(
                        avg.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      );
                    }
                    return const Text('--');
                  },
                ),
                Icons.trending_up,
                Colors.green,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard(
                l10n.thisM,
                FutureBuilder<List<DiaryEntry>>(
                  future: DatabaseHelper().getAllEntries(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final now = DateTime.now();
                      final thisMonth = snapshot.data!.where((entry) {
                        final entryDate = DateTime.parse(entry.date);
                        return entryDate.year == now.year &&
                            entryDate.month == now.month;
                      }).length;
                      return Text(
                        '$thisMonth',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      );
                    }
                    return const Text('--');
                  },
                ),
                Icons.calendar_month,
                Colors.orange,
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard(
                l10n.best,
                FutureBuilder<List<DiaryEntry>>(
                  future: DatabaseHelper().getAllEntries(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      final best = snapshot.data!
                          .map((e) => e.rating)
                          .reduce((a, b) => a > b ? a : b);
                      return Text(
                        '$best',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      );
                    }
                    return const Text('--');
                  },
                ),
                Icons.emoji_events,
                Colors.purple,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, Widget valueWidget, IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 120,
        height: 160,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Flexible(child: valueWidget),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /*Widget _buildMotivationalCard() {
    final messages = [
      '🌅 La giornata è appena iniziata!',
      '💪 Stai facendo un ottimo lavoro!',
      '🎯 Ogni giorno è una nuova opportunità',
      '✨ Le piccole cose fanno la differenza',
      '🌱 Cresci un giorno alla volta',
    ];

    final randomMessage = messages[DateTime.now().day % messages.length];

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.teal.withOpacity(0.8),
                Colors.cyan.withOpacity(0.6),
              ],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                randomMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Torna alle 18:00 per valutare la tua giornata', // Sostituisci con l10n
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }*/

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _keywordController.dispose();
    _saveAnimationController.dispose();
    _streakAnimationController.dispose();
    _fireAnimationController.dispose();
    super.dispose();
  }

  // Carica i dati dello streak
  void _loadStreakData() async {
    final prefs = await SharedPreferences.getInstance();
    final currentStreak = prefs.getInt('current_streak') ?? 0;
    final bestStreak = prefs.getInt('best_streak') ?? 0;

    setState(() {
      _currentStreak = currentStreak;
      _bestStreak = bestStreak;
    });

    // Anima lo streak se è maggiore di 0
    if (_currentStreak > 0) {
      _streakAnimationController.forward();
    }
  }

  // Calcola lo streak basato sulle entries
  Future<int> _calculateStreak() async {
    //final entries = await DatabaseHelper().getAllEntries();
    //DatabaseHelper().printDatabase();
    final entries = await DatabaseHelper().getAllEntriesWithSlancioTrue();

    if (entries.isEmpty) return 0;

    // Ordina le entries per data (più recenti prima)
    entries.sort(
        (a, b) => DateTime.parse(b.date).compareTo(DateTime.parse(a.date)));

    int streak = 0;
    DateTime today = DateTime.now();
    DateTime checkDate = DateTime(today.year, today.month, today.day);

    // Controlla se c'è un entry per oggi
    bool hasEntryToday = entries.any((entry) {
      final entryDate = DateTime.parse(entry.date);
      final entryDay = DateTime(entryDate.year, entryDate.month, entryDate.day);
      return entryDay.isAtSameMomentAs(checkDate);
    });

    // Se non c'è un entry per oggi, inizia dal giorno precedente
    if (!hasEntryToday) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    // Controlla i giorni consecutivi all'indietro
    for (int i = 0; i < entries.length; i++) {
      final entryDate = DateTime.parse(entries[i].date);
      final entryDay = DateTime(entryDate.year, entryDate.month, entryDate.day);

      if (entryDay.isAtSameMomentAs(checkDate)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (entryDay.isBefore(checkDate)) {
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
      _isNewStreak = wasNewStreak;
      _currentStreak = newStreak;
      if (isNewBest) {
        _bestStreak = newStreak;
      }
    });

    await prefs.setInt('current_streak', _currentStreak);
    await prefs.setInt('best_streak', _bestStreak);

    // Anima lo streak se è cambiato
    if (_currentStreak != newStreak || wasNewStreak) {
      _streakAnimationController.reset();
      await _streakAnimationController.forward();

      // Mostra celebrazione per milestone importanti
      if (_currentStreak % 7 == 0 && _currentStreak > 0) {
        _showStreakCelebration();
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
            child: Text(l10n.fantastic, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _loadTodayEntry() async {
    setState(() => _isLoading = true);

    try {
      final today = DateTime.now();
      final todayString = _getDateKey(today);

      final entries = await DatabaseHelper().getAllEntries();
      final todayEntry = entries
          .where((entry) => entry.date.startsWith(todayString))
          .firstOrNull;

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
      //final entries = await DatabaseHelper().getAllEntriesWithSlancioTrue();
      final last10Entries =
          entries.length > 10 ? entries.sublist(entries.length - 10) : entries;

      final averageRating = last10Entries.isEmpty
          ? _rating
          : (last10Entries.map((e) => e.rating).reduce((a, b) => a + b) /
                  last10Entries.length)
              .round();

      await WidgetService.saveAndUpdateWidget(
        rating: averageRating,
        emoji: _emoji,
        keyword: _keyword,
      );

      await NotiService().cancelNotifications();
      await NotiService().cancelNotifications1();
      await NotiService().cancelNotifications2();

      // Ricarica i dati per aggiornare l'UI
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

  void _showResetDialog() {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            l10n.dialogTitleModifyRating,
            style: const TextStyle(fontWeight: FontWeight.w600),
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
                    Icon(
                      Icons.widgets,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                l10n.dialogButtonOK,
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
            ),
            /*ElevatedButton.icon(
              onPressed: _product != null
                  ? () {
                      final param = PurchaseParam(productDetails: _product!);
                      _iap.buyConsumable(purchaseParam: param);
                      Navigator.of(context).pop(); // chiudi il dialog
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.volunteer_activism, color: Colors.white),
              label: Text(
                "Support DailyFox",
                style: const TextStyle(color: Colors.white),
              ),
            ),*/
          ],
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

  String _getStreakMessage() {
    if (_currentStreak == 0) return AppLocalizations.of(context)!.startS;
    if (_currentStreak == 1) return AppLocalizations.of(context)!.first;
    if (_currentStreak < 7) return AppLocalizations.of(context)!.continua;
    if (_currentStreak < 30) return AppLocalizations.of(context)!.incredibile;
    return AppLocalizations.of(context)!.legend;
  }

  Widget _buildStreakCard() {
    return AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: AnimatedBuilder(
          animation: Listenable.merge(
              [_streakScaleAnimation, _streakOpacityAnimation]),
          builder: (context, child) {
            // Se l'opacità é molto bassa, restituisce un widget vuoto
            if (_streakOpacityAnimation.value < 0.1) {
              return const SizedBox.shrink();
            }

            return Transform.scale(
              scale: _streakScaleAnimation.value,
              child: Opacity(
                opacity: _streakOpacityAnimation.value,
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.orange.withOpacity(0.8),
                            Colors.red.withOpacity(0.6),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)!.slancioDay,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        '$_currentStreak',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _currentStreak == 1
                                            ? AppLocalizations.of(context)!.day
                                            : AppLocalizations.of(context)!
                                                .days,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Record',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '$_bestStreak',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getStreakMessage(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ));
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
                    _getRatingColor(_rating).withOpacity(0.8),
                    _getRatingColor(_rating).withOpacity(0.6),
                  ]
                : [
                    Colors.blue.withOpacity(0.8),
                    Colors.blue.withOpacity(0.6),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (_hasEntryToday ? _getRatingColor(_rating) : Colors.blue)
                  .withOpacity(0.3),
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
                          color: Colors.white.withOpacity(0.9),
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
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _emoji,
                          style: const TextStyle(fontSize: 16),
                        ),
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
                        color: Colors.white.withOpacity(0.9),
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
    final screenHeight = MediaQuery.of(context).size.height;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Se non è ancora ora di valutare la giornata, mostra la schermata di attesa
    if (!_canRateToday()) {
      return _buildWaitingScreen();
    }

    // Altrimenti mostra la normale schermata di valutazione
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _hasEntryToday ? l10n.appTitleModifyDay : l10n.appTitleNewDay,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey[200],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showResetDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(),
            _buildStreakCard(),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                  color: Colors.grey[800],
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
                                        inactiveTrackColor: Colors.grey[300],
                                        thumbColor: _getRatingColor(_rating),
                                        overlayColor: _getRatingColor(_rating)
                                            .withOpacity(0.2),
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
                                  color: Colors.grey[800],
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
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.grey[300]!, width: 2),
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
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          if (_showEmojiPicker) ...[
                            const SizedBox(height: 16),
                            Container(
                              height: 250,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
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
                                        backgroundColor: Colors.white,
                                        columns: 7,
                                      ),
                                      skinToneConfig: const SkinToneConfig(),
                                      categoryViewConfig: CategoryViewConfig(
                                        indicatorColor: theme.primaryColor,
                                        iconColorSelected: theme.primaryColor,
                                      ),
                                    )),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                                  color: Colors.grey[800],
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
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: theme.primaryColor, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _keyword = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
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
                                theme.primaryColor.withOpacity(0.8),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.primaryColor.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
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

class WidgetService {
  static Future<void> saveAndUpdateWidget({
    required int rating,
    required String emoji,
    required String keyword,
  }) async {
    try {
      await HomeWidget.setAppGroupId('group.foxApp');
      await HomeWidget.saveWidgetData('rating', rating);
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
          'Widget updated successfully: Rating $rating, Emoji $emoji, Keyword $keyword');
    } catch (e) {
      debugPrint('Error updating widget: $e');
      rethrow;
    }
  }
}

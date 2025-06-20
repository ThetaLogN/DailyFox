import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:DailyFox/calendarPage.dart';
import 'package:DailyFox/noti_service.dart';
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

  // Configurazione widget iOS
  static const String appGroupId = "group.foxApp";
  static const String iOSWidgetName = "FoxWidget";

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

    // Carica i dati dell'entry di oggi se disponibili
    _loadTodayEntry();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    NotiService().scheduleNotification(context);
  }

  // Carica l'entry di oggi se esiste già
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
      debugPrint(
          'Error loading today\'s entry: $e'); // Non-user-facing, no localization needed
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
    );

    try {
      if (_hasEntryToday && _todayEntry != null) {
        await DatabaseHelper().updateEntry(entry);
      } else {
        await DatabaseHelper().insertEntry(entry);
      }

      final entries = await DatabaseHelper().getAllEntries();
      final averageRating = entries.isEmpty
          ? _rating
          : (entries.map((e) => e.rating).reduce((a, b) => a + b) /
                  entries.length)
              .round();

      await WidgetService.saveAndUpdateWidget(
        rating: averageRating,
        emoji: _emoji,
        keyword: _keyword,
      );
      await NotiService().cancelNotifications();
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
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                l10n.dialogButtonOK,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _saveAnimationController.dispose();
    super.dispose();
  }

  void _debugPrintAllEntries() async {
    final entries = await DatabaseHelper().getAllEntries();
    debugPrint('=== DEBUG: All entries ===');
    for (var entry in entries) {
      debugPrint(
          'ID: ${entry.id} | Rating: ${entry.rating} | Emoji: ${entry.emoji} | Keyword: ${entry.keyword} | Date: ${entry.date}');
    }
    debugPrint('=== End DEBUG ===');
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
                                    columns: 8,
                                    emojiSizeMax: 28,
                                    bgColor: Colors.white,
                                    indicatorColor: theme.primaryColor,
                                    iconColorSelected: theme.primaryColor,
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
          'keyword', keyword.isEmpty ? 'Today' : keyword); // Localized in .arb?
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

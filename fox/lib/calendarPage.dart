import 'dart:math';

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../models/diary_entry.dart';
import '../helpers/database_helper.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadEntries();
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

  bool _canAddEntry(DateTime date) {
    final today = DateTime.now();
    final dateOnly = DateTime(date.year, date.month, date.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    return dateOnly.isBefore(todayOnly);
  }

  void _showAddEntryDialog(DateTime date) {
    int selectedRating = 5;
    String selectedEmoji = '😊';
    String keyword = '';
    final TextEditingController keywordController = TextEditingController();
    bool showEmojiPicker = false;

    showDialog(
      context: context,
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
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${l10n.addedit}${_getFormattedDate(date)}',
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
                            // Sezione Rating
                            Text(
                              l10n.ratingCardTitle,
                              style: TextStyle(
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

                            // Sezione Emoji
                            const Text(
                              'Emoji:',
                              style: TextStyle(
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
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: Colors.grey[300]!),
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

                            // Emoji Picker
                            if (showEmojiPicker)
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
                                        backgroundColor: Colors.white,
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

                            // Sezione Keyword
                            Text(
                              l10n.keywordCardTitle,
                              style: TextStyle(
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
                                keyword = value;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Actions
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text(l10n.annulla),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              await _saveEntry(
                                  date, selectedRating, selectedEmoji, keyword);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getRatingColor(selectedRating),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(l10n.saveButtonNew),
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

  Future<void> _saveEntry(
      DateTime date, int rating, String emoji, String keyword) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final entry = DiaryEntry(
        date: _getDateKey(date),
        rating: rating,
        emoji: emoji,
        keyword: keyword.isNotEmpty ? keyword : null,
        slancio: false,
      );

      await DatabaseHelper().insertEntry(entry);
      await _loadEntries();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.snackBarUpdatedSuccess),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.snackBarSaveError),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCalendarCell(DateTime day, bool isToday, bool isSelected) {
    final dateKey = _getDateKey(day);
    final entry = _entries[dateKey];
    final hasEntry = entry != null;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: hasEntry
            ? _getRatingColor(entry.rating).withOpacity(0.3)
            : (isToday ? Colors.blue.withOpacity(0.1) : null),
        border: Border.all(
          color: isSelected
              ? Colors.blue
              : (isToday ? Colors.blue.withOpacity(0.5) : Colors.transparent),
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
                color: hasEntry
                    ? Colors.grey[800]
                    : (isToday ? Colors.blue : Colors.grey[600]),
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

  Widget _buildSelectedDayDetails() {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedDay == null) return const SizedBox.shrink();

    final dateKey = _getDateKey(_selectedDay!);
    final entry = _entries[dateKey];

    if (entry == null) {
      final canAddEntry = _canAddEntry(_selectedDay!);
      return Card(
        margin: const EdgeInsets.all(16),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.calendar_today,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.noEntryMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getFormattedDate(_selectedDay!),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 16),
              if (canAddEntry) ...[
                ElevatedButton.icon(
                  onPressed: () => _showAddEntryDialog(_selectedDay!),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addreting),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.orange[700],
                      ),
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
              _getRatingColor(entry.rating).withOpacity(0.1),
              _getRatingColor(entry.rating).withOpacity(0.05),
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
                      color: _getRatingColor(entry.rating).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getFormattedDate(_selectedDay!),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getRatingColor(entry.rating),
                      ),
                    ),
                  ),
                  if (_canAddEntry(_selectedDay!))
                    IconButton(
                      onPressed: () => _showAddEntryDialog(_selectedDay!),
                      icon: const Icon(Icons.edit),
                      tooltip: 'Modifica valutazione',
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
                          color: _getRatingColor(entry.rating).withOpacity(0.3),
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
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[300]!, width: 2),
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
                            color: Colors.grey[600],
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
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.label_outline,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.keywordCardTitle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        entry.keyword!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          l10n.calendarTitle,
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
            icon: const Icon(Icons.refresh),
            onPressed: _loadEntries,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TableCalendar<DiaryEntry>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
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
                        _focusedDay = focusedDay;
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
                        formatButtonVisible: true,
                        titleCentered: true,
                        formatButtonShowsNext: false,
                        formatButtonDecoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        formatButtonTextStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        weekendTextStyle: TextStyle(color: Colors.grey[600]),
                        holidayTextStyle: TextStyle(color: Colors.grey[600]),
                        defaultTextStyle: TextStyle(color: Colors.grey[800]),
                        cellMargin: const EdgeInsets.all(4),
                        cellPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildSelectedDayDetails(),
                  ),
                ),
              ],
            ),
    );
  }
}

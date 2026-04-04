import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../helpers/badge_helper.dart';
import '../models/badge.dart';
import '../widgets/badge_card.dart';

class BadgesPage extends StatefulWidget {
  final int currentStreak;

  const BadgesPage({super.key, required this.currentStreak});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  List<DailyBadge> _badges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    final badges = await BadgeHelper.loadBadges();
    setState(() {
      _badges = badges;
      _isLoading = false;
    });
  }

  int get _unlockedCount => _badges.where((b) => b.isUnlocked).length;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final nextBadge = BadgeHelper.nextBadge(widget.currentStreak);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          l10n.badgesPageTitle,
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(cs, nextBadge, l10n),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.78,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return BadgeCard(
                          badge: _badges[index],
                          showDescription: true,
                        );
                      },
                      childCount: _badges.length,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader(ColorScheme cs, DailyBadge? nextBadge, AppLocalizations l10n) {
    final progress = nextBadge != null
        ? (widget.currentStreak / nextBadge.requiredStreak).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Card riepilogo
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.amber.withValues(alpha: 0.15),
                    Colors.orange.withValues(alpha: 0.08),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🏆', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            Text(
                              l10n.badgesCollectionTitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.badgesUnlocked(_unlockedCount, _badges.length),
                          style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _badges.isEmpty
                                ? 0
                                : _unlockedCount / _badges.length,
                            minHeight: 8,
                            backgroundColor:
                                cs.outlineVariant.withValues(alpha: 0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.amber),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${widget.currentStreak}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        Text(
                          l10n.days, // 'Giorni'
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Prossimo badge
          if (nextBadge != null) ...[
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.trending_up,
                            size: 18, color: cs.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          l10n.badgesNextMilestone,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(nextBadge.emoji,
                            style: const TextStyle(fontSize: 32)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                BadgeHelper.localizedName(nextBadge.id, l10n),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.badgesDaysLeft(
                                    nextBadge.requiredStreak - widget.currentStreak),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor:
                                      cs.outlineVariant.withValues(alpha: 0.3),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.orange.shade600,
                                  ),
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
          ] else ...[
            const SizedBox(height: 12),
            Card(
              color: Colors.amber.shade50,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('👑', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.badgesAllUnlocked,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

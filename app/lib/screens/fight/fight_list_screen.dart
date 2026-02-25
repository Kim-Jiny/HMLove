import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../providers/fight_provider.dart';

enum FightFilter { all, unresolved, resolved }

class FightListScreen extends ConsumerStatefulWidget {
  const FightListScreen({super.key});

  @override
  ConsumerState<FightListScreen> createState() => _FightListScreenState();
}

class _FightListScreenState extends ConsumerState<FightListScreen> {
  FightFilter _currentFilter = FightFilter.all;
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(fightProvider.notifier).fetchFights();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fightState = ref.watch(fightProvider);
    final allFights = fightState.fights;

    // Filter fights
    final fights = allFights.where((fight) {
      switch (_currentFilter) {
        case FightFilter.all:
          return true;
        case FightFilter.unresolved:
          return !fight.isResolved;
        case FightFilter.resolved:
          return fight.isResolved;
      }
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('다툼 기록'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: '전체',
                  isSelected: _currentFilter == FightFilter.all,
                  onTap: () => setState(() => _currentFilter = FightFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '미해결',
                  isSelected: _currentFilter == FightFilter.unresolved,
                  onTap: () =>
                      setState(() => _currentFilter = FightFilter.unresolved),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '해결됨',
                  isSelected: _currentFilter == FightFilter.resolved,
                  onTap: () =>
                      setState(() => _currentFilter = FightFilter.resolved),
                ),
              ],
            ),
          ),
        ),
      ),
      body: fightState.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : fights.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: () async {
                    await ref.read(fightProvider.notifier).fetchFights();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: fights.length,
                    itemBuilder: (context, index) {
                      final fight = fights[index];
                      final isExpanded = _expandedIds.contains(fight.id);

                      return _FightCard(
                        fight: fight,
                        isExpanded: isExpanded,
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedIds.remove(fight.id);
                            } else {
                              _expandedIds.add(fight.id);
                            }
                          });
                        },
                        onEdit: () async {
                          await context.push('/fight/write', extra: fight);
                          setState(() => _expandedIds.clear());
                        },
                        onDelete: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('삭제 확인'),
                              content: const Text('이 기록을 삭제하시겠습니까?'),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('취소'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text(
                                    '삭제',
                                    style:
                                        TextStyle(color: AppTheme.errorColor),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref
                                .read(fightProvider.notifier)
                                .deleteFight(fight.id);
                          }
                        },
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/fight/write');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    switch (_currentFilter) {
      case FightFilter.all:
        message = '아직 기록이 없어요';
      case FightFilter.unresolved:
        message = '미해결 다툼이 없어요';
      case FightFilter.resolved:
        message = '해결된 다툼이 없어요';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_outlined,
              size: 40,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '다툼을 기록하고 함께 성장해요',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : AppTheme.textHint.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _FightCard extends StatelessWidget {
  final Fight fight;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FightCard({
    required this.fight,
    required this.isExpanded,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isResolved = fight.isResolved;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Date
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('yyyy년 M월 d일').format(fight.date),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  // Resolved badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isResolved
                          ? AppTheme.successColor.withValues(alpha: 0.1)
                          : AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isResolved ? Icons.check_circle : Icons.cancel,
                          size: 14,
                          color: isResolved
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isResolved ? '해결됨' : '미해결',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isResolved
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Reason
              Text(
                fight.reason,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: isExpanded ? null : 2,
                overflow: isExpanded ? null : TextOverflow.ellipsis,
              ),

              // Expanded content
              if (isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),

                // Resolution
                if (fight.resolution != null &&
                    fight.resolution!.isNotEmpty) ...[
                  _SectionLabel(
                    icon: Icons.handshake_outlined,
                    label: '해결 방법',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fight.resolution!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Reflection
                if (fight.reflection != null &&
                    fight.reflection!.isNotEmpty) ...[
                  _SectionLabel(
                    icon: Icons.lightbulb_outline,
                    label: '반성 / 느낀 점',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    fight.reflection!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('수정'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('삭제'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
              ],

              // Expand indicator
              if (!isExpanded)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppTheme.textHint,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }
}

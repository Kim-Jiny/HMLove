import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../providers/calendar_provider.dart';

class AnniversaryScreen extends ConsumerStatefulWidget {
  const AnniversaryScreen({super.key});

  @override
  ConsumerState<AnniversaryScreen> createState() => _AnniversaryScreenState();
}

class _AnniversaryScreenState extends ConsumerState<AnniversaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _autoAnniversaries = [];
  List<Map<String, dynamic>> _customAnniversaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAnniversaries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAnniversaries() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/couple/anniversaries');
      final data = response.data as Map<String, dynamic>;

      final autoList = (data['auto'] as List<dynamic>)
          .map((e) => {
                'title': e['title'] as String,
                'date': DateTime.parse(e['date'] as String),
                'type': 'auto',
                'repeatType': e['repeatType'] as String? ?? 'NONE',
              })
          .toList();

      final customList = (data['custom'] as List<dynamic>)
          .map((e) => {
                'id': e['id'] as String,
                'title': e['title'] as String,
                'date': DateTime.parse(e['date'] as String),
                'description': e['description'] as String?,
                'repeatType': e['repeatType'] as String? ?? 'NONE',
                'type': 'custom',
              })
          .toList();

      setState(() {
        _autoAnniversaries = autoList;
        _customAnniversaries = customList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getUpcoming() {
    final now = DateTime.now();
    final endOfYear = DateTime(now.year, 12, 31);

    final all = <Map<String, dynamic>>[];

    // Auto anniversaries remaining this year
    for (final a in _autoAnniversaries) {
      final date = a['date'] as DateTime;
      if (date.isAfter(now.subtract(const Duration(days: 1))) &&
          !date.isAfter(endOfYear)) {
        all.add(a);
      }
    }

    // Custom anniversaries - for YEARLY, compute this year's occurrence
    for (final a in _customAnniversaries) {
      final origDate = a['date'] as DateTime;
      final repeat = a['repeatType'] as String;

      if (repeat == 'YEARLY') {
        var thisYear = DateTime(now.year, origDate.month, origDate.day);
        if (thisYear.isBefore(now)) {
          thisYear = DateTime(now.year + 1, origDate.month, origDate.day);
        }
        if (!thisYear.isAfter(endOfYear.add(const Duration(days: 365)))) {
          all.add({...a, 'date': thisYear});
        }
      } else if (repeat == 'MONTHLY') {
        // Next monthly occurrence
        var next = DateTime(now.year, now.month, origDate.day);
        if (next.isBefore(now)) {
          next = DateTime(now.year, now.month + 1, origDate.day);
        }
        if (!next.isAfter(endOfYear)) {
          all.add({...a, 'date': next});
        }
      } else {
        final date = origDate;
        if (date.isAfter(now.subtract(const Duration(days: 1)))) {
          all.add(a);
        }
      }
    }

    all.sort((a, b) =>
        (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    return all;
  }

  List<Map<String, dynamic>> _getPast() {
    final now = DateTime.now();
    final all = <Map<String, dynamic>>[];

    for (final a in _autoAnniversaries) {
      final date = a['date'] as DateTime;
      if (date.isBefore(now)) {
        all.add(a);
      }
    }

    for (final a in _customAnniversaries) {
      final origDate = a['date'] as DateTime;
      final repeat = a['repeatType'] as String;

      if (repeat == 'YEARLY') {
        // Show all past yearly occurrences this year and before
        var thisYear = DateTime(now.year, origDate.month, origDate.day);
        if (thisYear.isBefore(now)) {
          all.add({...a, 'date': thisYear});
        }
      } else if (repeat == 'NONE' && origDate.isBefore(now)) {
        all.add(a);
      }
    }

    all.sort((a, b) =>
        (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return all;
  }

  void _showAddAnniversary() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String repeatType = 'YEARLY';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '기념일 추가',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: '기념일 이름',
                  hintText: '예: 결혼기념일, 첫 데이트',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: '메모 (선택)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Date picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                              primary: AppTheme.primaryColor,
                            ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setModalState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 20, color: AppTheme.textSecondary),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('yyyy년 M월 d일').format(selectedDate),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Repeat type
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: repeatType,
                    items: const [
                      DropdownMenuItem(value: 'NONE', child: Text('반복 없음')),
                      DropdownMenuItem(
                          value: 'YEARLY', child: Text('매년 반복')),
                      DropdownMenuItem(
                          value: 'MONTHLY', child: Text('매월 반복')),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => repeatType = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('기념일 이름을 입력해주세요.')),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    final success =
                        await ref.read(calendarProvider.notifier).createEvent(
                              title: titleController.text.trim(),
                              date: selectedDate,
                              description: descController.text.trim().isEmpty
                                  ? null
                                  : descController.text.trim(),
                              isAnniversary: true,
                              repeatType: repeatType,
                            );
                    if (success) {
                      _fetchAnniversaries();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('기념일이 추가되었습니다.')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('추가하기',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm(Map<String, dynamic> anniversary) {
    final id = anniversary['id'] as String?;
    if (id == null) return; // auto anniversaries can't be deleted

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기념일 삭제'),
        content: Text("'${anniversary['title']}'를 삭제하시겠습니까?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await ref.read(calendarProvider.notifier).deleteEvent(id);
              if (success) {
                _fetchAnniversaries();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('기념일이 삭제되었습니다.')),
                  );
                }
              }
            },
            child: const Text('삭제',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기념일'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: '다가오는 기념일'),
            Tab(text: '지난 기념일'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAnniversary,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUpcomingList(),
                _buildPastList(),
              ],
            ),
    );
  }

  Widget _buildUpcomingList() {
    final upcoming = _getUpcoming();

    if (upcoming.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration_outlined,
                size: 64, color: AppTheme.textHint),
            SizedBox(height: 12),
            Text('올해 남은 기념일이 없어요',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAnniversaries,
      color: AppTheme.primaryColor,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: upcoming.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return _AnniversaryTile(
            anniversary: upcoming[index],
            onLongPress: upcoming[index]['type'] == 'custom'
                ? () => _showDeleteConfirm(upcoming[index])
                : null,
          );
        },
      ),
    );
  }

  Widget _buildPastList() {
    final past = _getPast();

    if (past.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: AppTheme.textHint),
            SizedBox(height: 12),
            Text('지난 기념일이 없어요',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAnniversaries,
      color: AppTheme.primaryColor,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: past.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return _AnniversaryTile(
            anniversary: past[index],
            isPast: true,
            onLongPress: past[index]['type'] == 'custom'
                ? () => _showDeleteConfirm(past[index])
                : null,
          );
        },
      ),
    );
  }
}

class _AnniversaryTile extends StatelessWidget {
  final Map<String, dynamic> anniversary;
  final bool isPast;
  final VoidCallback? onLongPress;

  const _AnniversaryTile({
    required this.anniversary,
    this.isPast = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final title = anniversary['title'] as String;
    final date = anniversary['date'] as DateTime;
    final type = anniversary['type'] as String;
    final repeatType = anniversary['repeatType'] as String? ?? 'NONE';
    final description = anniversary['description'] as String?;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(date.year, date.month, date.day);
    final daysLeft = targetDay.difference(today).inDays;

    final isCustom = type == 'custom';
    final iconColor =
        isCustom ? const Color(0xFFE91E63) : AppTheme.primaryColor;
    final icon = isCustom ? Icons.favorite : Icons.celebration;

    String repeatLabel = '';
    if (repeatType == 'YEARLY') {
      repeatLabel = '매년';
    } else if (repeatType == 'MONTHLY') {
      repeatLabel = '매월';
    }

    return Card(
      child: InkWell(
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (repeatLabel.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              repeatLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('yyyy년 M월 d일 (E)', 'ko').format(date),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textHint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isPast
                        ? (daysLeft == 0 ? '오늘' : '${-daysLeft}일 전')
                        : (daysLeft == 0 ? 'D-Day' : 'D-$daysLeft'),
                    style: TextStyle(
                      fontSize: isPast ? 14 : 18,
                      fontWeight: FontWeight.bold,
                      color: daysLeft == 0
                          ? const Color(0xFFE91E63)
                          : isPast
                              ? AppTheme.textSecondary
                              : AppTheme.primaryColor,
                    ),
                  ),
                  if (!isPast && daysLeft > 0)
                    Text(
                      '${date.month}/${date.day}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textHint,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

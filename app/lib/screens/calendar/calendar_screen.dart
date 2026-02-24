import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/theme.dart';
import '../../providers/calendar_provider.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    Future.microtask(() {
      final yearMonth = DateFormat('yyyy-MM').format(_focusedDay);
      ref.read(calendarProvider.notifier).fetchEvents(yearMonth);
      ref.read(calendarProvider.notifier).selectDay(_selectedDay!);
    });
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final calendarState = ref.read(calendarProvider);
    return calendarState.getEventsForDay(day);
  }

  void _onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    final yearMonth = DateFormat('yyyy-MM').format(focusedDay);
    ref.read(calendarProvider.notifier).fetchEvents(yearMonth);
  }

  void _showAddEventSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '추가하기',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _AddOptionTile(
              icon: Icons.event,
              title: '일정 추가',
              subtitle: '기념일이나 약속을 추가하세요',
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.pop(context);
                _showCreateEventDialog();
              },
            ),
            const SizedBox(height: 12),
            _AddOptionTile(
              icon: Icons.mail_outline,
              title: '편지 쓰기',
              subtitle: '사랑하는 사람에게 편지를 보내세요',
              color: const Color(0xFFFF9800),
              onTap: () {
                Navigator.pop(context);
                final selectedDate = _selectedDay ?? DateTime.now();
                final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
                context.push('/letter/write?date=$dateStr');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showCreateEventDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isAnniversary = false;
    String repeatType = 'NONE';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            '새 일정',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    hintText: '일정 제목을 입력하세요',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '설명 (선택)',
                    hintText: '일정에 대한 설명을 입력하세요',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('날짜: '),
                    Text(
                      _selectedDay != null
                          ? DateFormat('yyyy년 M월 d일').format(_selectedDay!)
                          : '선택 안 됨',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: isAnniversary,
                  onChanged: (v) =>
                      setDialogState(() => isAnniversary = v ?? false),
                  title: const Text('기념일로 표시', style: TextStyle(fontSize: 14)),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                DropdownButtonFormField<String>(
                  value: repeatType,
                  decoration: const InputDecoration(
                    labelText: '반복',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'NONE', child: Text('반복 없음')),
                    DropdownMenuItem(value: 'YEARLY', child: Text('매년')),
                    DropdownMenuItem(value: 'MONTHLY', child: Text('매월')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => repeatType = v ?? 'NONE'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                final date = _selectedDay ?? DateTime.now();
                final success =
                    await ref.read(calendarProvider.notifier).createEvent(
                          title: title,
                          date: date,
                          description: descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim(),
                          isAnniversary: isAnniversary,
                          repeatType: repeatType,
                        );

                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('일정이 추가되었습니다')),
                    );
                  } else {
                    final error = ref.read(calendarProvider).error;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error ?? '일정 추가에 실패했습니다')),
                    );
                  }
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendarState = ref.watch(calendarProvider);
    final selectedEvents = ref.watch(selectedDayEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('캘린더'),
      ),
      body: Column(
        children: [
          // Calendar Widget
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TableCalendar<CalendarEvent>(
              firstDay: DateTime(2020, 1, 1),
              lastDay: DateTime(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              locale: 'ko_KR',
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: _getEventsForDay,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                titleTextStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                formatButtonTextStyle: const TextStyle(fontSize: 12),
                formatButtonDecoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryColor),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: AppTheme.primaryLight.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                markerDecoration: const BoxDecoration(
                  color: AppTheme.accentColor,
                  shape: BoxShape.circle,
                ),
                markerSize: 6,
                markersMaxCount: 3,
                outsideDaysVisible: false,
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                ref.read(calendarProvider.notifier).selectDay(selectedDay);
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              onPageChanged: _onPageChanged,
            ),
          ),
          const SizedBox(height: 8),

          // Loading indicator
          if (calendarState.isLoading)
            const LinearProgressIndicator(
              color: AppTheme.primaryColor,
              backgroundColor: Colors.transparent,
            ),

          // Events List
          Expanded(
            child: _buildEventsList(selectedEvents),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEventSheet,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEventsList(List<CalendarEvent> events) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              _selectedDay != null
                  ? '${DateFormat('M월 d일').format(_selectedDay!)}에 일정이 없습니다'
                  : '날짜를 선택하세요',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isAutoAnniversary = event.isAuto;

        Color iconBgColor;
        Color iconColor;
        IconData icon;

        if (isAutoAnniversary) {
          iconBgColor = const Color(0xFFFCE4EC);
          iconColor = const Color(0xFFE91E63);
          icon = event.title.contains('생일')
              ? Icons.cake
              : Icons.celebration;
        } else if (event.isAnniversary) {
          iconBgColor = AppTheme.primaryLight.withValues(alpha: 0.2);
          iconColor = AppTheme.primaryColor;
          icon = Icons.favorite;
        } else {
          iconBgColor = const Color(0xFFE3F2FD);
          iconColor = const Color(0xFF1976D2);
          icon = Icons.event;
        }

        return Card(
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isAutoAnniversary) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCE4EC),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '자동',
                      style: TextStyle(
                        fontSize: 9,
                        color: Color(0xFFE91E63),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: event.description != null
                ? Text(
                    event.description!,
                    style: const TextStyle(fontSize: 12),
                  )
                : null,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  DateFormat('M/d').format(event.date),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (event.repeatType != null && event.repeatType != 'NONE')
                  Text(
                    event.repeatType == 'YEARLY' ? '매년' : '매월',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textHint,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Add Option Tile Widget
class _AddOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AddOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

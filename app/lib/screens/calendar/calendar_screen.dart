import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/device_calendar_service.dart';
import '../../core/theme.dart';
import '../../core/top_snackbar.dart';
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

  static const _moodEmojiMap = {
    'happy': '😊',
    'love': '🥰',
    'excited': '🤩',
    'grateful': '🙏',
    'peaceful': '😌',
    'proud': '😎',
    'missing': '🥺',
    'bored': '😐',
    'sad': '😢',
    'angry': '😤',
    'tired': '😴',
    'stressed': '😩',
  };

  String _moodKeyToEmoji(String key) => _moodEmojiMap[key] ?? key;

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    final calendarState = ref.read(calendarProvider);
    return calendarState.getEventsForDay(day);
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  void _onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    final yearMonth = DateFormat('yyyy-MM').format(focusedDay);
    ref.read(calendarProvider.notifier).fetchEvents(yearMonth);
  }

  void _showDeviceCalendarSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _DeviceCalendarSettingsSheet(
        notifier: ref.read(calendarProvider.notifier),
        isEnabled: ref.read(calendarProvider).deviceCalendarEnabled,
        onChanged: () {
          // 설정 변경 후 이벤트 다시 가져오기
          final yearMonth = DateFormat('yyyy-MM').format(_focusedDay);
          ref.read(calendarProvider.notifier).fetchEvents(yearMonth);
        },
      ),
    );
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

  void _showEventDetail(CalendarEvent event) {
    final isUserEvent = !event.isAuto && event.eventType != 'feed' && event.eventType != 'device';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (event.isAuto)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCE4EC),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '자동',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFE91E63),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow(
              Icons.calendar_today,
              DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(event.date),
            ),
            if (event.description != null && event.description!.isNotEmpty)
              _detailRow(Icons.notes, event.description!),
            if (event.repeatType != null && event.repeatType != 'NONE')
              _detailRow(
                Icons.repeat,
                event.repeatType == 'YEARLY' ? '매년 반복' : '매월 반복',
              ),
            if (event.eventType == 'feed')
              _detailRow(Icons.photo_library, '피드 게시물'),
            if (event.isAnniversary && !event.isAuto)
              _detailRow(Icons.favorite, '기념일'),
            if (isUserEvent) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditEventDialog(event);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('수정'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showDeleteConfirm(event);
                      },
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      label: const Text('삭제',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
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

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(CalendarEvent event) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 삭제', style: TextStyle(fontSize: 16)),
        content: Text("'${event.title}' 일정을 삭제하시겠습니까?"),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(calendarProvider.notifier)
                  .deleteEvent(event.id);
              if (mounted) {
                if (success) {
                  showTopSnackBar(context, '일정이 삭제되었습니다');
                } else {
                  showTopSnackBar(context, '일정 삭제에 실패했습니다', isError: true);
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showEditEventDialog(CalendarEvent event) {
    final titleController = TextEditingController(text: event.title);
    final descriptionController =
        TextEditingController(text: event.description ?? '');
    bool isAnniversary = event.isAnniversary;
    String repeatType = event.repeatType ?? 'NONE';
    bool isSubmitting = false;
    final outerContext = context;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            '일정 수정',
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
                      DateFormat('yyyy년 M월 d일').format(event.date),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: isAnniversary,
                  onChanged: (v) =>
                      setDialogState(() => isAnniversary = v ?? false),
                  title:
                      const Text('기념일로 표시', style: TextStyle(fontSize: 14)),
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
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;

                      setDialogState(() => isSubmitting = true);

                      final success = await ref
                          .read(calendarProvider.notifier)
                          .updateEvent(
                            id: event.id,
                            title: title,
                            description:
                                descriptionController.text.trim().isEmpty
                                    ? null
                                    : descriptionController.text.trim(),
                            isAnniversary: isAnniversary,
                            repeatType: repeatType,
                          );

                      if (context.mounted) {
                        Navigator.pop(context);
                        if (success) {
                          showTopSnackBar(outerContext, '일정이 수정되었습니다');
                        } else {
                          final error = ref.read(calendarProvider).error;
                          showTopSnackBar(outerContext, error ?? '일정 수정에 실패했습니다', isError: true);
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('수정'),
            ),
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
    bool isSubmitting = false;
    final outerContext = context;

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
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;

                      setDialogState(() => isSubmitting = true);

                      final date = _selectedDay ?? DateTime.now();
                      final success = await ref
                          .read(calendarProvider.notifier)
                          .createEvent(
                            title: title,
                            date: date,
                            description:
                                descriptionController.text.trim().isEmpty
                                    ? null
                                    : descriptionController.text.trim(),
                            isAnniversary: isAnniversary,
                            repeatType: repeatType,
                          );

                      if (context.mounted) {
                        Navigator.pop(context);
                        if (success) {
                          showTopSnackBar(outerContext, '일정이 추가되었습니다');
                        } else {
                          final error = ref.read(calendarProvider).error;
                          showTopSnackBar(outerContext, error ?? '일정 추가에 실패했습니다', isError: true);
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('추가'),
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
        actions: [
          IconButton(
            icon: Icon(
              calendarState.deviceCalendarEnabled
                  ? Icons.sync
                  : Icons.sync_disabled,
              color: calendarState.deviceCalendarEnabled
                  ? AppTheme.primaryColor
                  : null,
            ),
            tooltip: '기기 캘린더 연동',
            onPressed: _showDeviceCalendarSettings,
          ),
        ],
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
                markersMaxCount: 0, // 기본 마커 숨김 (커스텀 사용)
                outsideDaysVisible: false,
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;

                  final types = <String>{};
                  for (final e in events) {
                    types.add(e.eventType);
                  }
                  final dots = <Widget>[];
                  if (types.contains('anniversary')) {
                    dots.add(_buildDot(const Color(0xFFE91E63)));
                  }
                  if (types.contains('schedule')) {
                    dots.add(_buildDot(const Color(0xFF1976D2)));
                  }
                  if (types.contains('feed')) {
                    dots.add(_buildDot(const Color(0xFFFF9800)));
                  }
                  if (types.contains('device')) {
                    dots.add(_buildDot(const Color(0xFF4CAF50)));
                  }

                  return Positioned(
                    bottom: 1,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: dots,
                    ),
                  );
                },
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
          const SizedBox(height: 4),

          // 범례
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildLegend(const Color(0xFFE91E63), '기념일'),
                const SizedBox(width: 12),
                _buildLegend(const Color(0xFF1976D2), '일정'),
                const SizedBox(width: 12),
                _buildLegend(const Color(0xFFFF9800), '피드'),
                if (calendarState.deviceCalendarEnabled) ...[
                  const SizedBox(width: 12),
                  _buildLegend(const Color(0xFF4CAF50), '기기'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Loading indicator
          if (calendarState.isLoading)
            const LinearProgressIndicator(
              color: AppTheme.primaryColor,
              backgroundColor: Colors.transparent,
            ),

          // Mood for selected day
          if (_selectedDay != null &&
              calendarState.getMoodsForDay(_selectedDay!).isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: calendarState
                    .getMoodsForDay(_selectedDay!)
                    .map((mood) => Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _moodKeyToEmoji(mood.emoji),
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                mood.nickname,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),

          // Events List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final yearMonth = DateFormat('yyyy-MM').format(_focusedDay);
                await ref.read(calendarProvider.notifier).fetchEvents(yearMonth);
              },
              child: _buildEventsList(selectedEvents),
            ),
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
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(
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
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isAutoAnniversary = event.isAuto;

        Color iconBgColor;
        Color iconColor;
        IconData icon;

        if (event.eventType == 'device') {
          iconBgColor = const Color(0xFFE8F5E9);
          iconColor = const Color(0xFF4CAF50);
          icon = Icons.event_note;
        } else if (event.eventType == 'feed') {
          iconBgColor = const Color(0xFFFFF3E0);
          iconColor = const Color(0xFFFF9800);
          icon = Icons.photo_library;
        } else if (isAutoAnniversary) {
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

        // 사용자가 만든 일정만 탭/삭제 가능
        final isUserEvent =
            !event.isAuto && event.eventType != 'feed' && event.eventType != 'device';

        return Card(
          child: ListTile(
            onTap: () => _showEventDetail(event),
            onLongPress: isUserEvent
                ? () => _showDeleteConfirm(event)
                : null,
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

// 기기 캘린더 설정 바텀시트
class _DeviceCalendarSettingsSheet extends StatefulWidget {
  final CalendarNotifier notifier;
  final bool isEnabled;
  final VoidCallback onChanged;

  const _DeviceCalendarSettingsSheet({
    required this.notifier,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  State<_DeviceCalendarSettingsSheet> createState() =>
      _DeviceCalendarSettingsSheetState();
}

class _DeviceCalendarSettingsSheetState
    extends State<_DeviceCalendarSettingsSheet> {
  late bool _isEnabled;
  List<dc.Calendar> _calendars = [];
  List<dc.Calendar> _writableCalendars = [];
  List<String> _selectedIds = [];
  String? _defaultWriteCalendarId;
  bool _syncPartner = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.isEnabled;
    _defaultWriteCalendarId = widget.notifier.getDefaultWriteCalendarId();
    _syncPartner = widget.notifier.isSyncPartnerEnabled();
    if (_isEnabled) {
      _loadCalendars();
    }
  }

  Future<void> _loadCalendars() async {
    setState(() => _isLoading = true);
    final calendars = await widget.notifier.getAvailableCalendars();
    final writable = await widget.notifier.getWritableCalendars();
    final selectedIds = widget.notifier.getSelectedCalendarIds();
    final writeId = widget.notifier.getDefaultWriteCalendarId();
    if (mounted) {
      setState(() {
        _calendars = calendars;
        _writableCalendars = writable;
        _selectedIds = selectedIds;
        _defaultWriteCalendarId = writeId;
        _isLoading = false;
      });
    }
  }

  /// 권한 요청 → 거부 시 설정 이동 팝업
  Future<bool> _ensurePermission() async {
    // 이미 권한 있는지 확인
    final hasPerm = await DeviceCalendarService.hasPermission();
    if (hasPerm) return true;

    // 권한 요청
    final granted = await DeviceCalendarService.requestPermission();
    if (granted) return true;

    // 거부됨 → 설정 이동 팝업
    if (!mounted) return false;
    final goToSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('캘린더 권한 필요'),
        content: const Text(
          '캘린더를 연동하려면 캘린더 접근 권한이 필요합니다.\n'
          '설정에서 캘린더 권한을 허용해주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );

    if (goToSettings == true) {
      await Geolocator.openAppSettings();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
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
            '기기 캘린더 연동',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '구글/애플 캘린더와 일정을 동기화합니다',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),

          // 동기화 토글
          SwitchListTile(
            value: _isEnabled,
            onChanged: (enabled) async {
              if (enabled) {
                final hasPermission = await _ensurePermission();
                if (!hasPermission) return;
              }

              await widget.notifier.toggleDeviceCalendar(enabled);
              setState(() => _isEnabled = enabled);

              if (enabled) {
                await _loadCalendars();
                // 쓰기 캘린더 자동 설정 (없으면 첫 번째 쓰기 가능 캘린더)
                if (_defaultWriteCalendarId == null &&
                    _writableCalendars.isNotEmpty) {
                  final firstId = _writableCalendars.first.id!;
                  await widget.notifier.setDefaultWriteCalendarId(firstId);
                  setState(() => _defaultWriteCalendarId = firstId);
                }
              } else {
                setState(() {
                  _calendars = [];
                  _writableCalendars = [];
                  _selectedIds = [];
                });
              }
              widget.onChanged();
            },
            title: const Text(
              '캘린더 동기화',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _isEnabled ? '연동 중' : '꺼짐',
              style: const TextStyle(fontSize: 12),
            ),
            secondary: Icon(
              Icons.calendar_month,
              color: _isEnabled ? AppTheme.primaryColor : AppTheme.textHint,
            ),
            activeColor: AppTheme.primaryColor,
            contentPadding: EdgeInsets.zero,
          ),

          // 캘린더 목록
          if (_isEnabled && _isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          if (_isEnabled && !_isLoading && _calendars.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 8),

            // 기본 쓰기 캘린더 선택
            if (_writableCalendars.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '일정 기록 캘린더',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '앱에서 추가한 일정이 저장될 캘린더',
                  style: TextStyle(fontSize: 11, color: AppTheme.textHint),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _writableCalendars.any(
                            (c) => c.id == _defaultWriteCalendarId)
                        ? _defaultWriteCalendarId
                        : _writableCalendars.first.id,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: _writableCalendars.map((cal) {
                      return DropdownMenuItem<String>(
                        value: cal.id,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: cal.color != null
                                    ? Color(cal.color!)
                                    : const Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                cal.name ?? '(이름 없음)',
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (id) async {
                      if (id == null) return;
                      await widget.notifier.setDefaultWriteCalendarId(id);
                      setState(() => _defaultWriteCalendarId = id);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 상대방 일정 동기화 토글
            SwitchListTile(
              value: _syncPartner,
              onChanged: (value) async {
                await widget.notifier.setSyncPartnerEnabled(value);
                setState(() => _syncPartner = value);
              },
              title: const Text(
                '상대방 일정도 동기화',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text(
                '상대방이 추가한 일정도 기기 캘린더에 저장',
                style: TextStyle(fontSize: 11, color: AppTheme.textHint),
              ),
              secondary: Icon(
                Icons.people_outline,
                color: _syncPartner ? AppTheme.primaryColor : AppTheme.textHint,
              ),
              activeColor: AppTheme.primaryColor,
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            const SizedBox(height: 8),

            // 표시할 캘린더 선택
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '표시할 캘린더',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.25,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _calendars.length,
                itemBuilder: (context, index) {
                  final cal = _calendars[index];
                  final isSelected = _selectedIds.contains(cal.id);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (checked) async {
                      await widget.notifier.toggleCalendarSelection(
                        cal.id!,
                        checked ?? false,
                      );
                      setState(() {
                        if (checked == true) {
                          _selectedIds.add(cal.id!);
                        } else {
                          _selectedIds.remove(cal.id);
                        }
                      });
                      widget.onChanged();
                    },
                    title: Text(
                      cal.name ?? '(이름 없음)',
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: cal.accountName != null
                        ? Text(
                            cal.accountName!,
                            style: const TextStyle(fontSize: 11),
                          )
                        : null,
                    secondary: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: cal.color != null
                            ? Color(cal.color!)
                            : const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    activeColor: AppTheme.primaryColor,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.trailing,
                  );
                },
              ),
            ),
          ],
          if (_isEnabled && !_isLoading && _calendars.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '사용 가능한 캘린더가 없습니다',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

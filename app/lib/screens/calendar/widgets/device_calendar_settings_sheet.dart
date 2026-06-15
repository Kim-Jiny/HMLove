import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/device_calendar_service.dart';
import '../../../core/theme.dart';
import '../../../providers/calendar_provider.dart';
import 'holiday_diagnosis_sheet.dart';

// 기기 캘린더 설정 바텀시트
class DeviceCalendarSettingsSheet extends StatefulWidget {
  final CalendarNotifier notifier;
  final bool isEnabled;
  final VoidCallback onChanged;

  const DeviceCalendarSettingsSheet({
    super.key,
    required this.notifier,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  State<DeviceCalendarSettingsSheet> createState() =>
      _DeviceCalendarSettingsSheetState();
}

class _DeviceCalendarSettingsSheetState
    extends State<DeviceCalendarSettingsSheet> {
  late bool _isEnabled;
  late bool _holidayEnabled;
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
    _holidayEnabled = DeviceCalendarService.isHolidayOverlayEnabled();
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

  /// 공휴일이 안 보일 때 사용자가 직접 진단할 수 있는 시트.
  /// 권한 → 기기 캘린더 목록 → 휴일 후보 매칭 결과 → 가이드 순으로 보여준다.
  Future<void> _showHolidayDiagnosis(BuildContext context) async {
    final hasPerm = await DeviceCalendarService.hasPermission();
    final calendars = hasPerm
        ? await DeviceCalendarService.getCalendars()
        : <dc.Calendar>[];
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) =>
          HolidayDiagnosisSheet(hasPermission: hasPerm, calendars: calendars),
    );
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
      child: SingleChildScrollView(
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

            // 공휴일 표시 토글 (기기 캘린더 동기화와 독립)
            SwitchListTile(
              value: _holidayEnabled,
              onChanged: (enabled) async {
                if (enabled) {
                  final hasPermission = await _ensurePermission();
                  if (!hasPermission) return;
                }
                await widget.notifier.toggleHolidayOverlay(enabled);
                setState(() => _holidayEnabled = enabled);
                widget.onChanged();
              },
              title: const Text(
                '공휴일 표시',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                '기기 설정의 공휴일 캘린더를 자동 감지해 표시',
                style: TextStyle(fontSize: 12),
              ),
              secondary: Icon(
                Icons.flag_outlined,
                color: _holidayEnabled
                    ? const Color(0xFFD32F2F)
                    : AppTheme.textHint,
              ),
              activeThumbColor: const Color(0xFFD32F2F),
              contentPadding: EdgeInsets.zero,
            ),
            // 공휴일이 안 보일 때 원인을 사용자가 직접 확인할 수 있는 진단.
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showHolidayDiagnosis(context),
                icon: const Icon(Icons.help_outline, size: 16),
                label: const Text(
                  '공휴일이 안 보이나요?',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: AppTheme.textSecondary,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const Divider(height: 8),

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
              activeThumbColor: AppTheme.primaryColor,
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
                      value:
                          _writableCalendars.any(
                            (c) => c.id == _defaultWriteCalendarId,
                          )
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
                  color: _syncPartner
                      ? AppTheme.primaryColor
                      : AppTheme.textHint,
                ),
                activeThumbColor: AppTheme.primaryColor,
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
      ),
    );
  }
}

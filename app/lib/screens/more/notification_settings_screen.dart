import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../core/notification_sound_service.dart';
import '../../core/theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late final Box _box;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _box = Hive.box(AppConstants.settingsBox);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  bool _get(String key, {bool defaultValue = true}) {
    return _box.get(key, defaultValue: defaultValue) as bool;
  }

  void _set(String key, bool value) {
    _box.put(key, value);
    setState(() {});
    _scheduleSyncToServer();
  }

  /// 설정 변경 후 500ms 디바운스로 서버에 동기화
  void _scheduleSyncToServer() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 500), _syncToServer);
  }

  Future<void> _syncToServer() async {
    try {
      // noti_sound, noti_vibrate는 더 이상 사용하지 않으므로
      // 개별 카테고리 키만 서버에 동기화
      const keys = [
        'noti_all',
        'noti_chat', 'noti_chat_sound', 'noti_chat_vibrate',
        'noti_feed', 'noti_feed_sound', 'noti_feed_vibrate',
        'noti_calendar', 'noti_calendar_sound', 'noti_calendar_vibrate',
        'noti_anniversary', 'noti_anniversary_sound', 'noti_anniversary_vibrate',
        'noti_letter', 'noti_letter_sound', 'noti_letter_vibrate',
        'noti_mood', 'noti_mood_sound', 'noti_mood_vibrate',
        'noti_fight', 'noti_fight_sound', 'noti_fight_vibrate',
      ];
      final prefs = <String, dynamic>{};
      for (final key in keys) {
        final val = _box.get(key);
        if (val != null) prefs[key] = val;
      }

      final dio = ApiClient.createDio();
      await dio.patch('/auth/notification-prefs', data: {'prefs': prefs});
      debugPrint('[NotiSettings] Synced to server: $prefs');
    } catch (e) {
      debugPrint('[NotiSettings] Sync failed: $e');
    }
  }

  bool get _allOn => _get('noti_all');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: ListView(
        children: [
          // ── 전체 ──
          const _SectionHeader(title: '전체'),
          SwitchListTile(
            title: const Text('알림 받기'),
            subtitle: const Text('모든 알림을 켜거나 끕니다'),
            value: _allOn,
            activeTrackColor: AppTheme.primaryColor,
            onChanged: (v) => _set('noti_all', v),
          ),
          const Divider(height: 1),

          // ── 카테고리별 ──
          const _SectionHeader(title: '카테고리별 알림'),
          _NotificationCategory(
            icon: Icons.chat_bubble_outline,
            iconColor: const Color(0xFF2196F3),
            title: '새 메시지',
            subtitle: '상대방이 메시지를 보내면 알림',
            enabledKey: 'noti_chat',
            soundKey: 'noti_chat_sound',
            vibrateKey: 'noti_chat_vibrate',
            allOn: _allOn,
            box: _box,
            onChanged: () { setState(() {}); _scheduleSyncToServer(); },
          ),
          _NotificationCategory(
            icon: Icons.photo_outlined,
            iconColor: const Color(0xFF4CAF50),
            title: '새 피드',
            subtitle: '상대방이 피드를 올리면 알림',
            enabledKey: 'noti_feed',
            soundKey: 'noti_feed_sound',
            vibrateKey: 'noti_feed_vibrate',
            allOn: _allOn,
            box: _box,
            onChanged: () { setState(() {}); _scheduleSyncToServer(); },
          ),
          _NotificationCategory(
            icon: Icons.calendar_today_outlined,
            iconColor: const Color(0xFFFF9800),
            title: '새 일정',
            subtitle: '상대방이 일정을 추가하면 알림',
            enabledKey: 'noti_calendar',
            soundKey: 'noti_calendar_sound',
            vibrateKey: 'noti_calendar_vibrate',
            allOn: _allOn,
            box: _box,
            onChanged: () { setState(() {}); _scheduleSyncToServer(); },
          ),
          _NotificationCategory(
            icon: Icons.cake_outlined,
            iconColor: const Color(0xFFE91E63),
            title: '기념일 리마인드',
            subtitle: '기념일 하루 전 알림',
            enabledKey: 'noti_anniversary',
            soundKey: 'noti_anniversary_sound',
            vibrateKey: 'noti_anniversary_vibrate',
            allOn: _allOn,
            box: _box,
            onChanged: () { setState(() {}); _scheduleSyncToServer(); },
          ),
          _NotificationCategory(
            icon: Icons.mail_outline,
            iconColor: const Color(0xFF9C27B0),
            title: '편지 도착',
            subtitle: '상대방이 편지를 보내면 알림',
            enabledKey: 'noti_letter',
            soundKey: 'noti_letter_sound',
            vibrateKey: 'noti_letter_vibrate',
            allOn: _allOn,
            box: _box,
            onChanged: () { setState(() {}); _scheduleSyncToServer(); },
          ),
          _NotificationCategory(
            icon: Icons.emoji_emotions_outlined,
            iconColor: const Color(0xFFFF5722),
            title: '기분 기록',
            subtitle: '상대방이 기분을 기록하면 알림',
            enabledKey: 'noti_mood',
            soundKey: 'noti_mood_sound',
            vibrateKey: 'noti_mood_vibrate',
            allOn: _allOn,
            box: _box,
            onChanged: () { setState(() {}); _scheduleSyncToServer(); },
          ),
          _NotificationCategory(
            icon: Icons.thunderstorm_outlined,
            iconColor: const Color(0xFF607D8B),
            title: '다툼 기록/해결',
            subtitle: '다툼이 기록되거나 해결되면 알림',
            enabledKey: 'noti_fight',
            soundKey: 'noti_fight_sound',
            vibrateKey: 'noti_fight_vibrate',
            allOn: _allOn,
            box: _box,
            onChanged: () { setState(() {}); _scheduleSyncToServer(); },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── 섹션 헤더 ──
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}

// ── 카테고리별 알림 항목 ──
class _NotificationCategory extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String enabledKey;
  final String soundKey;
  final String vibrateKey;
  final bool allOn;
  final Box box;
  final VoidCallback onChanged;

  const _NotificationCategory({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.enabledKey,
    required this.soundKey,
    required this.vibrateKey,
    required this.allOn,
    required this.box,
    required this.onChanged,
  });

  bool _get(String key) {
    return box.get(key, defaultValue: true) as bool;
  }

  void _set(String key, bool value) {
    box.put(key, value);
    onChanged();
  }

  bool get _enabled => allOn && _get(enabledKey);

  String get _currentSoundId {
    return NotificationSoundService.getSoundId(enabledKey);
  }

  NotificationSound? get _currentSound {
    final id = _currentSoundId;
    final all = NotificationSoundService.getAllSounds();
    return all.where((s) => s.id == id).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 메인 토글
        SwitchListTile(
          secondary: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          value: _get(enabledKey),
          activeTrackColor: AppTheme.primaryColor,
          onChanged: allOn ? (v) => _set(enabledKey, v) : null,
        ),
        // 소리 선택 + 진동 서브 옵션
        if (_enabled)
          Padding(
            padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
            child: Row(
              children: [
                // 알림음 선택
                GestureDetector(
                  onTap: () async {
                    final result = await showModalBottomSheet<String>(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (_) => _SoundPickerSheet(
                        categoryKey: enabledKey,
                        categoryTitle: title,
                      ),
                    );
                    if (result != null) {
                      NotificationSoundService.setSoundId(enabledKey, result);
                      onChanged();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentSound?.emoji ?? '🔔',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _currentSound?.label ?? '기본',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.expand_more, size: 14, color: AppTheme.primaryColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _SubToggle(
                  icon: Icons.volume_up_rounded,
                  label: '소리',
                  value: _get(soundKey),
                  onChanged: (v) => _set(soundKey, v),
                ),
                const SizedBox(width: 8),
                _SubToggle(
                  icon: Icons.vibration,
                  label: '진동',
                  value: _get(vibrateKey),
                  onChanged: (v) => _set(vibrateKey, v),
                ),
              ],
            ),
          ),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}

// ── 소리/진동 미니 토글 ──
class _SubToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SubToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: value
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? AppTheme.primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: value ? AppTheme.primaryColor : AppTheme.textHint,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: value ? AppTheme.primaryColor : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 사운드 선택 바텀시트 ──
class _SoundPickerSheet extends StatefulWidget {
  final String categoryKey;
  final String categoryTitle;

  const _SoundPickerSheet({
    required this.categoryKey,
    required this.categoryTitle,
  });

  @override
  State<_SoundPickerSheet> createState() => _SoundPickerSheetState();
}

class _SoundPickerSheetState extends State<_SoundPickerSheet> {
  late String _selected;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = NotificationSoundService.getSoundId(widget.categoryKey);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _nameController.dispose();
    if (_isRecording) {
      NotificationSoundService.cancelRecording();
    }
    super.dispose();
  }

  List<NotificationSound> get _allSounds => NotificationSoundService.getAllSounds();

  Future<void> _startRecording() async {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final ok = await NotificationSoundService.startRecording(id);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('마이크 권한이 필요합니다')),
        );
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _recordSeconds++);
      if (_recordSeconds >= 5) {
        _stopRecording(id);
      }
    });
  }

  Future<void> _stopRecording(String id) async {
    _recordTimer?.cancel();
    _recordTimer = null;

    if (!mounted) return;

    // 이름 입력 다이얼로그
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('녹음 이름'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 우리 소리'),
          maxLength: 10,
        ),
        actions: [
          TextButton(
            onPressed: () {
              NotificationSoundService.cancelRecording();
              Navigator.pop(ctx);
            },
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final text = _nameController.text.trim();
              Navigator.pop(ctx, text.isNotEmpty ? text : '녹음 ${_allSounds.where((s) => s.isCustom).length + 1}');
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (name != null) {
      await NotificationSoundService.stopRecording(id, name);
      setState(() {
        _selected = id;
        _isRecording = false;
        _recordSeconds = 0;
      });
      _nameController.clear();
    } else {
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sounds = _allSounds;
    final customSounds = sounds.where((s) => s.isCustom).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.categoryTitle} 알림음',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: const Text('완료'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                // 내장 사운드
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    '내장 알림음',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textHint,
                    ),
                  ),
                ),
                ...NotificationSoundService.builtInSounds.map(
                  (s) => _SoundTile(
                    sound: s,
                    isSelected: _selected == s.id,
                    onTap: () {
                      setState(() => _selected = s.id);
                      if (s.id != 'none') {
                        NotificationSoundService.preview(s.id);
                      }
                    },
                  ),
                ),

                // 녹음 섹션
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    '직접 녹음',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textHint,
                    ),
                  ),
                ),
                // 사용자 녹음 목록
                ...customSounds.map(
                  (s) => _SoundTile(
                    sound: s,
                    isSelected: _selected == s.id,
                    onTap: () {
                      setState(() => _selected = s.id);
                      NotificationSoundService.preview(s.id);
                    },
                    onDelete: () async {
                      await NotificationSoundService.deleteCustomSound(s.id);
                      if (_selected == s.id) _selected = 'default';
                      setState(() {});
                    },
                  ),
                ),
                // 녹음 버튼
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _isRecording
                      ? _RecordingIndicator(
                          seconds: _recordSeconds,
                          onStop: () {
                            final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
                            _stopRecording(id);
                          },
                        )
                      : OutlinedButton.icon(
                          onPressed: _startRecording,
                          icon: const Icon(Icons.mic, size: 18),
                          label: const Text('새로 녹음하기 (최대 5초)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.primaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            minimumSize: const Size(double.infinity, 0),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 사운드 리스트 타일 ──
class _SoundTile extends StatelessWidget {
  final NotificationSound sound;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _SoundTile({
    required this.sound,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(sound.emoji, style: const TextStyle(fontSize: 22)),
      title: Text(
        sound.label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppTheme.primaryColor : null,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 미리듣기 버튼
          if (sound.id != 'none')
            IconButton(
              icon: Icon(
                Icons.play_circle_outline,
                size: 22,
                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade500,
              ),
              onPressed: () => NotificationSoundService.preview(sound.id),
              tooltip: '미리듣기',
            ),
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey.shade400),
              onPressed: onDelete,
            ),
          if (isSelected)
            const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 22)
          else
            Icon(Icons.radio_button_unchecked, color: Colors.grey.shade300, size: 22),
        ],
      ),
      onTap: onTap,
    );
  }
}

// ── 녹음 중 인디케이터 ──
class _RecordingIndicator extends StatelessWidget {
  final int seconds;
  final VoidCallback onStop;

  const _RecordingIndicator({
    required this.seconds,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '녹음 중...',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
                ),
                const SizedBox(height: 2),
                // 진행 바
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: seconds / 5,
                    backgroundColor: Colors.red.shade100,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${seconds}s / 5s',
            style: TextStyle(fontSize: 12, color: Colors.red.shade700),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onStop,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stop, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

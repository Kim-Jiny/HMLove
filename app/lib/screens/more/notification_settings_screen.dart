import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants.dart';
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

  @override
  void initState() {
    super.initState();
    _box = Hive.box(AppConstants.settingsBox);
  }

  bool _get(String key, {bool defaultValue = true}) {
    return _box.get(key, defaultValue: defaultValue) as bool;
  }

  void _set(String key, bool value) {
    _box.put(key, value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: ListView(
        children: [
          _SectionHeader(title: '전체'),
          SwitchListTile(
            title: const Text('알림 받기'),
            subtitle: const Text('모든 알림을 켜거나 끕니다'),
            value: _get('noti_all'),
            activeColor: AppTheme.primaryColor,
            onChanged: (v) => _set('noti_all', v),
          ),
          const Divider(height: 1),

          _SectionHeader(title: '채팅'),
          SwitchListTile(
            title: const Text('새 메시지'),
            subtitle: const Text('상대방이 메시지를 보내면 알림'),
            value: _get('noti_chat'),
            activeColor: AppTheme.primaryColor,
            onChanged: _get('noti_all') ? (v) => _set('noti_chat', v) : null,
          ),
          const Divider(height: 1),

          _SectionHeader(title: '피드'),
          SwitchListTile(
            title: const Text('새 피드'),
            subtitle: const Text('상대방이 피드를 올리면 알림'),
            value: _get('noti_feed'),
            activeColor: AppTheme.primaryColor,
            onChanged: _get('noti_all') ? (v) => _set('noti_feed', v) : null,
          ),
          const Divider(height: 1),

          _SectionHeader(title: '캘린더'),
          SwitchListTile(
            title: const Text('새 일정'),
            subtitle: const Text('상대방이 일정을 추가하면 알림'),
            value: _get('noti_calendar'),
            activeColor: AppTheme.primaryColor,
            onChanged: _get('noti_all') ? (v) => _set('noti_calendar', v) : null,
          ),
          SwitchListTile(
            title: const Text('기념일 리마인드'),
            subtitle: const Text('기념일 하루 전 알림'),
            value: _get('noti_anniversary'),
            activeColor: AppTheme.primaryColor,
            onChanged: _get('noti_all') ? (v) => _set('noti_anniversary', v) : null,
          ),
          const Divider(height: 1),

          _SectionHeader(title: '편지'),
          SwitchListTile(
            title: const Text('편지 도착'),
            subtitle: const Text('상대방이 편지를 보내면 알림'),
            value: _get('noti_letter'),
            activeColor: AppTheme.primaryColor,
            onChanged: _get('noti_all') ? (v) => _set('noti_letter', v) : null,
          ),
          const Divider(height: 1),

          _SectionHeader(title: '기분'),
          SwitchListTile(
            title: const Text('기분 기록'),
            subtitle: const Text('상대방이 기분을 기록하면 알림'),
            value: _get('noti_mood'),
            activeColor: AppTheme.primaryColor,
            onChanged: _get('noti_all') ? (v) => _set('noti_mood', v) : null,
          ),
          const Divider(height: 1),

          _SectionHeader(title: '다툼'),
          SwitchListTile(
            title: const Text('다툼 기록/해결'),
            subtitle: const Text('다툼이 기록되거나 해결되면 알림'),
            value: _get('noti_fight'),
            activeColor: AppTheme.primaryColor,
            onChanged: _get('noti_all') ? (v) => _set('noti_fight', v) : null,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

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

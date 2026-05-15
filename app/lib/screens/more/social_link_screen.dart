import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/social_auth_service.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class SocialLinkScreen extends ConsumerStatefulWidget {
  const SocialLinkScreen({super.key});

  @override
  ConsumerState<SocialLinkScreen> createState() => _SocialLinkScreenState();
}

class _SocialLinkScreenState extends ConsumerState<SocialLinkScreen> {
  bool _loading = true;
  bool _busy = false;
  bool _hasPassword = true;
  List<_LinkedRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final data = await ref.read(authProvider.notifier).fetchLinkedProviders();
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _loading = false;
        _rows = const [];
      });
      return;
    }
    final providers = (data['providers'] as List).cast<Map>();
    final rows = providers.map((p) {
      final provider = SocialProviderX.fromServerName(p['provider'] as String?);
      return _LinkedRow(
        provider: provider!,
        linked: p['linked'] == true,
        email: p['email'] as String?,
      );
    }).toList();
    setState(() {
      _hasPassword = data['hasPassword'] == true;
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _toggleLink(_LinkedRow row) async {
    if (_busy) return;
    setState(() => _busy = true);
    String? error;
    try {
      if (row.linked) {
        // 마지막 로그인 수단 차단
        final linkedCount = _rows.where((r) => r.linked).length;
        if (!_hasPassword && linkedCount <= 1) {
          error = '비밀번호가 없는 계정은 마지막 소셜 연동을 해제할 수 없습니다.';
        } else {
          final ok = await _confirmUnlink(row.provider);
          if (!ok) {
            setState(() => _busy = false);
            return;
          }
          error = await ref.read(authProvider.notifier).unlinkSocial(row.provider);
        }
      } else {
        error = await ref.read(authProvider.notifier).linkSocial(row.provider);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            row.linked
                ? '${row.provider.displayName} 연동을 해제했어요.'
                : '${row.provider.displayName} 계정을 연동했어요.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    await _refresh();
  }

  Future<bool> _confirmUnlink(SocialProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${provider.displayName} 연동 해제'),
        content: Text('${provider.displayName} 계정 연동을 해제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('해제'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        title: const Text('계정 연동'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '연동된 소셜 계정으로도 로그인할 수 있어요. '
                      '같은 종류는 한 번에 하나만 연결할 수 있어요.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < _rows.length; i++) ...[
                          if (i > 0) const Divider(height: 1, indent: 16),
                          _LinkRow(
                            row: _rows[i],
                            disabled: _busy,
                            onToggle: () => _toggleLink(_rows[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _LinkedRow {
  final SocialProvider provider;
  final bool linked;
  final String? email;
  const _LinkedRow({
    required this.provider,
    required this.linked,
    this.email,
  });
}

class _LinkRow extends StatelessWidget {
  final _LinkedRow row;
  final bool disabled;
  final VoidCallback onToggle;

  const _LinkRow({
    required this.row,
    required this.disabled,
    required this.onToggle,
  });

  IconData get _icon {
    switch (row.provider) {
      case SocialProvider.google:
        return Icons.g_mobiledata;
      case SocialProvider.apple:
        return Icons.apple;
      case SocialProvider.kakao:
        return Icons.chat_bubble;
    }
  }

  Color get _iconColor {
    switch (row.provider) {
      case SocialProvider.google:
        return const Color(0xFF4285F4);
      case SocialProvider.apple:
        return Colors.black;
      case SocialProvider.kakao:
        return const Color(0xFFFEE500);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _iconColor.withValues(alpha: 0.15),
        child: Icon(_icon, color: _iconColor),
      ),
      title: Text(row.provider.displayName),
      subtitle: Text(
        row.linked ? (row.email ?? '연동됨') : '연동 안됨',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: TextButton(
        onPressed: disabled ? null : onToggle,
        style: TextButton.styleFrom(
          foregroundColor: row.linked ? AppTheme.errorColor : AppTheme.primaryColor,
        ),
        child: Text(row.linked ? '해제' : '연동'),
      ),
    );
  }
}

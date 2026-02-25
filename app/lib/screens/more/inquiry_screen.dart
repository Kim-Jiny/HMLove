import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/top_snackbar.dart';

class InquiryScreen extends ConsumerStatefulWidget {
  const InquiryScreen({super.key});

  @override
  ConsumerState<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends ConsumerState<InquiryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('문의하기'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: '새 문의'),
            Tab(text: '내 문의 내역'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _InquiryForm(onSubmitted: () {
            _tabController.animateTo(1);
          }),
          const _InquiryList(),
        ],
      ),
    );
  }
}

// ===== 문의 작성 폼 =====
class _InquiryForm extends ConsumerStatefulWidget {
  final VoidCallback onSubmitted;
  const _InquiryForm({required this.onSubmitted});

  @override
  ConsumerState<_InquiryForm> createState() => _InquiryFormState();
}

class _InquiryFormState extends ConsumerState<_InquiryForm> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _category = 'bug';
  bool _isSubmitting = false;
  String _deviceInfo = '';
  String _appVersion = '';

  final _categories = [
    {'value': 'bug', 'label': '버그 신고', 'icon': Icons.bug_report},
    {'value': 'feature', 'label': '기능 건의', 'icon': Icons.lightbulb_outline},
    {'value': 'account', 'label': '계정 문의', 'icon': Icons.person_outline},
    {'value': 'other', 'label': '기타', 'icon': Icons.help_outline},
  ];

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = DeviceInfoPlugin();

      String model = '';
      String os = '';

      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        model = '${info.brand} ${info.model}';
        os = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        model = '${info.name} (${info.utsname.machine})';
        os = '${info.systemName} ${info.systemVersion}';
      }

      if (mounted) {
        setState(() {
          _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
          _deviceInfo = '$model | $os';
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      showTopSnackBar(context, '제목을 입력해주세요', isError: true);
      return;
    }
    if (content.isEmpty) {
      showTopSnackBar(context, '내용을 입력해주세요', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final devicePlugin = DeviceInfoPlugin();
      String? deviceModel;
      String? osVersion;

      if (Platform.isAndroid) {
        final info = await devicePlugin.androidInfo;
        deviceModel = '${info.brand} ${info.model}';
        osVersion = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
      } else if (Platform.isIOS) {
        final info = await devicePlugin.iosInfo;
        deviceModel = '${info.name} (${info.utsname.machine})';
        osVersion = '${info.systemName} ${info.systemVersion}';
      }

      final packageInfo = await PackageInfo.fromPlatform();

      final dio = ref.read(dioProvider);
      await dio.post('/inquiry', data: {
        'category': _category,
        'title': title,
        'content': content,
        'appVersion': '${packageInfo.version}+${packageInfo.buildNumber}',
        'deviceModel': deviceModel,
        'osVersion': osVersion,
      });

      if (mounted) {
        _titleController.clear();
        _contentController.clear();
        showTopSnackBar(context, '문의가 접수되었습니다');
        widget.onSubmitted();
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, '문의 접수에 실패했습니다', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카테고리 선택
          const Text(
            '문의 유형',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((cat) {
              final selected = _category == cat['value'];
              return ChoiceChip(
                avatar: Icon(
                  cat['icon'] as IconData,
                  size: 18,
                  color: selected ? Colors.white : AppTheme.textSecondary,
                ),
                label: Text(cat['label'] as String),
                selected: selected,
                selectedColor: AppTheme.primaryColor,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppTheme.textPrimary,
                  fontSize: 13,
                ),
                onSelected: (_) => setState(() => _category = cat['value'] as String),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // 제목
          const Text(
            '제목',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: '문의 제목을 입력하세요',
            ),
            maxLength: 100,
          ),
          const SizedBox(height: 16),

          // 내용
          const Text(
            '내용',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _contentController,
            decoration: const InputDecoration(
              hintText: '문의 내용을 자세히 입력해주세요',
              alignLabelWithHint: true,
            ),
            maxLines: 6,
            maxLength: 2000,
          ),
          const SizedBox(height: 12),

          // 디바이스 정보 표시
          if (_deviceInfo.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '자동 수집 정보',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '앱 버전: $_appVersion',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '기기: $_deviceInfo',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // 제출 버튼
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('문의 접수'),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== 문의 내역 리스트 =====
class _InquiryList extends ConsumerStatefulWidget {
  const _InquiryList();

  @override
  ConsumerState<_InquiryList> createState() => _InquiryListState();
}

class _InquiryListState extends ConsumerState<_InquiryList> {
  List<dynamic> _inquiries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/inquiry');
      if (mounted) {
        setState(() {
          _inquiries = res.data['inquiries'] as List;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'RESOLVED':
        return Colors.green;
      case 'CLOSED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return '접수됨';
      case 'IN_PROGRESS':
        return '처리 중';
      case 'RESOLVED':
        return '답변 완료';
      case 'CLOSED':
        return '종료';
      default:
        return status;
    }
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'bug':
        return '버그';
      case 'feature':
        return '건의';
      case 'account':
        return '계정';
      default:
        return '기타';
    }
  }

  void _showDetail(Map<String, dynamic> inq) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 상태 뱃지 + 카테고리
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(inq['status']).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(inq['status']),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(inq['status']),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _categoryLabel(inq['category'] ?? ''),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 제목
              Text(
                inq['title'] ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(inq['createdAt']),
                style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              // 내용
              Text(
                inq['content'] ?? '',
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
              // 관리자 답변
              if (inq['adminReply'] != null) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.support_agent, size: 18, color: AppTheme.primaryColor),
                          SizedBox(width: 6),
                          Text(
                            '관리자 답변',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        inq['adminReply'],
                        style: const TextStyle(fontSize: 14, height: 1.6),
                      ),
                      if (inq['repliedAt'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _formatDate(inq['repliedAt']),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final d = DateTime.tryParse(dateStr);
    if (d == null) return '';
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_inquiries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              '문의 내역이 없습니다',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _inquiries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final inq = _inquiries[index] as Map<String, dynamic>;
          return Card(
            child: InkWell(
              onTap: () => _showDetail(inq),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _statusColor(inq['status']).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _statusLabel(inq['status']),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _statusColor(inq['status']),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _categoryLabel(inq['category'] ?? ''),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textHint,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            inq['title'] ?? '',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(inq['createdAt']),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (inq['adminReply'] != null)
                      const Icon(
                        Icons.chat_bubble,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      color: AppTheme.textHint,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

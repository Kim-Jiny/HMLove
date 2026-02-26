import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyScreen extends ConsumerStatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  ConsumerState<PrivacyPolicyScreen> createState() =>
      _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends ConsumerState<PrivacyPolicyScreen> {
  String? _content;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dio = Dio(BaseOptions(baseUrl: AppConstants.apiBaseUrl));
      final res = await dio.get('/settings/privacy_policy');
      setState(() {
        _content = res.data['value'] as String?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '개인정보처리방침을 불러올 수 없습니다.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('개인정보처리방침'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _load();
                        },
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              : Markdown(
                  data: _content ?? '',
                  padding: const EdgeInsets.all(20),
                  onTapLink: (text, href, title) {
                    if (href != null) launchUrl(Uri.parse(href));
                  },
                  styleSheet: MarkdownStyleSheet(
                    h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1f2937), height: 2),
                    h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1f2937), height: 2.5),
                    h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF374151), height: 2.2),
                    p: const TextStyle(fontSize: 14, height: 1.8, color: Color(0xFF374151)),
                    listBullet: const TextStyle(fontSize: 14, height: 1.8, color: Color(0xFF374151)),
                    a: const TextStyle(fontSize: 14, color: AppTheme.primaryColor, decoration: TextDecoration.underline),
                    h2Padding: const EdgeInsets.only(top: 12),
                    blockquoteDecoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border(left: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.4), width: 3)),
                    ),
                    horizontalRuleDecoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                  ),
                ),
    );
  }
}

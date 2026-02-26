import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

final unreadInquiryCountProvider =
    NotifierProvider<UnreadInquiryNotifier, int>(
  UnreadInquiryNotifier.new,
);

class UnreadInquiryNotifier extends Notifier<int> {
  @override
  int build() => 0;

  Future<void> fetch() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/inquiry/unread-count');
      state = (res.data['count'] as int?) ?? 0;
    } catch (e) {
      debugPrint('[Inquiry] unread count fetch error: $e');
    }
  }

  void markAllRead() {
    state = 0;
  }
}

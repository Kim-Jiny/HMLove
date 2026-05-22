import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/widget_service.dart';
import 'badge_provider.dart';
import 'couple_provider.dart';
import 'doodle_provider.dart';
import 'fortune_provider.dart';
import 'mission_provider.dart';
import 'mood_provider.dart';
import 'notification_provider.dart';
import 'question_provider.dart';
import 'wishlist_provider.dart';

Future<void> fetchAndApplyHomeSummary(WidgetRef ref) async {
  final dio = ref.read(dioProvider);
  final localDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final month = localDate.substring(0, 7);
  final settings = Hive.box(AppConstants.settingsBox);
  final lastSeenFeedAt = settings.get('lastSeenFeedAt') as String?;

  final response = await dio.get(
    '/home/summary',
    queryParameters: {
      'date': localDate,
      'month': month,
      'lastSeenFeedAt': ?lastSeenFeedAt,
    },
  );
  final data = response.data as Map<String, dynamic>;

  await ref
      .read(coupleProvider.notifier)
      .applySummary(data['couple'] as Map<String, dynamic>?);
  ref.read(moodProvider.notifier).applyTodayMoods(data['moods'] as List?);
  ref
      .read(fortuneProvider.notifier)
      .applyTodaySummary(data['fortune'] as Map<String, dynamic>?);
  ref
      .read(missionProvider.notifier)
      .applyTodaySummary(data['missions'] as Map<String, dynamic>?);
  ref
      .read(questionProvider.notifier)
      .applyTodaySummary(data['question'] as Map<String, dynamic>?);
  ref
      .read(wishlistProvider.notifier)
      .applyItems(
        (data['wishlist'] as Map<String, dynamic>?)?['items'] as List?,
      );
  ref
      .read(doodleProvider.notifier)
      .applyLatestReceived(data['doodle'] as Map<String, dynamic>?);

  final badges = data['badges'] as Map<String, dynamic>?;
  ref
      .read(badgeProvider.notifier)
      .applyCounts(
        unreadChatCount: badges?['unreadChatCount'] as int?,
        unseenFeedCount: badges?['unseenFeedCount'] as int?,
      );

  final notifications = data['notifications'] as Map<String, dynamic>?;
  ref
      .read(notificationProvider.notifier)
      .applyUnreadCount(notifications?['unreadCount'] as int? ?? 0);

  final widgets = data['widgets'] as Map<String, dynamic>?;
  await WidgetService.updateTodaySchedule(
    widgets?['todaySchedule'] as String? ?? '',
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'badge_provider.dart';
import 'calendar_provider.dart';
import 'couple_provider.dart';
import 'doodle_provider.dart';
import 'feed_provider.dart';
import 'fight_provider.dart';
import 'fortune_provider.dart';
import 'inquiry_provider.dart';
import 'letter_provider.dart';
import 'mission_provider.dart';
import 'mood_provider.dart';
import 'notification_provider.dart';
import 'photo_provider.dart';
import 'question_provider.dart';
import 'wishlist_provider.dart';

/// 한 계정의 데이터를 보유하는 모든 feature provider 를 초기화한다.
///
/// 로그아웃 / 강제 로그아웃 / 커플 해제 시 반드시 호출해야 같은 기기에서 다른
/// 계정으로 로그인했을 때 이전 계정의 사진·편지·피드 등이 남아 보이는 문제를
/// 막을 수 있다. auth/chat 은 호출부에서 별도로 처리한다.
///
/// 새 feature provider 를 추가하면 여기에도 등록할 것. (단일 소스)
void resetFeatureProviders(Ref ref) {
  ref.invalidate(badgeProvider);
  ref.invalidate(calendarProvider);
  ref.invalidate(coupleProvider);
  ref.invalidate(doodleProvider);
  ref.invalidate(feedProvider);
  ref.invalidate(fightProvider);
  ref.invalidate(fortuneProvider);
  ref.invalidate(letterProvider);
  ref.invalidate(missionProvider);
  ref.invalidate(moodProvider);
  ref.invalidate(notificationProvider);
  ref.invalidate(photoProvider);
  ref.invalidate(questionProvider);
  ref.invalidate(wishlistProvider);
  ref.invalidate(unreadInquiryCountProvider);
}

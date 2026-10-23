import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'store_mode.dart';

class AdService {
  AdService._();

  static Future<void> initialize() async {
    // 스토어 촬영 모드: 추적 권한 팝업/광고 초기화를 건너뛴다.
    if (storeModeEnabled) return;
    if (Platform.isIOS) {
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
    await MobileAds.instance.initialize();
  }
}

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kReleaseMode;

class AppConstants {
  AppConstants._();

  static const String appName = '우리연애';
  static const String appVersion = '1.0.0';

  // API
  static const String _localBaseUrl = 'https://love.jiny.shop';
  static const String _prodBaseUrl = 'https://love.jiny.shop';

  static String get _baseUrl => kReleaseMode ? _prodBaseUrl : _localBaseUrl;
  static String get apiBaseUrl => '$_baseUrl/api';
  static String get socketUrl => _baseUrl;

  // Hive Box Names
  static const String authBox = 'auth_box';
  static const String settingsBox = 'settings_box';
  static const String cacheBox = 'cache_box';

  // Hive Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String coupleIdKey = 'couple_id';

  // Push
  static const String fcmTokenKey = 'fcm_token';

  // Naver Map
  static const String naverMapClientId = 'lk38ez02sj';

  // Kakao SDK — 디벨로퍼스에서 발급받은 네이티브 앱 키.
  // 빌드 시 --dart-define=KAKAO_NATIVE_APP_KEY=xxx 로 주입.
  static const String kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
    defaultValue: '',
  );

  // Date Formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String displayDateFormat = 'yyyy년 M월 d일';
  static const String displayTimeFormat = 'a h:mm';

  // AdMob
  static String get adMobHomeBanner => Platform.isIOS
      ? 'ca-app-pub-2707874353926722/7735582107'
      : 'ca-app-pub-2707874353926722/2483255423';

  static String get adMobAnniversaryBanner => Platform.isIOS
      ? 'ca-app-pub-2707874353926722/6472136740'
      : 'ca-app-pub-2707874353926722/3638356743';

  static String get adMobMoreBanner => Platform.isIOS
      ? 'ca-app-pub-2707874353926722/4779781128'
      : 'ca-app-pub-2707874353926722/2730667438';

  static String get adMobFortuneBanner => Platform.isIOS
      ? 'ca-app-pub-2707874353926722/7002886688'
      : 'ca-app-pub-2707874353926722/9489449225';

  static String get adMobFortuneRewarded => Platform.isIOS
      ? 'ca-app-pub-2707874353926722/1502498596'
      : 'ca-app-pub-2707874353926722/4787137481';

  // Hive Keys - Ads
  static const String adsRemovedKey = 'adsRemoved';
}

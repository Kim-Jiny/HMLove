import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  static const String appName = '우리연애';
  static const String appVersion = '1.0.0';

  // API
  static const String _localBaseUrl = 'http://172.30.1.80:3000';
  static const String _prodBaseUrl = 'https://hmlove-server.onrender.com';

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

  // Date Formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String displayDateFormat = 'yyyy년 M월 d일';
  static const String displayTimeFormat = 'a h:mm';
}

class AppConstants {
  AppConstants._();

  static const String appName = 'HMLove';
  static const String appVersion = '1.0.0';

  // API
  static const String apiBaseUrl = 'http://172.30.1.80:3000/api';
  static const String socketUrl = 'http://172.30.1.80:3000';

  // Hive Box Names
  static const String authBox = 'auth_box';
  static const String settingsBox = 'settings_box';
  static const String cacheBox = 'cache_box';

  // Hive Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String coupleIdKey = 'couple_id';

  // Date Formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String displayDateFormat = 'yyyy년 M월 d일';
  static const String displayTimeFormat = 'a h:mm';
}

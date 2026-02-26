import 'package:home_widget/home_widget.dart';

/// App Group ID (iOS) - must match Widget Extension's App Group
const _appGroupId = 'group.com.jiny.hmlove';

/// Widget names
const _iosWidgetName = 'HMLoveWidget';
const _androidWidgetName = 'HMLoveWidgetProvider';
const _androidSmallWidgetName = 'HMLoveSmallWidgetProvider';

class WidgetService {
  WidgetService._();

  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Save auth info so widget extension can fetch data independently
  static Future<void> saveAuthInfo(String token, String apiBaseUrl) async {
    await Future.wait([
      HomeWidget.saveWidgetData('authToken', token),
      HomeWidget.saveWidgetData('apiBaseUrl', apiBaseUrl),
    ]);
  }

  /// Update D-day / couple data
  static Future<void> updateCoupleData({
    required String myName,
    required String partnerName,
    required int daysTogether,
    required String startDate,
    String? nextAnniversaryName,
    int? nextAnniversaryDaysLeft,
  }) async {
    await Future.wait([
      HomeWidget.saveWidgetData('isConnected', true),
      HomeWidget.saveWidgetData('myName', myName),
      HomeWidget.saveWidgetData('partnerName', partnerName),
      HomeWidget.saveWidgetData('daysTogether', daysTogether),
      HomeWidget.saveWidgetData('startDate', startDate),
      if (nextAnniversaryName != null)
        HomeWidget.saveWidgetData('nextAnniversaryName', nextAnniversaryName),
      if (nextAnniversaryDaysLeft != null)
        HomeWidget.saveWidgetData(
            'nextAnniversaryDaysLeft', nextAnniversaryDaysLeft),
    ]);
    await _refresh();
  }

  /// Clear widget data on logout
  static Future<void> clearData() async {
    await HomeWidget.saveWidgetData('isConnected', false);
    await _refresh();
  }

  /// Update mood data
  static Future<void> updateMoodData({
    String? myMoodKey,
    String? partnerMoodKey,
  }) async {
    final myEmoji = _moodEmoji(myMoodKey);
    final partnerEmoji = _moodEmoji(partnerMoodKey);

    await Future.wait([
      HomeWidget.saveWidgetData('myMoodEmoji', myEmoji),
      HomeWidget.saveWidgetData('partnerMoodEmoji', partnerEmoji),
    ]);
    await _refresh();
  }

  /// Update today's schedule text for medium widget
  static Future<void> updateTodaySchedule(String? schedule) async {
    await HomeWidget.saveWidgetData(
        'todaySchedule', schedule ?? '');
    await _refresh();
  }

  static Future<void> _refresh() async {
    await HomeWidget.updateWidget(
      iOSName: _iosWidgetName,
      androidName: _androidWidgetName,
    );
    await HomeWidget.updateWidget(
      iOSName: _iosWidgetName,
      androidName: _androidSmallWidgetName,
    );
  }

  static String _moodEmoji(String? key) {
    const map = {
      'happy': '😊',
      'love': '🥰',
      'excited': '🤩',
      'grateful': '🙏',
      'peaceful': '😌',
      'proud': '😎',
      'missing': '🥺',
      'bored': '😐',
      'sad': '😢',
      'angry': '😤',
      'tired': '😴',
      'stressed': '😩',
    };
    return map[key] ?? '😶';
  }

  static String _moodLabel(String? key) {
    const map = {
      'happy': '행복해',
      'love': '사랑해',
      'excited': '신나',
      'grateful': '감사해',
      'peaceful': '평온해',
      'proud': '뿌듯해',
      'missing': '보고싶어',
      'bored': '심심해',
      'sad': '슬퍼',
      'angry': '화나',
      'tired': '피곤해',
      'stressed': '스트레스',
    };
    return map[key] ?? '설정 안 됨';
  }
}

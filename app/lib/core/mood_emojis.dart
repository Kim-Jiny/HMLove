/// Single source of truth for mood key → emoji / label mappings.
///
/// These tables were previously duplicated across:
/// - core/widget_service.dart
/// - screens/home/home_screen.dart (mood picker + mood card)
/// - screens/calendar/calendar_screen.dart
///
/// Keep this in sync; all call sites should reference these maps.
library;

/// Canonical mood key → emoji.
const Map<String, String> moodEmojis = {
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

/// Canonical mood key → Korean label.
const Map<String, String> moodLabels = {
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

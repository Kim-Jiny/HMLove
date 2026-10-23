/// 기기 캘린더의 "휴일" 구독 캘린더에서 읽은 일정을 공휴일로 정리하는 순수 함수들.
///
/// 구글 "대한민국의 휴일" 같은 캘린더는 공휴일과 기념일(식목일·어버이날·스승의날·
/// 국군의날·크리스마스 이브 …)을 한 캘린더에 섞어 넣고 설명(description)으로만 구분한다.
///   - 공휴일: 설명이 "공휴일" (영어: "Public holiday")
///   - 기념일: 설명이 "기념일" + "기념일을 숨기려면 …" 안내 (영어: "Observance" …)
/// 삼성 "공휴일" 캘린더는 설명 없이 "대체공휴일" 처럼 따로 넣고, 같은 날을 구글은
/// "쉬는 날 개천절" 로 또 넣으며, 구글 계정이 둘이면 같은 일정이 두 번 읽힌다.
library;

/// 기념일(observance) 로 판정하는 설명 키워드. 소문자 비교.
/// 공휴일 설명에는 나오지 않는 말만 쓰고, 모르는 언어의 설명은 공휴일로 통과시킨다
/// (공휴일을 숨기는 것보다 기념일이 섞이는 쪽이 덜 해롭다).
const _observanceMarkers = <String>[
  '기념일',
  'observance',
  '記念日',
  '纪念日',
  '紀念日',
  'gedenktag',
];

/// 설명으로 보아 공휴일이 아닌 기념일인지.
bool isObservanceDescription(String? description) {
  final d = (description ?? '').trim().toLowerCase();
  if (d.isEmpty) return false;
  return _observanceMarkers.any(d.contains);
}

const _substitutePrefix = '쉬는 날 ';
const _genericSubstituteTitles = <String>{'대체공휴일', '대체 공휴일', '대체휴일'};

/// "쉬는 날 개천절" → "대체공휴일(개천절)". 그 외는 공백만 정리.
String normalizeHolidayTitle(String title) {
  final t = title.trim();
  if (t.startsWith(_substitutePrefix)) {
    return '대체공휴일(${t.substring(_substitutePrefix.length).trim()})';
  }
  return t;
}

/// 이름만으로는 어느 공휴일의 대체인지 알 수 없는 "대체공휴일" 류인지.
bool isGenericSubstituteTitle(String title) =>
    _genericSubstituteTitles.contains(title.trim());

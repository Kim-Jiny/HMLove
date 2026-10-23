import 'package:flutter_test/flutter_test.dart';
import 'package:hmlove/core/holiday_utils.dart';
import 'package:hmlove/providers/calendar_provider.dart';

CalendarEvent ev(String id, String title, int month, int day) => CalendarEvent(
      id: id,
      title: title,
      date: DateTime(2026, month, day),
      eventType: 'holiday',
      color: '#D32F2F',
    );

void main() {
  group('isObservanceDescription (구글 휴일 캘린더의 설명)', () {
    test('공휴일 설명은 기념일이 아니다', () {
      expect(isObservanceDescription('공휴일'), isFalse);
      expect(isObservanceDescription('Public holiday'), isFalse);
      expect(isObservanceDescription('祝日'), isFalse);
      expect(isObservanceDescription(''), isFalse); // 삼성 공휴일 캘린더
      expect(isObservanceDescription(null), isFalse);
    });

    test('기념일 설명(안내문 포함)은 기념일이다', () {
      expect(isObservanceDescription('기념일'), isTrue);
      expect(
        isObservanceDescription('기념일\n기념일을 숨기려면 Google Calendar 설정 > 대한민국의 휴일 캘린더로 이동하세요.'),
        isTrue,
      );
      expect(isObservanceDescription('Observance'), isTrue);
      expect(isObservanceDescription('記念日'), isTrue);
    });
  });

  group('normalizeHolidayTitle', () {
    test('"쉬는 날 X" 는 "대체공휴일(X)"', () {
      expect(normalizeHolidayTitle('쉬는 날 개천절'), '대체공휴일(개천절)');
      expect(normalizeHolidayTitle('쉬는 날 부처님오신날'), '대체공휴일(부처님오신날)');
      expect(normalizeHolidayTitle('  한글날 '), '한글날');
    });
  });

  group('dedupeHolidays — 실제 기기(삼성+구글 2계정) 2026년 10월/12월 데이터', () {
    test('10월 5일: 삼성 "대체공휴일" + 구글 "쉬는 날 개천절" → 구체적인 하나만', () {
      final out = dedupeHolidays([
        ev('g_oct3', '개천절', 10, 3),
        ev('s_oct5', '대체공휴일', 10, 5),
        ev('g_oct5', '쉬는 날 개천절', 10, 5),
        ev('g_oct9', '한글날', 10, 9),
      ]);
      expect(out.map((e) => '${e.date.day}:${e.title}').toList(),
          ['3:개천절', '5:대체공휴일(개천절)', '9:한글날']);
    });

    test('같은 날 같은 이름(구글 계정 2개)은 하나', () {
      final out = dedupeHolidays([
        ev('a', '크리스마스', 12, 25),
        ev('b', '크리스마스', 12, 25),
        ev('c', '새해첫날', 1, 1),
        ev('d', '새해첫날', 1, 1),
      ]);
      expect(out.length, 2);
    });

    test('삼성 "대체공휴일" 만 있으면 그대로 유지', () {
      final out = dedupeHolidays([ev('s', '대체공휴일', 3, 2)]);
      expect(out.single.title, '대체공휴일');
    });

    test('날짜는 보존된다', () {
      final out = dedupeHolidays([ev('x', '한글날', 10, 9)]);
      expect(out.single.date, DateTime(2026, 10, 9));
    });
  });
}

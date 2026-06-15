/// 날짜(연·월·일)만 서버로 보낼 때 쓰는 포맷.
///
/// `DateTime.toIso8601String()` 은 로컬 시각을 UTC 로 변환하므로, KST(+9) 사용자가
/// showDatePicker 로 고른 자정(로컬) 날짜가 하루 전날(UTC 15:00)로 밀린다. 생일·기념일
/// 처럼 "시각이 없는 날짜"는 고른 연·월·일 그대로 UTC 자정에 고정해 보내야 한다.
String toServerDateOnly(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-${day}T00:00:00.000Z';
}

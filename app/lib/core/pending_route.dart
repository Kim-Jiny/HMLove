/// 위젯 탭/딥링크 등 외부 진입에서 들어온 목표 경로.
///
/// 인증이 아직 안 풀린 cold-launch 에서 기록되고, 인증이 풀린 뒤 router redirect 의
/// splash→home(또는 login→home) 분기에서 소비된다. 로그아웃/강제 로그아웃 시
/// 반드시 [clearPendingWidgetRoute] 로 비워야 다음 세션/다른 계정으로 누수되지 않는다.
///
/// router.dart 와 auth_provider 사이의 순환 의존을 피하려고 의존성 없는 단일 파일로 둔다.
String? _pendingWidgetRoute;

void setPendingWidgetRoute(String? route) {
  _pendingWidgetRoute = route;
}

/// 읽으면서 비운다 (단발성 소비).
String? consumePendingWidgetRoute() {
  final r = _pendingWidgetRoute;
  _pendingWidgetRoute = null;
  return r;
}

/// 비우지 않고 현재 값만 확인.
String? peekPendingWidgetRoute() => _pendingWidgetRoute;

void clearPendingWidgetRoute() {
  _pendingWidgetRoute = null;
}

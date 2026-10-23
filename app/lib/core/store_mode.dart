import 'dart:async';
import 'dart:io';

import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

/// 스토어 스크린샷 촬영용 자동 로그인.
///
/// `--dart-define=STORE_EMAIL=... --dart-define=STORE_PASSWORD=...` 로 빌드했을 때만 동작하고,
/// 정의하지 않은 일반 빌드에서는 컴파일 타임 상수라 아무 일도 하지 않는다.
/// (시뮬레이터/기기에서 로그인 화면을 손으로 입력하지 않고 데모 계정으로 바로 들어가기 위함)
const _storeEmail = String.fromEnvironment('STORE_EMAIL');
const _storePassword = String.fromEnvironment('STORE_PASSWORD');

bool get storeModeEnabled =>
    _storeEmail.isNotEmpty && _storePassword.isNotEmpty;

({String email, String password}) get storeCredentials =>
    (email: _storeEmail, password: _storePassword);

Timer? _routeWatcher;

/// 촬영 모드에서 앱 문서 폴더의 `store_route.txt` 를 지켜보다가, 파일이 생기면 그 안의
/// 경로(예: /feed)로 이동하고 파일을 지운다. iOS 시뮬레이터는 딥링크를 열 때마다
/// "앱에서 열까요?" 확인창이 떠서 명령만으로 화면을 옮길 수 없기 때문이다.
Future<void> startStoreRouteWatcher(GoRouter router) async {
  if (!storeModeEnabled) return;
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/store_route.txt');
  _routeWatcher?.cancel();
  _routeWatcher = Timer.periodic(const Duration(milliseconds: 500), (_) async {
    if (!await file.exists()) return;
    final route = (await file.readAsString()).trim();
    await file.delete();
    if (route.isNotEmpty) router.go(route);
  });
}

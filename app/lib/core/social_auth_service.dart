import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

enum SocialProvider { google, apple, kakao }

extension SocialProviderX on SocialProvider {
  String get serverName {
    switch (this) {
      case SocialProvider.google:
        return 'GOOGLE';
      case SocialProvider.apple:
        return 'APPLE';
      case SocialProvider.kakao:
        return 'KAKAO';
    }
  }

  String get displayName {
    switch (this) {
      case SocialProvider.google:
        return '구글';
      case SocialProvider.apple:
        return '애플';
      case SocialProvider.kakao:
        return '카카오';
    }
  }

  static SocialProvider? fromServerName(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'GOOGLE':
        return SocialProvider.google;
      case 'APPLE':
        return SocialProvider.apple;
      case 'KAKAO':
        return SocialProvider.kakao;
      default:
        return null;
    }
  }
}

/// 소셜 로그인 SDK 호출 결과 — 서버 /auth/social/login 에 보낼 페이로드.
class SocialAuthResult {
  final SocialProvider provider;
  final Map<String, dynamic> tokenPayload;

  /// provider 가 SDK 응답에서 직접 준 사용자 정보 (가입 화면 기본값용).
  /// 서버에서 검증된 값이 우선이지만, 일부 provider 는 첫 로그인에만 이름을 줘서
  /// 클라이언트 측에서 한 번 받아둔다.
  final String? displayName;
  final String? email;

  const SocialAuthResult({
    required this.provider,
    required this.tokenPayload,
    this.displayName,
    this.email,
  });
}

class SocialAuthCancelledException implements Exception {
  final String message;
  SocialAuthCancelledException([this.message = '소셜 로그인이 취소되었습니다.']);
  @override
  String toString() => message;
}

class SocialAuthService {
  static GoogleSignIn? _googleSignIn;

  static GoogleSignIn _google() {
    return _googleSignIn ??= GoogleSignIn(
      scopes: const ['email', 'profile'],
    );
  }

  /// 카카오 SDK 초기화 — main() 에서 한 번 호출.
  /// nativeAppKey 는 카카오 디벨로퍼스에서 발급받은 네이티브 앱 키.
  static void initKakao({required String nativeAppKey}) {
    KakaoSdk.init(nativeAppKey: nativeAppKey);
  }

  static Future<SocialAuthResult> signIn(SocialProvider provider) async {
    switch (provider) {
      case SocialProvider.google:
        return _signInWithGoogle();
      case SocialProvider.apple:
        return _signInWithApple();
      case SocialProvider.kakao:
        return _signInWithKakao();
    }
  }

  static Future<void> signOut(SocialProvider provider) async {
    switch (provider) {
      case SocialProvider.google:
        try {
          await _google().signOut();
        } catch (_) {}
        return;
      case SocialProvider.kakao:
        try {
          await UserApi.instance.logout();
        } catch (_) {}
        return;
      case SocialProvider.apple:
        // Apple 은 명시적 sign-out API 없음 (시스템 설정에서 관리).
        return;
    }
  }

  static Future<SocialAuthResult> _signInWithGoogle() async {
    final google = _google();
    // 안정성을 위해 이전 세션 정리.
    try {
      await google.signOut();
    } catch (_) {}

    final account = await google.signIn();
    if (account == null) {
      throw SocialAuthCancelledException();
    }
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google idToken 을 받지 못했습니다.');
    }

    return SocialAuthResult(
      provider: SocialProvider.google,
      tokenPayload: {'idToken': idToken},
      displayName: account.displayName,
      email: account.email,
    );
  }

  static Future<SocialAuthResult> _signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256(rawNonce);

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw Exception('Apple identityToken 을 받지 못했습니다.');
    }

    final fullName = [
      credential.givenName,
      credential.familyName,
    ].where((s) => s != null && s.isNotEmpty).join(' ').trim();

    return SocialAuthResult(
      provider: SocialProvider.apple,
      tokenPayload: {
        'identityToken': identityToken,
        if (credential.authorizationCode.isNotEmpty)
          'authorizationCode': credential.authorizationCode,
        'rawNonce': rawNonce,
      },
      displayName: fullName.isEmpty ? null : fullName,
      email: credential.email,
    );
  }

  static Future<SocialAuthResult> _signInWithKakao() async {
    OAuthToken token;
    try {
      // 카카오톡이 설치돼 있으면 앱 로그인 우선, 안 되면 계정 로그인 fallback
      if (await isKakaoTalkInstalled()) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
        } catch (_) {
          token = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
    } catch (e) {
      // 카카오 SDK 는 사용자 취소를 별도 예외 타입으로 던지지만 메시지로도 식별 가능
      final msg = e.toString();
      if (msg.contains('CANCELED') || msg.contains('cancel')) {
        throw SocialAuthCancelledException();
      }
      rethrow;
    }

    String? displayName;
    String? email;
    try {
      final me = await UserApi.instance.me();
      displayName = me.kakaoAccount?.profile?.nickname;
      email = me.kakaoAccount?.email;
    } catch (_) {
      // 사용자 정보 조회 실패해도 토큰은 서버에서 검증하므로 진행.
    }

    return SocialAuthResult(
      provider: SocialProvider.kakao,
      tokenPayload: {'accessToken': token.accessToken},
      displayName: displayName,
      email: email,
    );
  }

  static String _generateNonce([int length = 32]) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  static String _sha256(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}

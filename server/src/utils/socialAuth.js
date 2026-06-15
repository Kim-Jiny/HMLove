import crypto from 'crypto';
import { OAuth2Client } from 'google-auth-library';
import appleSignin from 'apple-signin-auth';

/**
 * Google ID Token 검증.
 * 클라이언트(iOS/Android)에서 google_sign_in으로 받은 idToken 을 검증한다.
 *
 * audience 는 환경에 따라 여러 client id 를 허용해야 함:
 *   - iOS client id (REVERSED_CLIENT_ID 의 원본)
 *   - Android client id
 *   - Web/Server client id (서버에서 발급한 OAuth client)
 *
 * GOOGLE_CLIENT_IDS 는 콤마로 구분된 client id 목록.
 */
const googleClient = new OAuth2Client();

export async function verifyGoogleIdToken(idToken) {
  const audiences = (process.env.GOOGLE_CLIENT_IDS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  if (audiences.length === 0) {
    throw new Error('GOOGLE_CLIENT_IDS 환경변수가 설정되지 않았습니다.');
  }

  const ticket = await googleClient.verifyIdToken({
    idToken,
    audience: audiences,
  });
  const payload = ticket.getPayload();
  if (!payload) throw new Error('Google 토큰 검증 실패');

  return {
    providerId: payload.sub,
    email: payload.email || null,
    emailVerified: payload.email_verified === true,
    name: payload.name || null,
    picture: payload.picture || null,
  };
}

/**
 * Apple Identity Token 검증.
 * sign_in_with_apple 에서 받은 identityToken 을 검증한다.
 *
 * APPLE_CLIENT_IDS: 콤마 구분 audience 목록.
 *   - iOS native: 앱의 Bundle ID (예: com.example.hmlove)
 *   - Android/web: Apple Developer 에서 만든 Service ID
 */
export async function verifyAppleIdentityToken(identityToken, rawNonce) {
  const audiences = (process.env.APPLE_CLIENT_IDS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  if (audiences.length === 0) {
    throw new Error('APPLE_CLIENT_IDS 환경변수가 설정되지 않았습니다.');
  }

  // 리플레이 방지: 클라이언트가 보낸 rawNonce 의 sha256(hex)이 토큰의 nonce 클레임과
  // 일치해야 한다. 클라이언트(social_auth_service)는 sha256(rawNonce).toString() =
  // hex 를 Apple 에 nonce 로 전달하고, rawNonce 원문을 서버로 보낸다.
  if (!rawNonce || typeof rawNonce !== 'string') {
    throw new Error('Apple nonce 가 필요합니다.');
  }
  const hashedNonce = crypto.createHash('sha256').update(rawNonce).digest('hex');

  // verifyIdToken 은 옵션을 jsonwebtoken.verify 로 그대로 전달한다.
  // jsonwebtoken 의 nonce 옵션이 payload.nonce 와 정확히 일치하는지 검사한다.
  const payload = await appleSignin.verifyIdToken(identityToken, {
    audience: audiences,
    nonce: hashedNonce,
    ignoreExpiration: false,
  });

  return {
    providerId: payload.sub,
    email: payload.email || null,
    emailVerified: payload.email_verified === 'true' || payload.email_verified === true,
    isPrivateEmail:
      payload.is_private_email === 'true' || payload.is_private_email === true,
  };
}

/**
 * Kakao access token 검증.
 * kakao_flutter_sdk_user 에서 받은 accessToken 으로 카카오 user info API 호출.
 *
 * 카카오는 ID Token 보다 access token + REST API 호출 방식이 표준.
 */
export async function verifyKakaoAccessToken(accessToken) {
  const res = await fetch('https://kapi.kakao.com/v2/user/me', {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8',
    },
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Kakao 토큰 검증 실패: ${res.status} ${text}`);
  }

  // 토큰 혼동 방지: 토큰이 우리 카카오 앱으로 발급된 것인지 app_id 로 확인.
  // KAKAO_APP_ID(네이티브 앱 키의 앱 ID, 숫자)가 설정된 경우에만 강제한다.
  const expectedAppId = process.env.KAKAO_APP_ID;
  if (expectedAppId) {
    const infoRes = await fetch('https://kapi.kakao.com/v1/user/access_token_info', {
      method: 'GET',
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!infoRes.ok) {
      throw new Error(`Kakao 토큰 정보 조회 실패: ${infoRes.status}`);
    }
    const info = await infoRes.json();
    if (String(info.app_id) !== String(expectedAppId)) {
      throw new Error('Kakao 토큰의 app_id 가 일치하지 않습니다.');
    }
  }

  const data = await res.json();
  const kakaoAccount = data.kakao_account || {};
  const profile = kakaoAccount.profile || {};

  return {
    providerId: String(data.id),
    email: kakaoAccount.email || null,
    emailVerified: kakaoAccount.is_email_verified === true,
    name: profile.nickname || null,
    picture: profile.profile_image_url || null,
  };
}

/**
 * provider 이름으로 검증 함수 디스패치.
 * 검증 실패 시 throw.
 */
export async function verifySocialToken(provider, payload) {
  switch (provider) {
    case 'GOOGLE':
      if (!payload.idToken) throw new Error('idToken 이 필요합니다.');
      return verifyGoogleIdToken(payload.idToken);
    case 'APPLE':
      if (!payload.identityToken) throw new Error('identityToken 이 필요합니다.');
      return verifyAppleIdentityToken(payload.identityToken, payload.rawNonce);
    case 'KAKAO':
      if (!payload.accessToken) throw new Error('accessToken 이 필요합니다.');
      return verifyKakaoAccessToken(payload.accessToken);
    default:
      throw new Error(`지원하지 않는 provider: ${provider}`);
  }
}

export const SUPPORTED_PROVIDERS = ['GOOGLE', 'APPLE', 'KAKAO'];

export function normalizeProvider(raw) {
  if (!raw) return null;
  const upper = String(raw).toUpperCase();
  return SUPPORTED_PROVIDERS.includes(upper) ? upper : null;
}

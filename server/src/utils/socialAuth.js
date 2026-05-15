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
export async function verifyAppleIdentityToken(identityToken) {
  const audiences = (process.env.APPLE_CLIENT_IDS || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  if (audiences.length === 0) {
    throw new Error('APPLE_CLIENT_IDS 환경변수가 설정되지 않았습니다.');
  }

  const payload = await appleSignin.verifyIdToken(identityToken, {
    audience: audiences,
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
      return verifyAppleIdentityToken(payload.identityToken);
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

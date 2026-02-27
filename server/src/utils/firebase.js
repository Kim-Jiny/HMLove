import admin from 'firebase-admin';
import { readFileSync } from 'fs';
import { resolve } from 'path';

// 서비스 계정 키: JSON 문자열(배포) 또는 파일 경로(로컬) 지원
const serviceAccountEnv = process.env.FIREBASE_SERVICE_ACCOUNT;

if (serviceAccountEnv) {
  let serviceAccount;
  try {
    // 배포 환경: 환경변수에 JSON 문자열이 직접 들어있는 경우
    serviceAccount = JSON.parse(serviceAccountEnv);
  } catch {
    // 로컬 환경: 파일 경로인 경우
    serviceAccount = JSON.parse(readFileSync(resolve(serviceAccountEnv), 'utf-8'));
  }
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
} else {
  admin.initializeApp({
    projectId: process.env.FIREBASE_PROJECT_ID || 'hmlove-251115',
  });
}

/**
 * Send a push notification to a specific FCM token.
 * @param {object} opts
 * @param {string} opts.token - FCM token
 * @param {string} opts.title
 * @param {string} opts.body
 * @param {object} opts.data
 * @param {boolean} [opts.sound=true] - 소리 활성화 여부
 */
export async function sendPushNotification({ token, title, body, data, sound = true }) {
  if (!token) return;

  try {
    // data 필드에 title/body도 포함 (클라이언트 폴백용)
    // FCM data 값은 반드시 string이어야 함
    const mergedData = {
      ...(data || {}),
      title: title || '',
      body: body || '',
    };
    // data 값을 모두 string으로 변환
    for (const key of Object.keys(mergedData)) {
      if (typeof mergedData[key] !== 'string') {
        mergedData[key] = String(mergedData[key]);
      }
    }

    await admin.messaging().send({
      token,
      notification: { title, body },
      data: mergedData,
      android: {
        priority: 'high',
        notification: {
          channelId: sound ? 'default' : 'silent',
          ...(sound ? { sound: 'default' } : {}),
        },
      },
      apns: {
        payload: {
          aps: {
            badge: 1,
            ...(sound ? { sound: 'default' } : {}),
          },
        },
      },
    });
    console.log(`[Push] Sent to token: ${token.substring(0, 20)}... (sound: ${sound})`);
  } catch (err) {
    // 토큰이 유효하지 않으면 DB에서 삭제
    if (err.code === 'messaging/registration-token-not-registered' ||
        err.code === 'messaging/invalid-registration-token') {
      console.log('[Push] Invalid token, removing from DB');
      const prisma = (await import('./prisma.js')).default;
      await prisma.user.updateMany({
        where: { fcmToken: token },
        data: { fcmToken: null },
      });
    } else {
      console.error('[Push] Send error:', err.message);
    }
  }
}

/**
 * 커플 상대방에게 푸시 알림을 보내는 헬퍼 함수
 * + Notification DB에 기록 저장 (chat 제외)
 */
// 알림 타입 → 설정 키 매핑
const _typeToPrefKey = {
  chat: 'noti_chat',
  feed: 'noti_feed',
  feed_like: 'noti_feed',
  feed_comment: 'noti_feed',
  calendar: 'noti_calendar',
  anniversary: 'noti_anniversary',
  letter: 'noti_letter',
  mood: 'noti_mood',
  fight: 'noti_fight',
};

export async function notifyPartner({ userId, coupleId, title, body, data }) {
  try {
    const prisma = (await import('./prisma.js')).default;
    const partner = await prisma.user.findFirst({
      where: {
        coupleId,
        id: { not: userId },
      },
      select: { id: true, fcmToken: true, notiPrefs: true },
    });
    if (!partner) return;

    // 수신자의 알림 설정 확인
    const prefs = partner.notiPrefs || {};
    const type = data?.type;

    // 전체 알림 OFF면 보내지 않음
    if (prefs.noti_all === false) return;

    // 카테고리별 알림 OFF면 보내지 않음
    const prefKey = _typeToPrefKey[type];
    if (prefKey && prefs[prefKey] === false) return;

    // 채팅은 알림 DB에 저장하지 않음
    if (type && type !== 'chat') {
      await prisma.notification.create({
        data: {
          userId: partner.id,
          type,
          title,
          body,
          data: data || {},
        },
      });
    }

    if (partner.fcmToken) {
      // 카테고리별 소리 설정 확인 (개별 소리 토글)
      const sound = prefKey ? prefs[`${prefKey}_sound`] !== false : true;

      await sendPushNotification({ token: partner.fcmToken, title, body, data, sound });
    }
  } catch (err) {
    console.error('[Push] notifyPartner error:', err.message);
  }
}

export default admin;

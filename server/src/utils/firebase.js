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
 * @param {boolean} [opts.mutableContent=false] - iOS Notification Service Extension 트리거 여부 (위젯 갱신 등 사전 작업)
 */
export async function sendPushNotification({ token, title, body, data, sound = true, mutableContent = false }) {
  if (!token) return;

  try {
    // 실제 미읽음 알림 개수 조회
    let badgeCount = 1;
    try {
      const prisma = (await import('./prisma.js')).default;
      const user = await prisma.user.findFirst({
        where: { fcmToken: token },
        select: { id: true, coupleId: true },
      });
      if (user) {
        const [unreadMessages, unreadNotifications] = await Promise.all([
          prisma.message.count({
            where: {
              coupleId: user.coupleId,
              senderId: { not: user.id },
              isRead: false,
            },
          }),
          prisma.notification.count({
            where: { userId: user.id, isRead: false },
          }),
        ]);
        badgeCount = unreadMessages + unreadNotifications;
      }
    } catch {
      // 뱃지 조회 실패 시 기본값 1 사용
    }

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
        headers: {
          'apns-push-type': 'alert',
          'apns-priority': '10',
        },
        payload: {
          aps: {
            badge: badgeCount,
            ...(sound ? { sound: 'default' } : {}),
            ...(mutableContent ? { mutableContent: true } : {}),
          },
        },
      },
    });
    console.log(`[Push] Sent to token: ${token.substring(0, 20)}... (sound: ${sound}, mutable: ${mutableContent})`);
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
 * Send a silent (data-only) push notification — no visible notification.
 * Used to trigger background tasks like widget refresh.
 */
export async function sendSilentPush({ token, data }) {
  if (!token) return;

  try {
    // FCM data 값은 반드시 string이어야 함
    const stringData = {};
    for (const key of Object.keys(data || {})) {
      stringData[key] = typeof data[key] === 'string' ? data[key] : String(data[key]);
    }

    await admin.messaging().send({
      token,
      data: stringData,
      android: { priority: 'high' },
      apns: {
        headers: {
          'apns-push-type': 'background',
          'apns-priority': '5',
        },
        payload: {
          aps: { contentAvailable: true },
        },
      },
    });
    console.log(`[Push] Silent push sent to token: ${token.substring(0, 20)}...`);
  } catch (err) {
    if (err.code === 'messaging/registration-token-not-registered' ||
        err.code === 'messaging/invalid-registration-token') {
      console.log('[Push] Invalid token, removing from DB');
      const prisma = (await import('./prisma.js')).default;
      await prisma.user.updateMany({
        where: { fcmToken: token },
        data: { fcmToken: null },
      });
    } else {
      console.error('[Push] Silent push error:', err.message);
    }
  }
}

/**
 * 커플 상대방에게 사일런트 푸시를 보내는 헬퍼 (알림 설정 무시, notification 없음)
 */
export async function notifyPartnerSilent({ userId, coupleId, data }) {
  try {
    const prisma = (await import('./prisma.js')).default;
    const partner = await prisma.user.findFirst({
      where: {
        coupleId,
        id: { not: userId },
      },
      select: { fcmToken: true },
    });
    if (!partner?.fcmToken) return;

    await sendSilentPush({ token: partner.fcmToken, data });
  } catch (err) {
    console.error('[Push] notifyPartnerSilent error:', err.message);
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
  doodle: 'noti_doodle',
  mission: 'noti_mission',
  mood: 'noti_mood',
  fight: 'noti_fight',
  wishlist: 'noti_wishlist',
  question: 'noti_question',
};

export async function notifyPartner({ userId, coupleId, title, body, data, silentData }) {
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
    if (prefs.noti_all === false) {
      // 알림 OFF여도 사일런트 푸시는 전송 (위젯 갱신용, 사용자에게 안 보임)
      if (silentData && partner.fcmToken) {
        await sendSilentPush({ token: partner.fcmToken, data: silentData });
      }
      return;
    }

    // 카테고리별 알림 OFF면 보내지 않음
    const prefKey = _typeToPrefKey[type];
    if (prefKey && prefs[prefKey] === false) {
      if (silentData && partner.fcmToken) {
        await sendSilentPush({ token: partner.fcmToken, data: silentData });
      }
      return;
    }

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

      // iOS Notification Service Extension이 위젯 데이터를 갱신해야 하는 type 화이트리스트.
      // mutable-content:1을 설정하면 alert가 표시되기 전 NSE가 깨어나 백그라운드 작업을 수행한다.
      // (silent push는 OS가 throttle하지만 alert push는 즉시 전달됨)
      const mutableContent = type === 'calendar' || type === 'doodle';

      await sendPushNotification({ token: partner.fcmToken, title, body, data, sound, mutableContent });

      // 동일 partner 토큰으로 사일런트 푸시도 전송 (DB 재조회 없음)
      // Android는 이 silent push로 위젯 갱신, iOS는 위 NSE로 갱신
      if (silentData) {
        await sendSilentPush({ token: partner.fcmToken, data: silentData });
      }
    }
  } catch (err) {
    console.error('[Push] notifyPartner error:', err.message);
  }
}

export default admin;

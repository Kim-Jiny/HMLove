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
 */
export async function sendPushNotification({ token, title, body, data }) {
  if (!token) return;

  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data: data || {},
      android: {
        priority: 'high',
        notification: { channelId: 'default', sound: 'default' },
      },
      apns: {
        payload: {
          aps: { sound: 'default', badge: 1 },
        },
      },
    });
    console.log(`[Push] Sent to token: ${token.substring(0, 20)}...`);
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
 */
export async function notifyPartner({ userId, coupleId, title, body, data }) {
  try {
    const prisma = (await import('./prisma.js')).default;
    const partner = await prisma.user.findFirst({
      where: {
        coupleId,
        id: { not: userId },
      },
      select: { fcmToken: true },
    });
    if (partner?.fcmToken) {
      await sendPushNotification({ token: partner.fcmToken, title, body, data });
    }
  } catch (err) {
    console.error('[Push] notifyPartner error:', err.message);
  }
}

export default admin;

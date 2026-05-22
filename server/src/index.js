// 반드시 모든 다른 import 보다 위. @prisma/client 가 import 되는 순간
// 자체적으로 .env 를 자동 로드하므로, 그 전에 .env.local 을 process.env 에
// 박아두려면 별도 부트스트랩 모듈을 가장 먼저 import 해야 한다.
import './env.js';

import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import cookieParser from 'cookie-parser';
import jwt from 'jsonwebtoken';
import path from 'path';

import { globalLimiter } from './middleware/rateLimit.js';
import prisma from './utils/prisma.js';
import { sendPushNotification, notifyPartner } from './utils/firebase.js';
import { getUpcomingAnniversaries } from './utils/anniversary.js';
import authRoutes from './routes/auth.js';
import socialRoutes from './routes/social.js';
import coupleRoutes from './routes/couple.js';
import calendarRoutes from './routes/calendar.js';
import feedRoutes from './routes/feed.js';
import moodRoutes from './routes/mood.js';
import fightRoutes from './routes/fight.js';
import fortuneRoutes from './routes/fortune.js';
import chatRoutes from './routes/chat.js';
import photoRoutes from './routes/photo.js';
import letterRoutes from './routes/letter.js';
import inquiryRoutes from './routes/inquiry.js';
import adminRoutes from './routes/admin.js';
import settingsRoutes from './routes/settings.js';
import notificationRoutes from './routes/notification.js';
import missionRoutes from './routes/mission.js';
import mapRoutes from './routes/map.js';
import wishlistRoutes from './routes/wishlist.js';
import questionRoutes from './routes/question.js';
import doodleRoutes from './routes/doodle.js';

const app = express();
app.set('trust proxy', 1);
const server = createServer(app);
const connectedUserSockets = new Map();

// Socket.io 설정
const io = new Server(server, {
  cors: {
    origin: process.env.CLIENT_URL || 'http://localhost:3000',
    methods: ['GET', 'POST'],
    credentials: true,
  },
});

// io 객체를 라우트에서 사용할 수 있도록 공유
app.set('io', io);

// 채팅 푸시 debounce: 3초 내 같은 유저 → 같은 상대 메시지를 묶어서 1개 알림
const _chatPushTimers = new Map(); // key: `${senderId}:${partnerId}`
function debouncedChatPush({ senderId, partnerId, coupleId, token, senderNickname, body }) {
  const key = `${senderId}:${partnerId}`;
  const existing = _chatPushTimers.get(key);

  if (existing) {
    existing.count++;
    existing.lastBody = body;
    clearTimeout(existing.timer);
  } else {
    _chatPushTimers.set(key, { count: 1, lastBody: body });
  }

  const entry = _chatPushTimers.get(key);
  entry.timer = setTimeout(() => {
    const pushBody = entry.count > 1
      ? `${entry.count}개의 새 메시지`
      : entry.lastBody;
    sendPushNotification({
      token,
      title: senderNickname || '상대방',
      body: pushBody,
      data: { type: 'chat', coupleId: coupleId || '' },
    });
    _chatPushTimers.delete(key);
  }, 3000);
}

function addUserSocket(userId, socketId) {
  if (!userId || !socketId) return 0;
  const sockets = connectedUserSockets.get(userId) ?? new Set();
  sockets.add(socketId);
  connectedUserSockets.set(userId, sockets);
  return sockets.size;
}

function removeUserSocket(userId, socketId) {
  if (!userId || !socketId) return 0;
  const sockets = connectedUserSockets.get(userId);
  if (!sockets) return 0;

  sockets.delete(socketId);
  if (sockets.size === 0) {
    connectedUserSockets.delete(userId);
    return 0;
  }

  connectedUserSockets.set(userId, sockets);
  return sockets.size;
}

// Middleware
app.use(cors({
  origin: process.env.CLIENT_URL || 'http://localhost:3000',
  credentials: true,
}));
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(globalLimiter);
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));
app.use(cookieParser());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 정적 파일 제공
app.use('/uploads', express.static(path.resolve('uploads')));
app.use(express.static(path.resolve('public')));

// Admin 페이지 라우트 (인라인 스크립트 허용)
app.get('/admin', (req, res) => {
  res.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:;");
  res.sendFile(path.resolve('public/admin.html'));
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/auth/social', socialRoutes);
app.use('/api/couple', coupleRoutes);
app.use('/api/calendar', calendarRoutes);
app.use('/api/feed', feedRoutes);
app.use('/api/mood', moodRoutes);
app.use('/api/fight', fightRoutes);
app.use('/api/fortune', fortuneRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/photo', photoRoutes);
app.use('/api/letter', letterRoutes);
app.use('/api/inquiry', inquiryRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/settings', settingsRoutes);
app.use('/api/notification', notificationRoutes);
app.use('/api/mission', missionRoutes);
app.use('/api/map', mapRoutes);
app.use('/api/wishlist', wishlistRoutes);
app.use('/api/question', questionRoutes);
app.use('/api/doodle', doodleRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Socket.io - 채팅
io.use((socket, next) => {
  try {
    const token = socket.handshake.auth?.token;
    if (!token) return next(new Error('인증 토큰이 필요합니다.'));

    const payload = jwt.verify(token, process.env.JWT_SECRET);
    socket.userId = payload.userId;
    next();
  } catch {
    next(new Error('유효하지 않은 토큰입니다.'));
  }
});

io.on('connection', async (socket) => {
  try {
    console.log(`Socket connected: ${socket.userId}`);
    const activeSocketCount = addUserSocket(socket.userId, socket.id);

    // 사용자의 커플 룸에 참여
    const user = await prisma.user.findUnique({
      where: { id: socket.userId },
      select: { coupleId: true, nickname: true },
    });

    if (user?.coupleId) {
      const room = `couple:${user.coupleId}`;
      socket.join(room);
      socket.coupleId = user.coupleId;
      socket.nickname = user.nickname;

      const partner = await prisma.user.findFirst({
        where: {
          coupleId: user.coupleId,
          id: { not: socket.userId },
        },
        select: { id: true },
      });
      if (partner && connectedUserSockets.has(partner.id)) {
        socket.emit('partner:online', { userId: partner.id });
      }

      // 같은 사용자의 첫 활성 소켓일 때만 상대방에게 온라인 알림
      if (activeSocketCount == 1) {
        socket.to(room).emit('partner:online', { userId: socket.userId });
      }
    }
  } catch (err) {
    removeUserSocket(socket.userId, socket.id);
    console.error('Socket connection setup error:', err);
    socket.disconnect(true);
    return;
  }

  // 메시지 전송
  socket.on('message:send', async (data, ack) => {
    try {
      if (!socket.coupleId) {
        ack?.('채팅 연결이 준비되지 않았습니다.');
        return;
      }

      const { content, imageUrls } = data;
      const urls = Array.isArray(imageUrls)
        ? imageUrls.slice(0, 5).filter(u => typeof u === 'string' && u.length < 2048)
        : [];
      if (content !== undefined && content !== null && typeof content !== 'string') {
        ack?.('메시지 형식이 올바르지 않습니다.');
        return;
      }
      if (!content && urls.length === 0) {
        ack?.('보낼 메시지가 없습니다.');
        return;
      }
      if (typeof content === 'string' && content.length > 5000) {
        ack?.('메시지가 너무 깁니다.');
        return;
      }

      const message = await prisma.message.create({
        data: {
          coupleId: socket.coupleId,
          senderId: socket.userId,
          content,
          imageUrls: urls,
        },
        include: {
          sender: { select: { id: true, nickname: true, profileImage: true } },
        },
      });

      const room = `couple:${socket.coupleId}`;
      const payload = { ...message, _tempId: data._tempId || null };
      io.to(room).emit('message:new', payload);
      ack?.(null, { ok: true, messageId: message.id });

      // 상대방에게 푸시 알림 (debounce 적용)
      const partner = await prisma.user.findFirst({
        where: {
          coupleId: socket.coupleId,
          id: { not: socket.userId },
        },
        select: { id: true, fcmToken: true },
      });
      if (partner?.fcmToken) {
        let pushBody;
        if (!content) {
          pushBody = urls.length === 1
            ? '사진을 보냈습니다'
            : `사진 ${urls.length}장을 보냈습니다`;
        } else if (content.startsWith('__GAME_ROULETTE__:')) {
          pushBody = '🎰 룰렛을 돌렸어요!';
        } else if (content.startsWith('__GAME_LADDER__:')) {
          pushBody = '🪜 사다리타기를 했어요!';
        } else {
          pushBody = content;
        }
        debouncedChatPush({
          senderId: socket.userId,
          partnerId: partner.id,
          coupleId: socket.coupleId,
          token: partner.fcmToken,
          senderNickname: socket.nickname,
          body: pushBody,
        });
      }
    } catch (err) {
      console.error('Socket message:send error:', err);
      ack?.('메시지 전송에 실패했습니다.');
      socket.emit('error', { message: '메시지 전송에 실패했습니다.' });
    }
  });

  // 읽음 처리
  socket.on('message:read', async () => {
    try {
      if (!socket.coupleId) return;

      await prisma.message.updateMany({
        where: {
          coupleId: socket.coupleId,
          senderId: { not: socket.userId },
          isRead: false,
        },
        data: { isRead: true },
      });

      const room = `couple:${socket.coupleId}`;
      socket.to(room).emit('message:read', { readBy: socket.userId });
    } catch (err) {
      console.error('Socket message:read error:', err);
    }
  });

  // 메시지 수정
  socket.on('message:edit', async (data) => {
    try {
      if (!socket.coupleId) return;
      const { messageId, content } = data;
      if (!messageId || !content) return;
      if (typeof content !== 'string' || content.length > 5000) return;

      const message = await prisma.message.findUnique({ where: { id: messageId } });
      if (!message || message.senderId !== socket.userId || message.coupleId !== socket.coupleId) return;

      const updated = await prisma.message.update({
        where: { id: messageId },
        data: { content, isEdited: true },
        include: {
          sender: { select: { id: true, nickname: true, profileImage: true } },
        },
      });

      const room = `couple:${socket.coupleId}`;
      io.to(room).emit('message:edited', updated);
    } catch (err) {
      console.error('Socket message:edit error:', err);
    }
  });

  // 메시지 삭제
  socket.on('message:delete', async (data) => {
    try {
      if (!socket.coupleId) return;
      const { messageId } = data;
      if (!messageId) return;

      const message = await prisma.message.findUnique({ where: { id: messageId } });
      if (!message || message.senderId !== socket.userId || message.coupleId !== socket.coupleId) return;

      await prisma.message.delete({ where: { id: messageId } });

      const room = `couple:${socket.coupleId}`;
      io.to(room).emit('message:deleted', { messageId });
    } catch (err) {
      console.error('Socket message:delete error:', err);
    }
  });

  // 타이핑 표시 (5초 타임아웃으로 자동 해제)
  socket.on('typing:start', () => {
    if (!socket.coupleId) return;
    socket.to(`couple:${socket.coupleId}`).emit('typing:start', { userId: socket.userId });
    // 기존 타이머 초기화
    if (socket._typingTimer) clearTimeout(socket._typingTimer);
    socket._typingTimer = setTimeout(() => {
      socket.to(`couple:${socket.coupleId}`).emit('typing:stop', { userId: socket.userId });
      socket._typingTimer = null;
    }, 5000);
  });

  socket.on('typing:stop', () => {
    if (!socket.coupleId) return;
    if (socket._typingTimer) {
      clearTimeout(socket._typingTimer);
      socket._typingTimer = null;
    }
    socket.to(`couple:${socket.coupleId}`).emit('typing:stop', { userId: socket.userId });
  });

  // 연결 해제
  socket.on('disconnect', () => {
    if (socket._typingTimer) clearTimeout(socket._typingTimer);
    const remainingSocketCount = removeUserSocket(socket.userId, socket.id);
    console.log(`Socket disconnected: ${socket.userId}`);
    if (socket.coupleId && remainingSocketCount === 0) {
      socket.to(`couple:${socket.coupleId}`).emit('partner:offline', { userId: socket.userId });
    }
  });
});

// 예약 편지 배달 스케줄러 (1분마다 체크)
async function deliverScheduledLetters() {
  try {
    const now = new Date();
    const letters = await prisma.letter.findMany({
      where: {
        status: 'SCHEDULED',
        deliveryDate: { lte: now },
      },
      include: {
        writer: { select: { id: true, nickname: true, coupleId: true } },
      },
    });

    for (const letter of letters) {
      await prisma.letter.update({
        where: { id: letter.id },
        data: { status: 'DELIVERED' },
      });

      // 수신자에게 푸시 알림
      notifyPartner({
        userId: letter.writerId,
        coupleId: letter.writer.coupleId,
        title: letter.writer.nickname || '상대방',
        body: '편지가 도착했어요 💌',
        data: { type: 'letter', letterId: letter.id },
      });

      console.log(`[Scheduler] Letter ${letter.id} delivered`);
    }
  } catch (err) {
    console.error('[Scheduler] deliverScheduledLetters error:', err.message);
  }
}

const letterInterval = setInterval(deliverScheduledLetters, 60 * 1000); // 1분마다

// 기념일 리마인드 스케줄러 (1시간마다 체크)
async function sendAnniversaryReminders() {
  try {
    const couples = await prisma.couple.findMany({
      include: {
        users: {
          select: { id: true, nickname: true, birthDate: true, fcmToken: true, notiPrefs: true },
        },
      },
    });

    const now = new Date();
    // KST = UTC+9
    const kst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
    const todayStr = `${kst.getUTCFullYear()}-${String(kst.getUTCMonth() + 1).padStart(2, '0')}-${String(kst.getUTCDate()).padStart(2, '0')}`;

    let sentCount = 0;

    for (const couple of couples) {
      if (couple.users.length < 2) continue;

      for (const user of couple.users) {
        const prefs = user.notiPrefs || {};

        // 전체 알림 OFF이거나 기념일 알림 OFF이면 스킵
        if (prefs.noti_all === false || prefs.noti_anniversary === false) continue;

        // 유저별 마일스톤 설정 읽기
        const milestoneConfig = {
          dayMilestones: Array.isArray(prefs.noti_anniversary_milestones_day)
            ? prefs.noti_anniversary_milestones_day
            : undefined,
          yearMilestones: Array.isArray(prefs.noti_anniversary_milestones_year)
            ? prefs.noti_anniversary_milestones_year
            : undefined,
          birthday: prefs.noti_anniversary_milestones_birthday !== false,
        };

        const upcoming = getUpcomingAnniversaries(couple, 30, milestoneConfig);
        if (upcoming.length === 0) continue;

        const remindDays = Array.isArray(prefs.noti_anniversary_remind_days)
          ? prefs.noti_anniversary_remind_days
          : [1]; // 기본값: 1일 전

        for (const ann of upcoming) {
          if (!remindDays.includes(ann.daysLeft)) continue;

          // 중복 방지: 오늘 같은 알림을 이미 보냈는지 확인
          const dedupKey = `anniversary_remind:${ann.title}:d-${ann.daysLeft}`;
          // KST 자정 기준으로 중복 방지 (UTC 기준이 아닌 KST 00:00부터)
          const kstMidnightUtc = new Date(todayStr + 'T00:00:00+09:00');
          const existing = await prisma.notification.findFirst({
            where: {
              userId: user.id,
              type: 'anniversary_remind',
              createdAt: { gte: kstMidnightUtc },
              data: { path: ['dedupKey'], equals: dedupKey },
            },
          });
          if (existing) continue;

          // Notification 레코드 생성
          const body = ann.daysLeft === 0
            ? `오늘은 ${ann.title}이에요!`
            : `${ann.title}이 ${ann.daysLeft}일 남았어요!`;

          await prisma.notification.create({
            data: {
              userId: user.id,
              type: 'anniversary_remind',
              title: '기념일 리마인드',
              body,
              data: { dedupKey, anniversaryTitle: ann.title, daysLeft: ann.daysLeft },
            },
          });

          // 푸시 알림 전송
          if (user.fcmToken) {
            sendPushNotification({
              token: user.fcmToken,
              title: '기념일 리마인드',
              body,
              data: { type: 'anniversary_remind' },
            });
          }

          sentCount++;
        }
      }
    }

    if (sentCount > 0) {
      console.log(`[Scheduler] Anniversary reminders sent: ${sentCount}`);
    }
    console.log(`[Scheduler] Anniversary reminders checked`);
  } catch (err) {
    console.error('[Scheduler] sendAnniversaryReminders error:', err.message);
  }
}

const anniversaryInterval = setInterval(sendAnniversaryReminders, 3600 * 1000); // 1시간마다

// 서버 시작
const PORT = process.env.PORT || 4000;

server.listen(PORT, '0.0.0.0', () => {
  console.log(`우리연애 server running on port ${PORT}`);
  deliverScheduledLetters(); // 서버 시작 시 즉시 한번 체크
  sendAnniversaryReminders(); // 서버 시작 시 즉시 한번 체크
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down...');

  // 스케줄러 정리
  clearInterval(letterInterval);
  clearInterval(anniversaryInterval);

  // 모든 소켓 클라이언트에게 서버 종료 알림 후 연결 해제
  io.emit('server:restart');
  io.disconnectSockets(true);

  // 서버 먼저 닫고 DB 연결 해제
  server.close(async () => {
    await prisma.$disconnect();
    console.log('Server closed');
    process.exit(0);
  });

  // 5초 후 강제 종료
  setTimeout(() => process.exit(0), 5000);
});

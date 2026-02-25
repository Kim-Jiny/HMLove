import 'dotenv/config';
import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import cookieParser from 'cookie-parser';
import jwt from 'jsonwebtoken';
import path from 'path';

import prisma from './utils/prisma.js';
import { sendPushNotification } from './utils/firebase.js';
import authRoutes from './routes/auth.js';
import coupleRoutes from './routes/couple.js';
import calendarRoutes from './routes/calendar.js';
import feedRoutes from './routes/feed.js';
import moodRoutes from './routes/mood.js';
import fightRoutes from './routes/fight.js';
import fortuneRoutes from './routes/fortune.js';
import chatRoutes from './routes/chat.js';
import photoRoutes from './routes/photo.js';
import letterRoutes from './routes/letter.js';
import adminRoutes from './routes/admin.js';

const app = express();
const server = createServer(app);

// Socket.io 설정
const io = new Server(server, {
  cors: {
    origin: process.env.CLIENT_URL || 'http://localhost:3000',
    methods: ['GET', 'POST'],
    credentials: true,
  },
});

// Middleware
app.use(cors({
  origin: process.env.CLIENT_URL || 'http://localhost:3000',
  credentials: true,
}));
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(morgan('dev'));
app.use(cookieParser());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 정적 파일 제공
app.use('/uploads', express.static(path.resolve('uploads')));
app.use(express.static(path.resolve('public')));

// Admin 페이지 라우트 (인라인 스크립트 허용을 위해 CSP 해제)
app.get('/admin', (req, res) => {
  res.removeHeader('Content-Security-Policy');
  res.sendFile(path.resolve('public/admin.html'));
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/couple', coupleRoutes);
app.use('/api/calendar', calendarRoutes);
app.use('/api/feed', feedRoutes);
app.use('/api/mood', moodRoutes);
app.use('/api/fight', fightRoutes);
app.use('/api/fortune', fortuneRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/photo', photoRoutes);
app.use('/api/letter', letterRoutes);
app.use('/api/admin', adminRoutes);

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
  console.log(`Socket connected: ${socket.userId}`);

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

    // 상대방에게 온라인 알림
    socket.to(room).emit('partner:online', { userId: socket.userId });
  }

  // 메시지 전송
  socket.on('message:send', async (data) => {
    try {
      if (!socket.coupleId) return;

      const { content, imageUrl } = data;
      if (!content && !imageUrl) return;

      const message = await prisma.message.create({
        data: {
          coupleId: socket.coupleId,
          senderId: socket.userId,
          content,
          imageUrl,
        },
        include: {
          sender: { select: { id: true, nickname: true, profileImage: true } },
        },
      });

      const room = `couple:${socket.coupleId}`;
      const payload = { ...message, _tempId: data._tempId || null };
      io.to(room).emit('message:new', payload);

      // 상대방에게 푸시 알림
      const partner = await prisma.user.findFirst({
        where: {
          coupleId: socket.coupleId,
          id: { not: socket.userId },
        },
        select: { fcmToken: true },
      });
      if (partner?.fcmToken) {
        sendPushNotification({
          token: partner.fcmToken,
          title: socket.nickname || '상대방',
          body: content || '사진을 보냈습니다',
          data: { type: 'chat', coupleId: socket.coupleId },
        });
      }
    } catch (err) {
      console.error('Socket message:send error:', err);
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

      const message = await prisma.message.findUnique({ where: { id: messageId } });
      if (!message || message.senderId !== socket.userId) return;

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
      if (!message || message.senderId !== socket.userId) return;

      await prisma.message.delete({ where: { id: messageId } });

      const room = `couple:${socket.coupleId}`;
      io.to(room).emit('message:deleted', { messageId });
    } catch (err) {
      console.error('Socket message:delete error:', err);
    }
  });

  // 타이핑 표시
  socket.on('typing:start', () => {
    if (!socket.coupleId) return;
    socket.to(`couple:${socket.coupleId}`).emit('typing:start', { userId: socket.userId });
  });

  socket.on('typing:stop', () => {
    if (!socket.coupleId) return;
    socket.to(`couple:${socket.coupleId}`).emit('typing:stop', { userId: socket.userId });
  });

  // 연결 해제
  socket.on('disconnect', () => {
    console.log(`Socket disconnected: ${socket.userId}`);
    if (socket.coupleId) {
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
      const { notifyPartner } = await import('./utils/firebase.js');
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

setInterval(deliverScheduledLetters, 60 * 1000); // 1분마다

// 서버 시작
const PORT = process.env.PORT || 4000;

server.listen(PORT, '0.0.0.0', () => {
  console.log(`HMLove server running on port ${PORT}`);
  deliverScheduledLetters(); // 서버 시작 시 즉시 한번 체크
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down...');
  await prisma.$disconnect();
  server.close();
  process.exit(0);
});

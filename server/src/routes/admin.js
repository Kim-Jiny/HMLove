import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import prisma from '../utils/prisma.js';
import { sendPushNotification } from '../utils/firebase.js';

const router = Router();

// POST /admin/login
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: '아이디와 비밀번호를 입력해주세요.' });
    }

    const admin = await prisma.adminAccount.findUnique({ where: { username } });
    if (!admin) {
      return res.status(401).json({ error: '아이디 또는 비밀번호가 올바르지 않습니다.' });
    }

    const valid = await bcrypt.compare(password, admin.password);
    if (!valid) {
      return res.status(401).json({ error: '아이디 또는 비밀번호가 올바르지 않습니다.' });
    }

    const token = jwt.sign(
      { adminId: admin.id, username: admin.username },
      process.env.JWT_SECRET,
      { expiresIn: '7d' },
    );

    res.json({ token, username: admin.username });
  } catch (err) {
    console.error('Admin login error:', err);
    res.status(500).json({ error: '로그인에 실패했습니다.' });
  }
});

// Admin JWT 인증 미들웨어
function adminAuth(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth?.startsWith('Bearer ')) {
    return res.status(401).json({ error: '관리자 인증이 필요합니다.' });
  }
  try {
    const payload = jwt.verify(auth.slice(7), process.env.JWT_SECRET);
    if (!payload.adminId) throw new Error('Not admin token');
    req.admin = payload;
    next();
  } catch {
    return res.status(401).json({ error: '인증이 만료되었습니다. 다시 로그인해주세요.' });
  }
}

// 이후 모든 라우트에 인증 적용
router.use(adminAuth);

// GET /admin/stats
router.get('/stats', async (req, res) => {
  try {
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    sevenDaysAgo.setHours(0, 0, 0, 0);

    const fourteenDaysAgo = new Date();
    fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14);
    fourteenDaysAgo.setHours(0, 0, 0, 0);

    const [totalUsers, totalCouples, totalMessages, totalFeeds, totalPhotos, totalLetters, totalFortunes, totalCalendarEvents, totalMoods] = await Promise.all([
      prisma.user.count(),
      prisma.couple.count(),
      prisma.message.count(),
      prisma.feed.count(),
      prisma.photo.count(),
      prisma.letter.count(),
      prisma.fortune.count(),
      prisma.calendarEvent.count(),
      prisma.mood.count(),
    ]);

    const [newUsersToday, newMessagesToday, newFeedsToday, moodsToday] = await Promise.all([
      prisma.user.count({ where: { createdAt: { gte: todayStart } } }),
      prisma.message.count({ where: { createdAt: { gte: todayStart } } }),
      prisma.feed.count({ where: { createdAt: { gte: todayStart } } }),
      prisma.mood.count({ where: { date: todayStart } }),
    ]);

    // DAU
    const [activeMessageUsers, activeFeedUsers] = await Promise.all([
      prisma.message.findMany({
        where: { createdAt: { gte: todayStart } },
        select: { senderId: true },
        distinct: ['senderId'],
      }),
      prisma.feed.findMany({
        where: { createdAt: { gte: todayStart } },
        select: { authorId: true },
        distinct: ['authorId'],
      }),
    ]);
    const dauIds = new Set([
      ...activeMessageUsers.map(m => m.senderId),
      ...activeFeedUsers.map(f => f.authorId),
    ]);

    // WAU
    const [wauMsg, wauFeed] = await Promise.all([
      prisma.message.findMany({
        where: { createdAt: { gte: sevenDaysAgo } },
        select: { senderId: true },
        distinct: ['senderId'],
      }),
      prisma.feed.findMany({
        where: { createdAt: { gte: sevenDaysAgo } },
        select: { authorId: true },
        distinct: ['authorId'],
      }),
    ]);
    const wauIds = new Set([...wauMsg.map(m => m.senderId), ...wauFeed.map(f => f.authorId)]);

    // 일별 차트 (14일)
    const [dailyMessagesRaw, dailyUsersRaw, dailyFeedsRaw] = await Promise.all([
      prisma.$queryRaw`
        SELECT DATE("createdAt") as date, COUNT(*)::int as count
        FROM "Message" WHERE "createdAt" >= ${fourteenDaysAgo}
        GROUP BY DATE("createdAt") ORDER BY date
      `,
      prisma.$queryRaw`
        SELECT DATE("createdAt") as date, COUNT(*)::int as count
        FROM "User" WHERE "createdAt" >= ${fourteenDaysAgo}
        GROUP BY DATE("createdAt") ORDER BY date
      `,
      prisma.$queryRaw`
        SELECT DATE("createdAt") as date, COUNT(*)::int as count
        FROM "Feed" WHERE "createdAt" >= ${fourteenDaysAgo}
        GROUP BY DATE("createdAt") ORDER BY date
      `,
    ]);

    const fmt = r => ({ date: r.date, count: Number(r.count) });

    // 다툼
    const [totalFights, resolvedFights] = await Promise.all([
      prisma.fight.count(),
      prisma.fight.count({ where: { isResolved: true } }),
    ]);

    // 최근 유저 10명
    const recentUsers = await prisma.user.findMany({
      take: 10,
      orderBy: { createdAt: 'desc' },
      select: { id: true, email: true, nickname: true, createdAt: true, coupleId: true },
    });

    res.json({
      overview: { totalUsers, totalCouples, totalMessages, totalFeeds, totalPhotos, totalLetters, totalFortunes, totalCalendarEvents, totalMoods },
      today: { newUsers: newUsersToday, newMessages: newMessagesToday, newFeeds: newFeedsToday, moods: moodsToday, activeUsers: dauIds.size },
      activity: { weeklyActiveUsers: wauIds.size, avgMessagesPerCouple: totalCouples > 0 ? Math.round(totalMessages / totalCouples) : 0 },
      charts: { dailyMessages: dailyMessagesRaw.map(fmt), dailyUsers: dailyUsersRaw.map(fmt), dailyFeeds: dailyFeedsRaw.map(fmt) },
      fights: { total: totalFights, resolved: resolvedFights, unresolved: totalFights - resolvedFights },
      recentUsers,
    });
  } catch (err) {
    console.error('Admin stats error:', err);
    res.status(500).json({ error: '통계 조회에 실패했습니다.' });
  }
});

// GET /admin/users
router.get('/users', async (req, res) => {
  try {
    const { page = '1', limit = '20', search = '' } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const take = Math.min(parseInt(limit), 100);

    const where = search.trim() ? {
      OR: [
        { email: { contains: search.trim(), mode: 'insensitive' } },
        { nickname: { contains: search.trim(), mode: 'insensitive' } },
      ],
    } : {};

    const [users, total] = await Promise.all([
      prisma.user.findMany({
        where, skip, take,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true, email: true, nickname: true, profileImage: true,
          birthDate: true, coupleId: true, createdAt: true,
          _count: { select: { sentMessages: true, feeds: true, photos: true, lettersWritten: true } },
        },
      }),
      prisma.user.count({ where }),
    ]);

    res.json({ users, total, page: parseInt(page), totalPages: Math.ceil(total / take) });
  } catch (err) {
    console.error('Admin users error:', err);
    res.status(500).json({ error: '유저 조회에 실패했습니다.' });
  }
});

// GET /admin/users/:id
router.get('/users/:id', async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.params.id },
      select: {
        id: true, email: true, nickname: true, profileImage: true,
        birthDate: true, zodiacSign: true, chineseZodiac: true,
        fcmToken: true, coupleId: true, createdAt: true, updatedAt: true,
        couple: {
          select: {
            id: true, startDate: true, inviteCode: true,
            users: { select: { id: true, nickname: true, email: true } },
          },
        },
        _count: {
          select: {
            sentMessages: true, feeds: true, photos: true,
            lettersWritten: true, lettersReceived: true,
            moods: true, calendarEvents: true, fights: true,
            feedLikes: true, feedComments: true,
          },
        },
      },
    });
    if (!user) return res.status(404).json({ error: '유저를 찾을 수 없습니다.' });
    res.json({ user });
  } catch (err) {
    console.error('Admin user detail error:', err);
    res.status(500).json({ error: '유저 조회에 실패했습니다.' });
  }
});

// DELETE /admin/users/:id
router.delete('/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const user = await prisma.user.findUnique({
      where: { id },
      select: { id: true, coupleId: true, nickname: true },
    });
    if (!user) return res.status(404).json({ error: '유저를 찾을 수 없습니다.' });

    if (user.coupleId) {
      await prisma.user.update({ where: { id }, data: { coupleId: null } });
    }

    await prisma.$transaction([
      prisma.feedLike.deleteMany({ where: { userId: id } }),
      prisma.feedComment.deleteMany({ where: { authorId: id } }),
      prisma.mood.deleteMany({ where: { userId: id } }),
      prisma.letter.deleteMany({ where: { OR: [{ writerId: id }, { receiverId: id }] } }),
      prisma.fight.deleteMany({ where: { authorId: id } }),
      prisma.photo.deleteMany({ where: { authorId: id } }),
      prisma.feed.deleteMany({ where: { authorId: id } }),
      prisma.message.deleteMany({ where: { senderId: id } }),
      prisma.calendarEvent.deleteMany({ where: { authorId: id } }),
      prisma.user.delete({ where: { id } }),
    ]);

    res.json({ message: `${user.nickname} 유저가 삭제되었습니다.` });
  } catch (err) {
    console.error('Admin delete user error:', err);
    res.status(500).json({ error: '유저 삭제에 실패했습니다.' });
  }
});

// GET /admin/couples
router.get('/couples', async (req, res) => {
  try {
    const { page = '1', limit = '20' } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const take = Math.min(parseInt(limit), 100);

    const [couples, total] = await Promise.all([
      prisma.couple.findMany({
        skip, take,
        orderBy: { createdAt: 'desc' },
        include: {
          users: { select: { id: true, nickname: true, email: true } },
          _count: {
            select: { messages: true, feeds: true, photos: true, letters: true, calendarEvents: true, moods: true, fights: true, fortunes: true },
          },
        },
      }),
      prisma.couple.count(),
    ]);

    res.json({ couples, total, page: parseInt(page), totalPages: Math.ceil(total / take) });
  } catch (err) {
    console.error('Admin couples error:', err);
    res.status(500).json({ error: '커플 조회에 실패했습니다.' });
  }
});

// GET /admin/couples/:id
router.get('/couples/:id', async (req, res) => {
  try {
    const couple = await prisma.couple.findUnique({
      where: { id: req.params.id },
      include: {
        users: { select: { id: true, email: true, nickname: true, profileImage: true, birthDate: true, createdAt: true } },
        _count: { select: { messages: true, feeds: true, photos: true, letters: true, calendarEvents: true, moods: true, fights: true, fortunes: true } },
      },
    });
    if (!couple) return res.status(404).json({ error: '커플을 찾을 수 없습니다.' });

    const lastMessage = await prisma.message.findFirst({
      where: { coupleId: couple.id },
      orderBy: { createdAt: 'desc' },
      select: { createdAt: true },
    });

    const diffDays = Math.floor((new Date() - new Date(couple.startDate)) / (1000 * 60 * 60 * 24)) + 1;

    res.json({ couple, daysTogether: diffDays, lastActivity: lastMessage?.createdAt || null });
  } catch (err) {
    console.error('Admin couple detail error:', err);
    res.status(500).json({ error: '커플 조회에 실패했습니다.' });
  }
});

// GET /admin/couples/:id/messages
router.get('/couples/:id/messages', async (req, res) => {
  try {
    const { page = '1', limit = '30' } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const take = Math.min(parseInt(limit), 100);

    const [messages, total] = await Promise.all([
      prisma.message.findMany({
        where: { coupleId: req.params.id },
        skip, take,
        orderBy: { createdAt: 'desc' },
        include: {
          sender: { select: { id: true, nickname: true, profileImage: true } },
        },
      }),
      prisma.message.count({ where: { coupleId: req.params.id } }),
    ]);

    res.json({ messages, total, page: parseInt(page), totalPages: Math.ceil(total / take) });
  } catch (err) {
    console.error('Admin couple messages error:', err);
    res.status(500).json({ error: '메시지 조회에 실패했습니다.' });
  }
});

// GET /admin/couples/:id/feeds
router.get('/couples/:id/feeds', async (req, res) => {
  try {
    const { page = '1', limit = '20' } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const take = Math.min(parseInt(limit), 100);

    const [feeds, total] = await Promise.all([
      prisma.feed.findMany({
        where: { coupleId: req.params.id },
        skip, take,
        orderBy: { createdAt: 'desc' },
        include: {
          author: { select: { id: true, nickname: true, profileImage: true } },
          _count: { select: { likes: true, comments: true } },
        },
      }),
      prisma.feed.count({ where: { coupleId: req.params.id } }),
    ]);

    res.json({ feeds, total, page: parseInt(page), totalPages: Math.ceil(total / take) });
  } catch (err) {
    console.error('Admin couple feeds error:', err);
    res.status(500).json({ error: '피드 조회에 실패했습니다.' });
  }
});

// GET /admin/couples/:id/letters
router.get('/couples/:id/letters', async (req, res) => {
  try {
    const { page = '1', limit = '20' } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const take = Math.min(parseInt(limit), 100);

    const [letters, total] = await Promise.all([
      prisma.letter.findMany({
        where: { coupleId: req.params.id },
        skip, take,
        orderBy: { createdAt: 'desc' },
        include: {
          writer: { select: { id: true, nickname: true, profileImage: true } },
          receiver: { select: { id: true, nickname: true } },
        },
      }),
      prisma.letter.count({ where: { coupleId: req.params.id } }),
    ]);

    res.json({ letters, total, page: parseInt(page), totalPages: Math.ceil(total / take) });
  } catch (err) {
    console.error('Admin couple letters error:', err);
    res.status(500).json({ error: '편지 조회에 실패했습니다.' });
  }
});

// GET /admin/couples/:id/photos
router.get('/couples/:id/photos', async (req, res) => {
  try {
    const { page = '1', limit = '20' } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const take = Math.min(parseInt(limit), 100);

    const [photos, total] = await Promise.all([
      prisma.photo.findMany({
        where: { coupleId: req.params.id },
        skip, take,
        orderBy: { createdAt: 'desc' },
        include: {
          author: { select: { id: true, nickname: true, profileImage: true } },
        },
      }),
      prisma.photo.count({ where: { coupleId: req.params.id } }),
    ]);

    res.json({ photos, total, page: parseInt(page), totalPages: Math.ceil(total / take) });
  } catch (err) {
    console.error('Admin couple photos error:', err);
    res.status(500).json({ error: '사진 조회에 실패했습니다.' });
  }
});

// GET /admin/fights
router.get('/fights', async (req, res) => {
  try {
    const { page = '1', limit = '20', status = '' } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const take = Math.min(parseInt(limit), 100);

    const where = status === 'resolved' ? { isResolved: true }
      : status === 'unresolved' ? { isResolved: false }
      : {};

    const [fights, total] = await Promise.all([
      prisma.fight.findMany({
        where, skip, take,
        orderBy: { createdAt: 'desc' },
        include: {
          author: { select: { id: true, nickname: true, profileImage: true } },
          couple: {
            select: {
              id: true,
              users: { select: { id: true, nickname: true } },
            },
          },
        },
      }),
      prisma.fight.count({ where }),
    ]);

    res.json({ fights, total, page: parseInt(page), totalPages: Math.ceil(total / take) });
  } catch (err) {
    console.error('Admin fights error:', err);
    res.status(500).json({ error: '다툼 조회에 실패했습니다.' });
  }
});

// GET /admin/fights/:id
router.get('/fights/:id', async (req, res) => {
  try {
    const fight = await prisma.fight.findUnique({
      where: { id: req.params.id },
      include: {
        author: { select: { id: true, nickname: true, profileImage: true, email: true } },
        couple: {
          select: {
            id: true, startDate: true,
            users: { select: { id: true, nickname: true, email: true, profileImage: true } },
          },
        },
      },
    });
    if (!fight) return res.status(404).json({ error: '다툼 기록을 찾을 수 없습니다.' });
    res.json({ fight });
  } catch (err) {
    console.error('Admin fight detail error:', err);
    res.status(500).json({ error: '다툼 조회에 실패했습니다.' });
  }
});

// DELETE /admin/couples/:id
router.delete('/couples/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const couple = await prisma.couple.findUnique({
      where: { id },
      include: { users: { select: { id: true, nickname: true } } },
    });
    if (!couple) return res.status(404).json({ error: '커플을 찾을 수 없습니다.' });

    const names = couple.users.map(u => u.nickname).join(', ');

    await prisma.$transaction([
      prisma.user.updateMany({ where: { coupleId: id }, data: { coupleId: null } }),
      prisma.feedLike.deleteMany({ where: { feed: { coupleId: id } } }),
      prisma.feedComment.deleteMany({ where: { feed: { coupleId: id } } }),
      prisma.feed.deleteMany({ where: { coupleId: id } }),
      prisma.message.deleteMany({ where: { coupleId: id } }),
      prisma.calendarEvent.deleteMany({ where: { coupleId: id } }),
      prisma.mood.deleteMany({ where: { coupleId: id } }),
      prisma.photo.deleteMany({ where: { coupleId: id } }),
      prisma.letter.deleteMany({ where: { coupleId: id } }),
      prisma.fight.deleteMany({ where: { coupleId: id } }),
      prisma.fortune.deleteMany({ where: { coupleId: id } }),
      prisma.couple.delete({ where: { id } }),
    ]);

    res.json({ message: `커플(${names})이 삭제되었습니다.` });
  } catch (err) {
    console.error('Admin delete couple error:', err);
    res.status(500).json({ error: '커플 삭제에 실패했습니다.' });
  }
});

// GET /admin/inquiries
router.get('/inquiries', async (req, res) => {
  try {
    const { page = '1', limit = '20', status = '' } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const take = Math.min(parseInt(limit), 100);

    const where = status ? { status } : {};

    const [inquiries, total] = await Promise.all([
      prisma.inquiry.findMany({
        where, skip, take,
        orderBy: { createdAt: 'desc' },
        include: {
          user: { select: { id: true, nickname: true, email: true, profileImage: true } },
        },
      }),
      prisma.inquiry.count({ where }),
    ]);

    res.json({ inquiries, total, page: parseInt(page), totalPages: Math.ceil(total / take) });
  } catch (err) {
    console.error('Admin inquiries error:', err);
    res.status(500).json({ error: '문의 조회에 실패했습니다.' });
  }
});

// GET /admin/inquiries/:id
router.get('/inquiries/:id', async (req, res) => {
  try {
    const inquiry = await prisma.inquiry.findUnique({
      where: { id: req.params.id },
      include: {
        user: {
          select: {
            id: true, nickname: true, email: true, profileImage: true,
            coupleId: true, createdAt: true,
            _count: { select: { sentMessages: true, feeds: true, photos: true } },
          },
        },
      },
    });
    if (!inquiry) return res.status(404).json({ error: '문의를 찾을 수 없습니다.' });
    res.json({ inquiry });
  } catch (err) {
    console.error('Admin inquiry detail error:', err);
    res.status(500).json({ error: '문의 조회에 실패했습니다.' });
  }
});

// PATCH /admin/inquiries/:id - 상태 변경 + 답변 + 푸시
router.patch('/inquiries/:id', async (req, res) => {
  try {
    const { status, adminReply } = req.body;
    const inquiry = await prisma.inquiry.findUnique({
      where: { id: req.params.id },
      include: { user: { select: { id: true, nickname: true, fcmToken: true } } },
    });
    if (!inquiry) return res.status(404).json({ error: '문의를 찾을 수 없습니다.' });

    const data = {};
    if (status) data.status = status;
    if (adminReply !== undefined) {
      data.adminReply = adminReply;
      data.repliedAt = new Date();
      data.isReplyRead = false;
    }

    const updated = await prisma.inquiry.update({
      where: { id: req.params.id },
      data,
      include: {
        user: { select: { id: true, nickname: true, email: true } },
      },
    });

    // 알림 DB 저장 + 푸시 알림 전송
    let pushResult = { sent: false, reason: '' };

    if (adminReply) {
      const nTitle = '문의 답변 도착';
      const nBody = `"${inquiry.title}" 문의에 답변이 등록되었습니다.`;
      const nData = { type: 'inquiry', inquiryId: inquiry.id };

      // Notification DB 저장
      await prisma.notification.create({
        data: { userId: inquiry.user.id, type: 'inquiry', title: nTitle, body: nBody, data: nData },
      });

      if (!inquiry.user.fcmToken) {
        pushResult = { sent: false, reason: '유저에게 FCM 토큰이 없습니다 (푸시 알림 미허용 또는 미등록)' };
      } else {
        try {
          await sendPushNotification({ token: inquiry.user.fcmToken, title: nTitle, body: nBody, data: nData });
          pushResult = { sent: true, reason: `전송 성공 (토큰: ${inquiry.user.fcmToken.substring(0, 20)}...)` };
        } catch (pushErr) {
          pushResult = { sent: false, reason: `전송 실패: ${pushErr.message}` };
        }
      }
    } else if (status) {
      const statusLabels = {
        PENDING: '접수됨',
        IN_PROGRESS: '처리 중',
        RESOLVED: '답변 완료',
        CLOSED: '종료',
      };
      const nTitle = '문의 상태 변경';
      const nBody = `"${inquiry.title}" 문의가 ${statusLabels[status] || status} 상태로 변경되었습니다.`;
      const nData = { type: 'inquiry', inquiryId: inquiry.id };

      // Notification DB 저장
      await prisma.notification.create({
        data: { userId: inquiry.user.id, type: 'inquiry', title: nTitle, body: nBody, data: nData },
      });

      if (!inquiry.user.fcmToken) {
        pushResult = { sent: false, reason: '유저에게 FCM 토큰이 없습니다' };
      } else {
        try {
          await sendPushNotification({ token: inquiry.user.fcmToken, title: nTitle, body: nBody, data: nData });
          pushResult = { sent: true, reason: `전송 성공 (토큰: ${inquiry.user.fcmToken.substring(0, 20)}...)` };
        } catch (pushErr) {
          pushResult = { sent: false, reason: `전송 실패: ${pushErr.message}` };
        }
      }
    }

    res.json({ inquiry: updated, pushResult });
  } catch (err) {
    console.error('Admin update inquiry error:', err);
    res.status(500).json({ error: '문의 처리에 실패했습니다.' });
  }
});

// ===== PUSH NOTIFICATION =====

// POST /admin/push/send - 개별 유저 푸시 발송
router.post('/push/send', async (req, res) => {
  try {
    const { userId, title, body } = req.body;
    if (!title || !body) {
      return res.status(400).json({ error: '제목과 내용을 입력해주세요.' });
    }

    let users;
    if (userId) {
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { id: true, nickname: true, fcmToken: true },
      });
      if (!user) return res.status(404).json({ error: '유저를 찾을 수 없습니다.' });
      users = [user];
    } else {
      // 전체 발송
      users = await prisma.user.findMany({
        where: { fcmToken: { not: null } },
        select: { id: true, nickname: true, fcmToken: true },
      });
    }

    const results = [];
    for (const user of users) {
      if (!user.fcmToken) {
        results.push({ nickname: user.nickname, success: false, reason: '토큰 없음' });
        continue;
      }
      try {
        await sendPushNotification({
          token: user.fcmToken,
          title,
          body,
          data: { type: 'notice' },
        });
        results.push({ nickname: user.nickname, success: true, reason: '전송 성공' });
      } catch (err) {
        results.push({ nickname: user.nickname, success: false, reason: err.message });
      }
    }

    const successCount = results.filter(r => r.success).length;
    res.json({ total: results.length, success: successCount, failed: results.length - successCount, results });
  } catch (err) {
    console.error('Admin push send error:', err);
    res.status(500).json({ error: '푸시 발송에 실패했습니다.' });
  }
});

// GET /admin/push/tokens - FCM 토큰 보유 유저 목록
router.get('/push/tokens', async (req, res) => {
  try {
    const users = await prisma.user.findMany({
      select: { id: true, nickname: true, email: true, fcmToken: true },
      orderBy: { createdAt: 'desc' },
    });
    res.json({ users });
  } catch (err) {
    console.error('Admin push tokens error:', err);
    res.status(500).json({ error: '조회에 실패했습니다.' });
  }
});

// ===== APP SETTINGS =====

// GET /admin/settings - 전체 설정 목록
router.get('/settings', async (req, res) => {
  try {
    const settings = await prisma.appSettings.findMany({
      orderBy: { key: 'asc' },
    });
    res.json({ settings });
  } catch (err) {
    console.error('Admin settings list error:', err);
    res.status(500).json({ error: '설정 조회에 실패했습니다.' });
  }
});

// PUT /admin/settings/:key - 설정 생성/수정 (upsert)
router.put('/settings/:key', async (req, res) => {
  try {
    const { value } = req.body;
    if (value === undefined) {
      return res.status(400).json({ error: '값을 입력해주세요.' });
    }

    const setting = await prisma.appSettings.upsert({
      where: { key: req.params.key },
      update: { value },
      create: { key: req.params.key, value },
    });

    res.json({ setting });
  } catch (err) {
    console.error('Admin settings update error:', err);
    res.status(500).json({ error: '설정 저장에 실패했습니다.' });
  }
});

export default router;

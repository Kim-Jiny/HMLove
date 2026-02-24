import { Router } from 'express';
import prisma from '../utils/prisma.js';

const router = Router();

// Admin 인증 미들웨어
function adminAuth(req, res, next) {
  const key = req.headers['x-admin-key'] || req.query.key;
  if (!key || key !== process.env.ADMIN_PASSWORD) {
    return res.status(401).json({ error: '관리자 인증이 필요합니다.' });
  }
  next();
}

router.use(adminAuth);

// GET /admin/stats - 전체 통계
router.get('/stats', async (req, res) => {
  try {
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const fourteenDaysAgo = new Date();
    fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14);
    fourteenDaysAgo.setHours(0, 0, 0, 0);

    // 전체 카운트
    const [totalUsers, totalCouples, totalMessages, totalFeeds, totalPhotos, totalLetters, totalFortunes] = await Promise.all([
      prisma.user.count(),
      prisma.couple.count(),
      prisma.message.count(),
      prisma.feed.count(),
      prisma.photo.count(),
      prisma.letter.count(),
      prisma.fortune.count(),
    ]);

    // 오늘 카운트
    const [newUsersToday, newMessagesToday, newFeedsToday, moodsToday] = await Promise.all([
      prisma.user.count({ where: { createdAt: { gte: todayStart } } }),
      prisma.message.count({ where: { createdAt: { gte: todayStart } } }),
      prisma.feed.count({ where: { createdAt: { gte: todayStart } } }),
      prisma.mood.count({ where: { date: todayStart } }),
    ]);

    // 일별 메시지 (14일)
    const dailyMessagesRaw = await prisma.$queryRaw`
      SELECT DATE("createdAt") as date, COUNT(*)::int as count
      FROM "Message"
      WHERE "createdAt" >= ${fourteenDaysAgo}
      GROUP BY DATE("createdAt")
      ORDER BY date
    `;
    const dailyMessages = dailyMessagesRaw.map(r => ({
      date: r.date,
      count: Number(r.count),
    }));

    // 일별 신규 유저 (14일)
    const dailyUsersRaw = await prisma.$queryRaw`
      SELECT DATE("createdAt") as date, COUNT(*)::int as count
      FROM "User"
      WHERE "createdAt" >= ${fourteenDaysAgo}
      GROUP BY DATE("createdAt")
      ORDER BY date
    `;
    const dailyUsers = dailyUsersRaw.map(r => ({
      date: r.date,
      count: Number(r.count),
    }));

    // 다툼 통계
    const [totalFights, resolvedFights] = await Promise.all([
      prisma.fight.count(),
      prisma.fight.count({ where: { isResolved: true } }),
    ]);

    // 최근 유저
    const recentUsers = await prisma.user.findMany({
      take: 20,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        email: true,
        nickname: true,
        createdAt: true,
        coupleId: true,
        profileImage: true,
      },
    });

    // 커플 목록 (통계 포함)
    const couples = await prisma.couple.findMany({
      take: 20,
      orderBy: { createdAt: 'desc' },
      include: {
        users: { select: { id: true, nickname: true, email: true } },
        _count: {
          select: {
            messages: true,
            feeds: true,
            photos: true,
            letters: true,
          },
        },
      },
    });

    res.json({
      overview: {
        totalUsers,
        totalCouples,
        totalMessages,
        totalFeeds,
        totalPhotos,
        totalLetters,
        totalFortunes,
      },
      today: {
        newUsers: newUsersToday,
        newMessages: newMessagesToday,
        newFeeds: newFeedsToday,
        moods: moodsToday,
      },
      charts: {
        dailyMessages,
        dailyUsers,
      },
      fights: {
        total: totalFights,
        resolved: resolvedFights,
        unresolved: totalFights - resolvedFights,
      },
      recentUsers,
      couples,
    });
  } catch (err) {
    console.error('Admin stats error:', err);
    res.status(500).json({ error: '통계 조회에 실패했습니다.' });
  }
});

export default router;

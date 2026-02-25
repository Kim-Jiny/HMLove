import { Router } from 'express';
import { authenticate, requireCouple } from '../middleware/auth.js';
import prisma from '../utils/prisma.js';
import { notifyPartner } from '../utils/firebase.js';

const router = Router();
router.use(authenticate, requireCouple);

// GET /mood/today?date=2026-02-25
router.get('/today', async (req, res) => {
  try {
    const dateStr = req.query.date;
    const today = dateStr
      ? new Date(dateStr + 'T00:00:00.000Z')
      : new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), new Date().getUTCDate()));

    const moods = await prisma.mood.findMany({
      where: {
        coupleId: req.user.coupleId,
        date: today,
      },
      include: {
        user: { select: { id: true, nickname: true, profileImage: true } },
      },
    });

    res.json({ moods });
  } catch (err) {
    console.error('Get today mood error:', err);
    res.status(500).json({ error: '오늘의 기분 조회에 실패했습니다.' });
  }
});

// POST /mood
router.post('/', async (req, res) => {
  try {
    const { emoji, message, date: dateStr } = req.body;

    if (!emoji) {
      return res.status(400).json({ error: '이모지를 선택해주세요.' });
    }

    const today = dateStr
      ? new Date(dateStr + 'T00:00:00.000Z')
      : new Date(Date.UTC(new Date().getUTCFullYear(), new Date().getUTCMonth(), new Date().getUTCDate()));

    const mood = await prisma.mood.upsert({
      where: {
        userId_date: {
          userId: req.user.id,
          date: today,
        },
      },
      update: { emoji, message },
      create: {
        userId: req.user.id,
        coupleId: req.user.coupleId,
        emoji,
        message,
        date: today,
      },
      include: {
        user: { select: { id: true, nickname: true, profileImage: true } },
      },
    });

    // 상대방에게 푸시 알림
    notifyPartner({
      userId: req.user.id,
      coupleId: req.user.coupleId,
      title: req.user.nickname || '상대방',
      body: `오늘의 기분: ${emoji}`,
      data: { type: 'mood' },
    });

    res.json({ mood });
  } catch (err) {
    console.error('Upsert mood error:', err);
    res.status(500).json({ error: '기분 등록에 실패했습니다.' });
  }
});

export default router;

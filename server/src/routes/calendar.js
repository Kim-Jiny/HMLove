import { Router } from 'express';
import { authenticate, requireCouple } from '../middleware/auth.js';
import prisma from '../utils/prisma.js';
import { notifyPartner } from '../utils/firebase.js';
import { getAutoAnniversariesForMonth } from '../utils/anniversary.js';

const router = Router();
router.use(authenticate, requireCouple);

// GET /calendar/:yearMonth (e.g. 2026-02)
router.get('/:yearMonth', async (req, res) => {
  try {
    const { yearMonth } = req.params;
    const [year, month] = yearMonth.split('-').map(Number);

    if (!year || !month || month < 1 || month > 12) {
      return res.status(400).json({ error: '올바른 날짜 형식이 아닙니다. (예: 2026-02)' });
    }

    const startOfMonth = new Date(Date.UTC(year, month - 1, 1));
    const endOfMonth = new Date(Date.UTC(year, month, 0, 23, 59, 59, 999));

    // DB 이벤트 조회
    const dbEvents = await prisma.calendarEvent.findMany({
      where: {
        coupleId: req.user.coupleId,
        OR: [
          // 해당 월 이벤트
          { date: { gte: startOfMonth, lte: endOfMonth }, repeatType: 'NONE' },
          // 매년 반복: 같은 월인 것
          { repeatType: 'YEARLY' },
          // 매월 반복: 전부
          { repeatType: 'MONTHLY' },
        ],
      },
      include: {
        author: { select: { id: true, nickname: true } },
      },
      orderBy: { date: 'asc' },
    });

    // 반복 이벤트 처리: 해당 월에 맞게 날짜 조정 + eventType 구분
    const events = [];
    for (const ev of dbEvents) {
      const eventType = ev.isAnniversary ? 'anniversary' : 'schedule';
      if (ev.repeatType === 'YEARLY') {
        if (ev.date.getUTCMonth() === month - 1) {
          events.push({ ...ev, eventType, date: new Date(Date.UTC(year, month - 1, ev.date.getUTCDate())) });
        }
      } else if (ev.repeatType === 'MONTHLY') {
        events.push({ ...ev, eventType, date: new Date(Date.UTC(year, month - 1, ev.date.getUTCDate())) });
      } else {
        events.push({ ...ev, eventType });
      }
    }

    // 자동 기념일 생성 (100일, N주년, 생일)
    const couple = await prisma.couple.findUnique({
      where: { id: req.user.coupleId },
      include: {
        users: { select: { nickname: true, birthDate: true } },
      },
    });

    const autoEvents = couple ? getAutoAnniversariesForMonth(couple, year, month) : [];

    // 피드 조회 (해당 월)
    const feeds = await prisma.feed.findMany({
      where: {
        coupleId: req.user.coupleId,
        createdAt: { gte: startOfMonth, lte: endOfMonth },
      },
      select: { id: true, content: true, imageUrls: true, createdAt: true, authorId: true },
      orderBy: { createdAt: 'asc' },
    });

    const feedEvents = feeds.map(f => ({
      id: `feed-${f.id}`,
      title: f.imageUrls?.length > 0 ? '사진 피드' : (f.content.length > 20 ? f.content.substring(0, 20) + '...' : f.content),
      date: f.createdAt,
      isAnniversary: false,
      repeatType: 'NONE',
      description: null,
      color: null,
      eventType: 'feed',
      _auto: false,
    }));

    // 무드 조회 (해당 월, 커플 전원)
    const moods = await prisma.mood.findMany({
      where: {
        coupleId: req.user.coupleId,
        date: { gte: startOfMonth, lte: endOfMonth },
      },
      select: { emoji: true, date: true, userId: true, user: { select: { nickname: true } } },
      orderBy: { date: 'asc' },
    });

    // 날짜별 무드 맵: { "2026-02-14": [{ emoji: "😊", nickname: "현규" }] }
    const moodMap = {};
    for (const m of moods) {
      const d = m.date;
      const key = `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`;
      if (!moodMap[key]) moodMap[key] = [];
      moodMap[key].push({ emoji: m.emoji, nickname: m.user.nickname });
    }

    const allEvents = [...events, ...autoEvents, ...feedEvents].sort((a, b) => a.date - b.date);

    res.json({ events: allEvents, moods: moodMap });
  } catch (err) {
    console.error('Get calendar events error:', err);
    res.status(500).json({ error: '일정 조회에 실패했습니다.' });
  }
});

// POST /calendar
router.post('/', async (req, res) => {
  try {
    const { title, description, date, isAnniversary, repeatType, color } = req.body;

    if (!title || !date) {
      return res.status(400).json({ error: '제목과 날짜를 입력해주세요.' });
    }

    const event = await prisma.calendarEvent.create({
      data: {
        coupleId: req.user.coupleId,
        authorId: req.user.id,
        title,
        description,
        date: new Date(date + 'T00:00:00.000Z'),
        isAnniversary: isAnniversary || false,
        repeatType: repeatType || 'NONE',
        color,
      },
      include: {
        author: { select: { id: true, nickname: true } },
      },
    });

    // 상대방에게 푸시 알림
    notifyPartner({
      userId: req.user.id,
      coupleId: req.user.coupleId,
      title: req.user.nickname || '상대방',
      body: `새 일정: ${title}`,
      data: { type: 'calendar' },
    });

    const eventType = event.isAnniversary ? 'anniversary' : 'schedule';
    res.status(201).json({ event: { ...event, eventType } });
  } catch (err) {
    console.error('Create calendar event error:', err);
    res.status(500).json({ error: '일정 생성에 실패했습니다.' });
  }
});

// PUT /calendar/:id
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { title, description, date, isAnniversary, repeatType, color } = req.body;

    const existing = await prisma.calendarEvent.findUnique({ where: { id } });
    if (!existing || existing.coupleId !== req.user.coupleId) {
      return res.status(404).json({ error: '일정을 찾을 수 없습니다.' });
    }

    const event = await prisma.calendarEvent.update({
      where: { id },
      data: {
        ...(title !== undefined && { title }),
        ...(description !== undefined && { description }),
        ...(date !== undefined && { date: new Date(date + 'T00:00:00.000Z') }),
        ...(isAnniversary !== undefined && { isAnniversary }),
        ...(repeatType !== undefined && { repeatType }),
        ...(color !== undefined && { color }),
      },
      include: {
        author: { select: { id: true, nickname: true } },
      },
    });

    const eventType = event.isAnniversary ? 'anniversary' : 'schedule';
    res.json({ event: { ...event, eventType } });
  } catch (err) {
    console.error('Update calendar event error:', err);
    res.status(500).json({ error: '일정 수정에 실패했습니다.' });
  }
});

// DELETE /calendar/:id
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const existing = await prisma.calendarEvent.findUnique({ where: { id } });
    if (!existing || existing.coupleId !== req.user.coupleId) {
      return res.status(404).json({ error: '일정을 찾을 수 없습니다.' });
    }

    await prisma.calendarEvent.delete({ where: { id } });
    res.json({ message: '일정이 삭제되었습니다.' });
  } catch (err) {
    console.error('Delete calendar event error:', err);
    res.status(500).json({ error: '일정 삭제에 실패했습니다.' });
  }
});

export default router;

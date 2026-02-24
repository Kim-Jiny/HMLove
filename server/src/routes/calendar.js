import { Router } from 'express';
import { authenticate, requireCouple } from '../middleware/auth.js';
import prisma from '../utils/prisma.js';
import { notifyPartner } from '../utils/firebase.js';

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

    const startOfMonth = new Date(year, month - 1, 1);
    const endOfMonth = new Date(year, month, 0, 23, 59, 59, 999);

    const events = await prisma.calendarEvent.findMany({
      where: {
        coupleId: req.user.coupleId,
        date: { gte: startOfMonth, lte: endOfMonth },
      },
      include: {
        author: { select: { id: true, nickname: true } },
      },
      orderBy: { date: 'asc' },
    });

    res.json({ events });
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
        date: new Date(date),
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

    res.status(201).json({ event });
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
        ...(date !== undefined && { date: new Date(date) }),
        ...(isAnniversary !== undefined && { isAnniversary }),
        ...(repeatType !== undefined && { repeatType }),
        ...(color !== undefined && { color }),
      },
      include: {
        author: { select: { id: true, nickname: true } },
      },
    });

    res.json({ event });
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

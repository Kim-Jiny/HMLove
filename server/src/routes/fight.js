import { Router } from 'express';
import { authenticate, requireCouple } from '../middleware/auth.js';
import prisma from '../utils/prisma.js';
import { notifyPartner } from '../utils/firebase.js';

const router = Router();
router.use(authenticate, requireCouple);

// GET /fight?isResolved=true
router.get('/', async (req, res) => {
  try {
    const { isResolved } = req.query;

    const where = { coupleId: req.user.coupleId };
    if (isResolved !== undefined) {
      where.isResolved = isResolved === 'true';
    }

    const fights = await prisma.fight.findMany({
      where,
      orderBy: { date: 'desc' },
      include: {
        author: { select: { id: true, nickname: true } },
      },
    });

    res.json({ fights });
  } catch (err) {
    console.error('Get fights error:', err);
    res.status(500).json({ error: '다툼 기록 조회에 실패했습니다.' });
  }
});

// POST /fight
router.post('/', async (req, res) => {
  try {
    const { date, reason, resolution, reflection } = req.body;

    if (!reason) {
      return res.status(400).json({ error: '다툼 사유를 입력해주세요.' });
    }

    const fight = await prisma.fight.create({
      data: {
        coupleId: req.user.coupleId,
        authorId: req.user.id,
        date: date ? new Date(date) : new Date(),
        reason,
        resolution,
        reflection,
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
      body: '다툼 기록을 남겼어요',
      data: { type: 'fight', fightId: fight.id },
    });

    res.status(201).json({ fight });
  } catch (err) {
    console.error('Create fight error:', err);
    res.status(500).json({ error: '다툼 기록 생성에 실패했습니다.' });
  }
});

// PUT /fight/:id
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { reason, resolution, reflection, date, isResolved } = req.body;

    const existing = await prisma.fight.findUnique({ where: { id } });
    if (!existing || existing.coupleId !== req.user.coupleId) {
      return res.status(404).json({ error: '다툼 기록을 찾을 수 없습니다.' });
    }

    const fight = await prisma.fight.update({
      where: { id },
      data: {
        ...(reason !== undefined && { reason }),
        ...(resolution !== undefined && { resolution }),
        ...(reflection !== undefined && { reflection }),
        ...(date !== undefined && { date: new Date(date) }),
        ...(isResolved !== undefined && { isResolved }),
      },
      include: {
        author: { select: { id: true, nickname: true } },
      },
    });

    res.json({ fight });
  } catch (err) {
    console.error('Update fight error:', err);
    res.status(500).json({ error: '다툼 기록 수정에 실패했습니다.' });
  }
});

// PATCH /fight/:id/resolve
router.patch('/:id/resolve', async (req, res) => {
  try {
    const { id } = req.params;

    const existing = await prisma.fight.findUnique({ where: { id } });
    if (!existing || existing.coupleId !== req.user.coupleId) {
      return res.status(404).json({ error: '다툼 기록을 찾을 수 없습니다.' });
    }

    const fight = await prisma.fight.update({
      where: { id },
      data: { isResolved: true },
      include: {
        author: { select: { id: true, nickname: true } },
      },
    });

    // 상대방에게 푸시 알림
    notifyPartner({
      userId: req.user.id,
      coupleId: req.user.coupleId,
      title: req.user.nickname || '상대방',
      body: '다툼이 해결되었어요 🤝',
      data: { type: 'fight', fightId: fight.id },
    });

    res.json({ fight });
  } catch (err) {
    console.error('Resolve fight error:', err);
    res.status(500).json({ error: '다툼 해결 처리에 실패했습니다.' });
  }
});

export default router;

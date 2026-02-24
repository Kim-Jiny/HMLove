import { Router } from 'express';
import { authenticate, requireCouple } from '../middleware/auth.js';
import prisma from '../utils/prisma.js';

const router = Router();
router.use(authenticate, requireCouple);

// GET /chat/unread-count
router.get('/unread-count', async (req, res) => {
  try {
    const count = await prisma.message.count({
      where: {
        coupleId: req.user.coupleId,
        senderId: { not: req.user.id },
        isRead: false,
      },
    });
    res.json({ count });
  } catch (err) {
    console.error('Unread count error:', err);
    res.json({ count: 0 });
  }
});

// GET /chat/messages?cursor=xxx&limit=30
router.get('/messages', async (req, res) => {
  try {
    const { cursor, limit = '30' } = req.query;
    const take = Math.min(parseInt(limit), 100);

    const messages = await prisma.message.findMany({
      where: { coupleId: req.user.coupleId },
      take: take + 1,
      ...(cursor && { cursor: { id: cursor }, skip: 1 }),
      orderBy: { createdAt: 'desc' },
      include: {
        sender: { select: { id: true, nickname: true, profileImage: true } },
      },
    });

    const hasNext = messages.length > take;
    if (hasNext) messages.pop();

    const nextCursor = hasNext ? messages[messages.length - 1].id : null;

    res.json({ messages, nextCursor });
  } catch (err) {
    console.error('Get messages error:', err);
    res.status(500).json({ error: '메시지 조회에 실패했습니다.' });
  }
});

// PATCH /chat/read
router.patch('/read', async (req, res) => {
  try {
    const result = await prisma.message.updateMany({
      where: {
        coupleId: req.user.coupleId,
        senderId: { not: req.user.id },
        isRead: false,
      },
      data: { isRead: true },
    });

    res.json({ readCount: result.count });
  } catch (err) {
    console.error('Read messages error:', err);
    res.status(500).json({ error: '읽음 처리에 실패했습니다.' });
  }
});

export default router;

import { Router } from 'express';
import prisma from '../utils/prisma.js';
import { authenticate } from '../middleware/auth.js';

const router = Router();
router.use(authenticate);

// 알림 목록 조회 (최신순, 페이지네이션)
router.get('/', async (req, res) => {
  try {
    const { cursor, limit = '20' } = req.query;
    const take = Math.min(parseInt(limit) || 20, 50);

    const notifications = await prisma.notification.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' },
      take: take + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });

    const hasMore = notifications.length > take;
    if (hasMore) notifications.pop();

    res.json({
      notifications,
      hasMore,
      nextCursor: hasMore ? notifications[notifications.length - 1].id : null,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// 읽지 않은 알림 수
router.get('/unread-count', async (req, res) => {
  try {
    const count = await prisma.notification.count({
      where: { userId: req.user.id, isRead: false },
    });
    res.json({ count });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// 전체 읽음 처리
router.patch('/read-all', async (req, res) => {
  try {
    await prisma.notification.updateMany({
      where: { userId: req.user.id, isRead: false },
      data: { isRead: true },
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// 개별 읽음 처리
router.patch('/:id/read', async (req, res) => {
  try {
    await prisma.notification.update({
      where: { id: req.params.id },
      data: { isRead: true },
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

export default router;

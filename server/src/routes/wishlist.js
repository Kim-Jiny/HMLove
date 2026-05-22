import { Router } from 'express';
import prisma from '../utils/prisma.js';
import { authenticate, requireCouple } from '../middleware/auth.js';
import { notifyPartner } from '../utils/firebase.js';

const router = Router();
router.use(authenticate, requireCouple);

// 목록 조회
router.get('/', async (req, res) => {
  try {
    const { coupleId } = req.user;

    const { category } = req.query;
    const where = { coupleId };
    if (category && ['PLACE', 'FOOD', 'ACTIVITY', 'OTHER'].includes(category)) {
      where.category = category;
    }

    const items = await prisma.wishItem.findMany({
      where,
      orderBy: [
        { isFavorite: 'desc' },
        { isCompleted: 'asc' },
        { createdAt: 'desc' },
      ],
    });

    res.json({ items });
  } catch (err) {
    console.error('GET /wishlist error:', err);
    res.status(500).json({ error: '위시리스트 조회에 실패했습니다.' });
  }
});

// 추가
router.post('/', async (req, res) => {
  try {
    const { coupleId, id: userId } = req.user;

    const { category, title, memo } = req.body;
    if (!title || !title.trim()) {
      return res.status(400).json({ error: '제목을 입력해주세요.' });
    }

    const item = await prisma.wishItem.create({
      data: {
        coupleId,
        authorId: userId,
        category: ['PLACE', 'FOOD', 'ACTIVITY', 'OTHER'].includes(category) ? category : 'OTHER',
        title: title.trim(),
        memo: memo?.trim() || null,
      },
    });

    // Socket.io broadcast.
    // Backwards-compat: item 필드를 root 에 spread 해두면 구버전 클라이언트
    // ({ ...item } 직접 파싱) 와 신버전 클라이언트 ({ item, actorId } 분리 파싱)
    // 모두 정상 동작. 구버전 앱이 모두 업데이트되면 spread 제거 가능.
    const io = req.app.get('io');
    if (io) {
      io.to(`couple:${coupleId}`).emit('wish:new', {
        ...item,
        item,
        actorId: userId,
      });
    }

    // 파트너에게 푸시 알림
    notifyPartner({
      userId,
      coupleId,
      title: '위시리스트',
      body: `새로운 위시가 추가됐어요: ${item.title}`,
      data: { type: 'wishlist', wishId: item.id },
    });

    res.status(201).json({ item });
  } catch (err) {
    console.error('POST /wishlist error:', err);
    res.status(500).json({ error: '위시 추가에 실패했습니다.' });
  }
});

// 수정
router.patch('/:id', async (req, res) => {
  try {
    const { coupleId, id: userId } = req.user;
    const { id } = req.params;

    const { category, title, memo } = req.body;
    const data = {};
    if (title !== undefined && typeof title === 'string') {
      const trimmed = title.trim();
      if (!trimmed) return res.status(400).json({ error: '제목을 입력해주세요.' });
      data.title = trimmed;
    }
    if (memo !== undefined) data.memo = typeof memo === 'string' ? memo.trim() || null : null;
    if (category && ['PLACE', 'FOOD', 'ACTIVITY', 'OTHER'].includes(category)) {
      data.category = category;
    }

    const existing = await prisma.wishItem.findFirst({ where: { id, coupleId } });
    if (!existing) return res.status(404).json({ error: '위시를 찾을 수 없습니다.' });

    if (Object.keys(data).length === 0) {
      return res.json({ item: existing });
    }

    const item = await prisma.wishItem.update({
      where: { id },
      data,
    });

    const io = req.app.get('io');
    if (io) {
      io.to(`couple:${coupleId}`).emit('wish:updated', {
        ...item,
        item,
        actorId: userId,
      });
    }

    res.json({ item });
  } catch (err) {
    if (err.code === 'P2025') {
      return res.status(404).json({ error: '위시를 찾을 수 없습니다.' });
    }
    console.error('PATCH /wishlist/:id error:', err);
    res.status(500).json({ error: '위시 수정에 실패했습니다.' });
  }
});

// 즐겨찾기 토글
router.patch('/:id/favorite', async (req, res) => {
  try {
    const { coupleId, id: userId } = req.user;
    const { id } = req.params;

    const existing = await prisma.wishItem.findFirst({ where: { id, coupleId } });
    if (!existing) {
      return res.status(404).json({ error: '위시를 찾을 수 없습니다.' });
    }

    const item = await prisma.wishItem.update({
      where: { id },
      data: {
        isFavorite: !existing.isFavorite,
      },
    });

    const io = req.app.get('io');
    if (io) {
      io.to(`couple:${coupleId}`).emit('wish:updated', {
        ...item,
        item,
        actorId: userId,
      });
    }

    res.json({ item });
  } catch (err) {
    if (err.code === 'P2025') {
      return res.status(404).json({ error: '위시를 찾을 수 없습니다.' });
    }
    console.error('PATCH /wishlist/:id/favorite error:', err);
    res.status(500).json({ error: '즐겨찾기 변경에 실패했습니다.' });
  }
});

// 완료 토글
router.patch('/:id/toggle', async (req, res) => {
  try {
    const { coupleId, id: userId } = req.user;
    const { id } = req.params;

    const existing = await prisma.wishItem.findFirst({ where: { id, coupleId } });
    if (!existing) {
      return res.status(404).json({ error: '위시를 찾을 수 없습니다.' });
    }

    const newCompleted = !existing.isCompleted;
    const item = await prisma.wishItem.update({
      where: { id },
      data: {
        isCompleted: newCompleted,
        completedBy: newCompleted ? userId : null,
        completedAt: newCompleted ? new Date() : null,
      },
    });

    const io = req.app.get('io');
    if (io) {
      io.to(`couple:${coupleId}`).emit('wish:toggled', {
        ...item,
        item,
        actorId: userId,
      });
    }

    if (newCompleted) {
      notifyPartner({
        userId,
        coupleId,
        title: '위시리스트',
        body: `위시가 완료됐어요: ${item.title}`,
        data: { type: 'wishlist', wishId: item.id },
      });
    }

    res.json({ item });
  } catch (err) {
    if (err.code === 'P2025') {
      return res.status(404).json({ error: '위시를 찾을 수 없습니다.' });
    }
    console.error('PATCH /wishlist/:id/toggle error:', err);
    res.status(500).json({ error: '위시 상태 변경에 실패했습니다.' });
  }
});

// 삭제
router.delete('/:id', async (req, res) => {
  try {
    const { coupleId, id: userId } = req.user;
    const { id } = req.params;

    const existing = await prisma.wishItem.findFirst({ where: { id, coupleId } });
    if (!existing) {
      return res.status(404).json({ error: '위시를 찾을 수 없습니다.' });
    }

    await prisma.wishItem.delete({ where: { id } });

    const io = req.app.get('io');
    if (io) {
      io.to(`couple:${coupleId}`).emit('wish:deleted', { id, actorId: userId });
    }

    res.json({ success: true });
  } catch (err) {
    if (err.code === 'P2025') {
      return res.status(404).json({ error: '위시를 찾을 수 없습니다.' });
    }
    console.error('DELETE /wishlist/:id error:', err);
    res.status(500).json({ error: '위시 삭제에 실패했습니다.' });
  }
});

export default router;

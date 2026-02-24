import { Router } from 'express';
import { authenticate, requireCouple } from '../middleware/auth.js';
import prisma from '../utils/prisma.js';
import { notifyPartner } from '../utils/firebase.js';

const router = Router();
router.use(authenticate, requireCouple);

// GET /feed/unread-count?since=ISO_DATE
router.get('/unread-count', async (req, res) => {
  try {
    const { since } = req.query;
    const count = await prisma.feed.count({
      where: {
        coupleId: req.user.coupleId,
        authorId: { not: req.user.id },
        ...(since && { createdAt: { gt: new Date(since) } }),
      },
    });
    res.json({ count });
  } catch (err) {
    console.error('Feed unread count error:', err);
    res.json({ count: 0 });
  }
});

// GET /feed?cursor=xxx&limit=20
router.get('/', async (req, res) => {
  try {
    const { cursor, limit = '20' } = req.query;
    const take = Math.min(parseInt(limit), 50);

    const where = { coupleId: req.user.coupleId };

    const feeds = await prisma.feed.findMany({
      where,
      take: take + 1,
      ...(cursor && { cursor: { id: cursor }, skip: 1 }),
      orderBy: { createdAt: 'desc' },
      include: {
        author: { select: { id: true, nickname: true, profileImage: true } },
      },
    });

    const hasNext = feeds.length > take;
    if (hasNext) feeds.pop();

    const nextCursor = hasNext ? feeds[feeds.length - 1].id : null;

    res.json({ feeds, nextCursor });
  } catch (err) {
    console.error('Get feeds error:', err);
    res.status(500).json({ error: '피드 조회에 실패했습니다.' });
  }
});

// POST /feed
router.post('/', async (req, res) => {
  try {
    const { content, imageUrl, type } = req.body;

    if (!content) {
      return res.status(400).json({ error: '내용을 입력해주세요.' });
    }

    const feed = await prisma.feed.create({
      data: {
        coupleId: req.user.coupleId,
        authorId: req.user.id,
        content,
        imageUrl,
        type: type || 'DIARY',
      },
      include: {
        author: { select: { id: true, nickname: true, profileImage: true } },
      },
    });

    // 상대방에게 푸시 알림
    notifyPartner({
      userId: req.user.id,
      coupleId: req.user.coupleId,
      title: req.user.nickname || '상대방',
      body: '새 피드를 올렸어요',
      data: { type: 'feed' },
    });

    res.status(201).json({ feed });
  } catch (err) {
    console.error('Create feed error:', err);
    res.status(500).json({ error: '피드 생성에 실패했습니다.' });
  }
});

// DELETE /feed/:id
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const feed = await prisma.feed.findUnique({ where: { id } });
    if (!feed || feed.coupleId !== req.user.coupleId) {
      return res.status(404).json({ error: '피드를 찾을 수 없습니다.' });
    }

    if (feed.authorId !== req.user.id) {
      return res.status(403).json({ error: '본인이 작성한 피드만 삭제할 수 있습니다.' });
    }

    await prisma.feed.delete({ where: { id } });
    res.json({ message: '피드가 삭제되었습니다.' });
  } catch (err) {
    console.error('Delete feed error:', err);
    res.status(500).json({ error: '피드 삭제에 실패했습니다.' });
  }
});

export default router;

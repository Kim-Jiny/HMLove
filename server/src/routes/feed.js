import { Router } from 'express';
import multer from 'multer';
import sharp from 'sharp';
import { authenticate, requireCouple } from '../middleware/auth.js';
import prisma from '../utils/prisma.js';
import { uploadFile } from '../utils/storage.js';
import { notifyPartner } from '../utils/firebase.js';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) cb(null, true);
    else cb(new Error('이미지 파일만 업로드 가능합니다.'));
  },
});

const router = Router();
router.use(authenticate, requireCouple);

const feedInclude = (userId) => ({
  author: { select: { id: true, nickname: true, profileImage: true } },
  _count: { select: { likes: true, comments: true } },
  likes: { where: { userId }, select: { id: true } },
  comments: {
    take: 3,
    orderBy: { createdAt: 'desc' },
    include: { author: { select: { id: true, nickname: true, profileImage: true } } },
  },
});

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

    const feeds = await prisma.feed.findMany({
      where: { coupleId: req.user.coupleId },
      take: take + 1,
      ...(cursor && { cursor: { id: cursor }, skip: 1 }),
      orderBy: { createdAt: 'desc' },
      include: feedInclude(req.user.id),
    });

    const hasNext = feeds.length > take;
    if (hasNext) feeds.pop();
    const nextCursor = hasNext ? feeds[feeds.length - 1].id : null;

    // Transform: add isLiked, likeCount, commentCount, recentComments
    const result = feeds.map(f => ({
      ...f,
      isLiked: f.likes.length > 0,
      likeCount: f._count.likes,
      commentCount: f._count.comments,
      recentComments: [...f.comments].reverse(),
      likes: undefined,
      _count: undefined,
      comments: undefined,
    }));

    res.json({ feeds: result, nextCursor });
  } catch (err) {
    console.error('Get feeds error:', err);
    res.status(500).json({ error: '피드 조회에 실패했습니다.' });
  }
});

// POST /feed/upload — 피드 이미지 업로드 (최대 5장, Supabase Storage)
router.post('/upload', upload.array('images', 5), async (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ error: '이미지를 첨부해주세요.' });
    }

    const imageUrls = [];

    for (let i = 0; i < req.files.length; i++) {
      const fileName = `${Date.now()}_${req.user.id}_${i}.webp`;

      const buffer = await sharp(req.files[i].buffer)
        .rotate()
        .resize(1080, 1080, { fit: 'inside', withoutEnlargement: true })
        .webp({ quality: 75 })
        .toBuffer();

      const key = `feed/${fileName}`;
      try {
        const publicUrl = await uploadFile(buffer, key, 'image/webp');
        imageUrls.push(publicUrl);
      } catch (err) {
        console.error('Feed upload error:', err);
        continue;
      }
    }

    res.json({ imageUrls });
  } catch (err) {
    console.error('Feed upload error:', err);
    res.status(500).json({ error: '이미지 업로드에 실패했습니다.' });
  }
});

// POST /feed
router.post('/', async (req, res) => {
  try {
    const { content, imageUrls, type } = req.body;

    if (!content && (!imageUrls || imageUrls.length === 0)) {
      return res.status(400).json({ error: '내용 또는 이미지를 입력해주세요.' });
    }

    const feed = await prisma.feed.create({
      data: {
        coupleId: req.user.coupleId,
        authorId: req.user.id,
        content: content || '',
        imageUrls: imageUrls || [],
        type: type || (imageUrls?.length > 0 ? 'PHOTO' : 'DIARY'),
      },
      include: feedInclude(req.user.id),
    });

    const result = {
      ...feed,
      isLiked: false,
      likeCount: 0,
      commentCount: 0,
      recentComments: [],
      likes: undefined,
      _count: undefined,
      comments: undefined,
    };

    notifyPartner({
      userId: req.user.id,
      coupleId: req.user.coupleId,
      title: req.user.nickname || '상대방',
      body: '새 피드를 올렸어요',
      data: { type: 'feed' },
    });

    res.status(201).json({ feed: result });
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

// POST /feed/:id/like — 좋아요 토글
router.post('/:id/like', async (req, res) => {
  try {
    const { id } = req.params;

    const feed = await prisma.feed.findUnique({ where: { id } });
    if (!feed || feed.coupleId !== req.user.coupleId) {
      return res.status(404).json({ error: '피드를 찾을 수 없습니다.' });
    }

    const existing = await prisma.feedLike.findUnique({
      where: { feedId_userId: { feedId: id, userId: req.user.id } },
    });

    if (existing) {
      await prisma.feedLike.delete({ where: { id: existing.id } });
      const count = await prisma.feedLike.count({ where: { feedId: id } });
      res.json({ isLiked: false, likeCount: count });
    } else {
      await prisma.feedLike.create({
        data: { feedId: id, userId: req.user.id },
      });
      const count = await prisma.feedLike.count({ where: { feedId: id } });

      // 좋아요 알림 (내 글이 아닐 때만)
      if (feed.authorId !== req.user.id) {
        notifyPartner({
          userId: req.user.id,
          coupleId: req.user.coupleId,
          title: req.user.nickname || '상대방',
          body: '피드에 좋아요를 눌렀어요 ❤️',
          data: { type: 'feed_like', feedId: id },
        });
      }

      res.json({ isLiked: true, likeCount: count });
    }
  } catch (err) {
    console.error('Like feed error:', err);
    res.status(500).json({ error: '좋아요 처리에 실패했습니다.' });
  }
});

// GET /feed/:id/comments — 댓글 목록
router.get('/:id/comments', async (req, res) => {
  try {
    const { id } = req.params;

    const comments = await prisma.feedComment.findMany({
      where: { feedId: id },
      orderBy: { createdAt: 'asc' },
      include: {
        author: { select: { id: true, nickname: true, profileImage: true } },
      },
    });

    res.json({ comments });
  } catch (err) {
    console.error('Get comments error:', err);
    res.status(500).json({ error: '댓글 조회에 실패했습니다.' });
  }
});

// POST /feed/:id/comments — 댓글 작성
router.post('/:id/comments', async (req, res) => {
  try {
    const { id } = req.params;
    const { content } = req.body;

    if (!content || content.trim().length === 0) {
      return res.status(400).json({ error: '댓글 내용을 입력해주세요.' });
    }

    const feed = await prisma.feed.findUnique({ where: { id } });
    if (!feed || feed.coupleId !== req.user.coupleId) {
      return res.status(404).json({ error: '피드를 찾을 수 없습니다.' });
    }

    const comment = await prisma.feedComment.create({
      data: {
        feedId: id,
        authorId: req.user.id,
        content: content.trim(),
      },
      include: {
        author: { select: { id: true, nickname: true, profileImage: true } },
      },
    });

    // 댓글 알림
    if (feed.authorId !== req.user.id) {
      notifyPartner({
        userId: req.user.id,
        coupleId: req.user.coupleId,
        title: req.user.nickname || '상대방',
        body: `댓글: ${content.trim().substring(0, 30)}`,
        data: { type: 'feed_comment', feedId: id },
      });
    }

    res.status(201).json({ comment });
  } catch (err) {
    console.error('Create comment error:', err);
    res.status(500).json({ error: '댓글 작성에 실패했습니다.' });
  }
});

// DELETE /feed/:id/comments/:commentId — 댓글 삭제
router.delete('/:id/comments/:commentId', async (req, res) => {
  try {
    const { commentId } = req.params;

    const comment = await prisma.feedComment.findUnique({
      where: { id: commentId },
    });
    if (!comment || comment.authorId !== req.user.id) {
      return res.status(403).json({ error: '본인이 작성한 댓글만 삭제할 수 있습니다.' });
    }

    await prisma.feedComment.delete({ where: { id: commentId } });
    res.json({ message: '댓글이 삭제되었습니다.' });
  } catch (err) {
    console.error('Delete comment error:', err);
    res.status(500).json({ error: '댓글 삭제에 실패했습니다.' });
  }
});

export default router;

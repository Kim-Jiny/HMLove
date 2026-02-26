import { Router } from 'express';
import multer from 'multer';
import sharp from 'sharp';
import { mkdirSync, existsSync } from 'fs';
import { authenticate, requireCouple } from '../middleware/auth.js';
import prisma from '../utils/prisma.js';

const UPLOAD_DIR = 'uploads/chat';
if (!existsSync(UPLOAD_DIR)) mkdirSync(UPLOAD_DIR, { recursive: true });

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

// POST /chat/upload — 채팅 이미지 업로드
router.post('/upload', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: '이미지를 첨부해주세요.' });
    }

    const fileName = `${Date.now()}_${req.user.id}.webp`;
    const filePath = `${UPLOAD_DIR}/${fileName}`;

    await sharp(req.file.buffer)
      .rotate() // EXIF 기반 자동 회전
      .resize(1200, 1200, { fit: 'inside', withoutEnlargement: true })
      .webp({ quality: 80 })
      .toFile(filePath);

    const baseUrl = `${req.protocol}://${req.get('host')}`;
    const imageUrl = `${baseUrl}/${filePath}`;

    res.json({ imageUrl });
  } catch (err) {
    console.error('Chat upload error:', err);
    res.status(500).json({ error: '이미지 업로드에 실패했습니다.' });
  }
});

// GET /chat/media?cursor=xxx&limit=20 — 미디어 메시지만
router.get('/media', async (req, res) => {
  try {
    const { cursor, limit = '20' } = req.query;
    const take = Math.min(parseInt(limit), 50);

    const messages = await prisma.message.findMany({
      where: {
        coupleId: req.user.coupleId,
        imageUrl: { not: null },
      },
      take: take + 1,
      ...(cursor && { cursor: { id: cursor }, skip: 1 }),
      orderBy: { createdAt: 'desc' },
      select: { id: true, imageUrl: true, senderId: true, createdAt: true },
    });

    const hasNext = messages.length > take;
    if (hasNext) messages.pop();
    const nextCursor = hasNext ? messages[messages.length - 1].id : null;

    res.json({ messages, nextCursor });
  } catch (err) {
    console.error('Get media error:', err);
    res.status(500).json({ error: '미디어 조회에 실패했습니다.' });
  }
});

// GET /chat/messages/around/:messageId — 특정 메시지 주변 메시지 조회
router.get('/messages/around/:messageId', async (req, res) => {
  try {
    const { messageId } = req.params;
    const half = 15;

    const target = await prisma.message.findUnique({
      where: { id: messageId },
      include: {
        sender: { select: { id: true, nickname: true, profileImage: true } },
      },
    });

    if (!target || target.coupleId !== req.user.coupleId) {
      return res.status(404).json({ error: '메시지를 찾을 수 없습니다.' });
    }

    const [newer, older] = await Promise.all([
      prisma.message.findMany({
        where: {
          coupleId: req.user.coupleId,
          createdAt: { gt: target.createdAt },
        },
        take: half,
        orderBy: { createdAt: 'asc' },
        include: {
          sender: { select: { id: true, nickname: true, profileImage: true } },
        },
      }),
      prisma.message.findMany({
        where: {
          coupleId: req.user.coupleId,
          createdAt: { lt: target.createdAt },
        },
        take: half + 1,
        orderBy: { createdAt: 'desc' },
        include: {
          sender: { select: { id: true, nickname: true, profileImage: true } },
        },
      }),
    ]);

    const hasMore = older.length > half;
    if (hasMore) older.pop();

    // newest first: [...newer reversed, target, ...older]
    const messages = [...newer.reverse(), target, ...older];
    const nextCursor = hasMore ? older[older.length - 1].id : null;

    res.json({ messages, nextCursor, hasMore, targetIndex: newer.length });
  } catch (err) {
    console.error('Get messages around error:', err);
    res.status(500).json({ error: '메시지 조회에 실패했습니다.' });
  }
});

// GET /chat/search?q=keyword&cursor=xxx&limit=20 — 메시지 검색
router.get('/search', async (req, res) => {
  try {
    const { q, cursor, limit = '20' } = req.query;
    if (!q || q.trim().length === 0) {
      return res.json({ messages: [], nextCursor: null });
    }

    const take = Math.min(parseInt(limit), 50);

    const messages = await prisma.message.findMany({
      where: {
        coupleId: req.user.coupleId,
        content: { contains: q.trim(), mode: 'insensitive' },
      },
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
    console.error('Search messages error:', err);
    res.status(500).json({ error: '검색에 실패했습니다.' });
  }
});

export default router;

import { Router } from 'express';
import prisma from '../utils/prisma.js';
import { authenticate } from '../middleware/auth.js';

const router = Router();

router.use(authenticate);

// POST /inquiry - 문의 생성
router.post('/', async (req, res) => {
  try {
    const { category, title, content, appVersion, deviceModel, osVersion } = req.body;
    if (!title || !content) {
      return res.status(400).json({ error: '제목과 내용을 입력해주세요.' });
    }

    const inquiry = await prisma.inquiry.create({
      data: {
        userId: req.user.id,
        category: category || 'other',
        title,
        content,
        appVersion,
        deviceModel,
        osVersion,
      },
    });

    res.status(201).json({ inquiry });
  } catch (err) {
    console.error('Create inquiry error:', err);
    res.status(500).json({ error: '문의 접수에 실패했습니다.' });
  }
});

// GET /inquiry - 내 문의 목록
router.get('/', async (req, res) => {
  try {
    const inquiries = await prisma.inquiry.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' },
    });

    res.json({ inquiries });
  } catch (err) {
    console.error('Get inquiries error:', err);
    res.status(500).json({ error: '문의 조회에 실패했습니다.' });
  }
});

// GET /inquiry/unread-count - 미확인 답변 수
router.get('/unread-count', async (req, res) => {
  try {
    const count = await prisma.inquiry.count({
      where: {
        userId: req.user.id,
        adminReply: { not: null },
        isReplyRead: false,
      },
    });
    res.json({ count });
  } catch (err) {
    console.error('Inquiry unread count error:', err);
    res.status(500).json({ error: '조회에 실패했습니다.' });
  }
});

// PATCH /inquiry/:id/read - 답변 읽음 처리
router.patch('/:id/read', async (req, res) => {
  try {
    const inquiry = await prisma.inquiry.findUnique({
      where: { id: req.params.id },
    });
    if (!inquiry || inquiry.userId !== req.user.id) {
      return res.status(404).json({ error: '문의를 찾을 수 없습니다.' });
    }

    await prisma.inquiry.update({
      where: { id: req.params.id },
      data: { isReplyRead: true },
    });

    res.json({ success: true });
  } catch (err) {
    console.error('Inquiry read error:', err);
    res.status(500).json({ error: '처리에 실패했습니다.' });
  }
});

export default router;

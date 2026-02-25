import { Router } from 'express';
import { authenticate, requireCouple } from '../middleware/auth.js';
import prisma from '../utils/prisma.js';
import { notifyPartner } from '../utils/firebase.js';

const router = Router();
router.use(authenticate, requireCouple);

function isDelivered(letter) {
  return new Date(letter.deliveryDate) <= new Date();
}

// GET /letter
router.get('/', async (req, res) => {
  try {
    const letters = await prisma.letter.findMany({
      where: {
        coupleId: req.user.coupleId,
        OR: [
          { writerId: req.user.id },
          { receiverId: req.user.id },
        ],
      },
      orderBy: { createdAt: 'desc' },
      include: {
        writer: { select: { id: true, nickname: true } },
        receiver: { select: { id: true, nickname: true } },
      },
    });

    // 아직 배달되지 않은 상대방의 편지 내용 숨기기
    const sanitized = letters.map((letter) => {
      if (letter.writerId !== req.user.id && !isDelivered(letter)) {
        return {
          ...letter,
          content: null,
          title: '아직 배달되지 않은 편지입니다',
          status: 'SCHEDULED',
        };
      }
      return {
        ...letter,
        status: isDelivered(letter) ? 'DELIVERED' : letter.status,
      };
    });

    res.json({ letters: sanitized });
  } catch (err) {
    console.error('Get letters error:', err);
    res.status(500).json({ error: '편지 목록 조회에 실패했습니다.' });
  }
});

// GET /letter/:id
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const letter = await prisma.letter.findUnique({
      where: { id },
      include: {
        writer: { select: { id: true, nickname: true, profileImage: true } },
        receiver: { select: { id: true, nickname: true, profileImage: true } },
      },
    });

    if (!letter || letter.coupleId !== req.user.coupleId) {
      return res.status(404).json({ error: '편지를 찾을 수 없습니다.' });
    }

    // 작성자가 아니고 아직 배달 전이면 볼 수 없음
    if (letter.writerId !== req.user.id && !isDelivered(letter)) {
      return res.status(403).json({ error: '아직 배달되지 않은 편지입니다.' });
    }

    res.json({ letter });
  } catch (err) {
    console.error('Get letter error:', err);
    res.status(500).json({ error: '편지 조회에 실패했습니다.' });
  }
});

// POST /letter
router.post('/', async (req, res) => {
  try {
    const { title, content, deliveryDate } = req.body;

    if (!title || !content || !deliveryDate) {
      return res.status(400).json({ error: '제목, 내용, 배달 날짜를 모두 입력해주세요.' });
    }

    // 커플의 상대방 찾기
    const partner = await prisma.user.findFirst({
      where: {
        coupleId: req.user.coupleId,
        id: { not: req.user.id },
      },
    });

    if (!partner) {
      return res.status(400).json({ error: '커플 상대방이 없습니다.' });
    }

    const delivery = new Date(deliveryDate);
    const status = delivery <= new Date() ? 'DELIVERED' : 'SCHEDULED';

    const letter = await prisma.letter.create({
      data: {
        coupleId: req.user.coupleId,
        writerId: req.user.id,
        receiverId: partner.id,
        title,
        content,
        deliveryDate: delivery,
        status,
      },
      include: {
        writer: { select: { id: true, nickname: true } },
        receiver: { select: { id: true, nickname: true } },
      },
    });

    // 즉시 배달된 편지면 상대방에게 푸시 알림
    if (status === 'DELIVERED') {
      notifyPartner({
        userId: req.user.id,
        coupleId: req.user.coupleId,
        title: req.user.nickname || '상대방',
        body: '편지가 도착했어요 💌',
        data: { type: 'letter', letterId: letter.id },
      });
    }

    res.status(201).json({ letter });
  } catch (err) {
    console.error('Create letter error:', err);
    res.status(500).json({ error: '편지 작성에 실패했습니다.' });
  }
});

// PUT /letter/:id
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { title, content, deliveryDate } = req.body;

    const existing = await prisma.letter.findUnique({ where: { id } });
    if (!existing || existing.coupleId !== req.user.coupleId) {
      return res.status(404).json({ error: '편지를 찾을 수 없습니다.' });
    }

    if (existing.writerId !== req.user.id) {
      return res.status(403).json({ error: '본인이 작성한 편지만 수정할 수 있습니다.' });
    }

    if (isDelivered(existing)) {
      return res.status(400).json({ error: '이미 배달된 편지는 수정할 수 없습니다.' });
    }

    const letter = await prisma.letter.update({
      where: { id },
      data: {
        ...(title !== undefined && { title }),
        ...(content !== undefined && { content }),
        ...(deliveryDate !== undefined && { deliveryDate: new Date(deliveryDate) }),
      },
      include: {
        writer: { select: { id: true, nickname: true } },
        receiver: { select: { id: true, nickname: true } },
      },
    });

    res.json({ letter });
  } catch (err) {
    console.error('Update letter error:', err);
    res.status(500).json({ error: '편지 수정에 실패했습니다.' });
  }
});

// DELETE /letter/:id
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const existing = await prisma.letter.findUnique({ where: { id } });
    if (!existing || existing.coupleId !== req.user.coupleId) {
      return res.status(404).json({ error: '편지를 찾을 수 없습니다.' });
    }

    if (existing.writerId !== req.user.id) {
      return res.status(403).json({ error: '본인이 작성한 편지만 삭제할 수 있습니다.' });
    }

    if (isDelivered(existing)) {
      return res.status(400).json({ error: '이미 배달된 편지는 삭제할 수 없습니다.' });
    }

    await prisma.letter.delete({ where: { id } });
    res.json({ message: '편지가 삭제되었습니다.' });
  } catch (err) {
    console.error('Delete letter error:', err);
    res.status(500).json({ error: '편지 삭제에 실패했습니다.' });
  }
});

// PATCH /letter/:id/read
router.patch('/:id/read', async (req, res) => {
  try {
    const { id } = req.params;

    const existing = await prisma.letter.findUnique({ where: { id } });
    if (!existing || existing.coupleId !== req.user.coupleId) {
      return res.status(404).json({ error: '편지를 찾을 수 없습니다.' });
    }

    if (existing.receiverId !== req.user.id) {
      return res.status(403).json({ error: '수신자만 읽음 처리할 수 있습니다.' });
    }

    if (!isDelivered(existing)) {
      return res.status(400).json({ error: '아직 배달되지 않은 편지입니다.' });
    }

    const letter = await prisma.letter.update({
      where: { id },
      data: { isRead: true },
    });

    res.json({ letter });
  } catch (err) {
    console.error('Read letter error:', err);
    res.status(500).json({ error: '편지 읽음 처리에 실패했습니다.' });
  }
});

export default router;

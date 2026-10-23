import { Router } from 'express';
import { authenticate, requireCouple } from '../middleware/auth.js';
import { pokeLimiter } from '../middleware/rateLimit.js';
import prisma from '../utils/prisma.js';
import { notifyPartner } from '../utils/firebase.js';

const router = Router();
router.use(authenticate, requireCouple);

// 콕 종류별 알림 문구. 키는 앱의 PokeKind 와 같아야 한다.
const KINDS = {
  miss: '보고싶어요',
  love: '사랑해요',
  cheer: '힘내요! 응원할게요',
  thanks: '고마워요',
  sorry: '미안해요',
  goodnight: '잘 자요',
};

// POST /poke  { kind?: 'miss' | 'love' | ... }  → 상대에게 콕 + 푸시
router.post('/', pokeLimiter, async (req, res) => {
  try {
    const kind = req.body?.kind ?? 'miss';
    if (typeof kind !== 'string' || !Object.hasOwn(KINDS, kind)) {
      return res.status(400).json({ error: '알 수 없는 콕 종류입니다.' });
    }

    const partner = await prisma.user.findFirst({
      where: { coupleId: req.user.coupleId, id: { not: req.user.id } },
      select: { id: true, nickname: true },
    });
    if (!partner) {
      return res.status(400).json({ error: '상대방이 연결되면 콕을 보낼 수 있어요.' });
    }

    const poke = await prisma.poke.create({
      data: {
        coupleId: req.user.coupleId,
        senderId: req.user.id,
        receiverId: partner.id,
        kind,
      },
    });

    const senderName = req.user.nickname || '상대방';
    const payload = {
      pokeId: poke.id,
      kind,
      senderName,
      createdAt: poke.createdAt.toISOString(),
    };

    // 응답을 막지 않도록 푸시는 기다리지 않는다 (실패해도 콕 기록은 남는다)
    notifyPartner({
      userId: req.user.id,
      coupleId: req.user.coupleId,
      title: senderName,
      body: KINDS[kind],
      data: { ...payload, type: 'poke' },
      silentData: { ...payload, type: 'poke_widget_refresh' },
    });

    res.status(201).json({ poke });
  } catch (err) {
    console.error('Send poke error:', err);
    res.status(500).json({ error: '콕을 보내지 못했어요.' });
  }
});

// GET /poke/latest → 내가 마지막으로 받은 콕 1건 (홈/위젯 표시용)
router.get('/latest', async (req, res) => {
  try {
    const poke = await prisma.poke.findFirst({
      where: { receiverId: req.user.id },
      orderBy: { createdAt: 'desc' },
      include: { sender: { select: { id: true, nickname: true } } },
    });
    res.json({ poke });
  } catch (err) {
    console.error('Get latest poke error:', err);
    res.status(500).json({ error: '콕을 불러오지 못했어요.' });
  }
});

export default router;

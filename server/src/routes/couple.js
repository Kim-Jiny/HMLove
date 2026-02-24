import { Router } from 'express';
import crypto from 'crypto';
import { authenticate, requireCouple } from '../middleware/auth.js';
import prisma from '../utils/prisma.js';

const router = Router();
router.use(authenticate);

const INVITE_CHARS = '123456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // 0, O 제외

function generateInviteCode() {
  const bytes = crypto.randomBytes(6);
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += INVITE_CHARS[bytes[i] % INVITE_CHARS.length];
  }
  return code;
}

// POST /couple/create
router.post('/create', async (req, res) => {
  try {
    if (req.user.coupleId) {
      return res.status(400).json({ error: '이미 커플이 연결되어 있습니다.' });
    }

    const { startDate } = req.body;
    if (!startDate) {
      return res.status(400).json({ error: '사귀기 시작한 날짜를 입력해주세요.' });
    }

    let inviteCode = generateInviteCode();
    // 중복 방지
    while (await prisma.couple.findUnique({ where: { inviteCode } })) {
      inviteCode = generateInviteCode();
    }

    const couple = await prisma.couple.create({
      data: {
        inviteCode,
        startDate: new Date(startDate),
        users: { connect: { id: req.user.id } },
      },
    });

    res.status(201).json({ couple });
  } catch (err) {
    console.error('Create couple error:', err);
    res.status(500).json({ error: '커플 생성에 실패했습니다.' });
  }
});

// POST /couple/join
router.post('/join', async (req, res) => {
  try {
    if (req.user.coupleId) {
      return res.status(400).json({ error: '이미 커플이 연결되어 있습니다.' });
    }

    const { inviteCode } = req.body;
    if (!inviteCode) {
      return res.status(400).json({ error: '초대 코드를 입력해주세요.' });
    }

    const couple = await prisma.couple.findUnique({
      where: { inviteCode },
      include: { users: true },
    });

    if (!couple) {
      return res.status(404).json({ error: '유효하지 않은 초대 코드입니다.' });
    }

    if (couple.users.length >= 2) {
      return res.status(400).json({ error: '이미 커플이 완성되었습니다.' });
    }

    await prisma.user.update({
      where: { id: req.user.id },
      data: { coupleId: couple.id },
    });

    const updated = await prisma.couple.findUnique({
      where: { id: couple.id },
      include: {
        users: {
          select: {
            id: true, email: true, nickname: true, profileImage: true,
            birthDate: true, zodiacSign: true, chineseZodiac: true,
            createdAt: true, updatedAt: true,
          },
        },
      },
    });

    res.json({ couple: updated });
  } catch (err) {
    console.error('Join couple error:', err);
    res.status(500).json({ error: '커플 연결에 실패했습니다.' });
  }
});

// DELETE /couple/leave — 커플 해제 (혼자만 있는 커플이면 커플도 삭제)
router.delete('/leave', async (req, res) => {
  try {
    const { coupleId } = req.user;
    if (!coupleId) {
      return res.status(400).json({ error: '연결된 커플이 없습니다.' });
    }

    const couple = await prisma.couple.findUnique({
      where: { id: coupleId },
      include: { users: { select: { id: true } } },
    });

    if (!couple) {
      return res.status(404).json({ error: '커플 정보를 찾을 수 없습니다.' });
    }

    // 유저의 coupleId를 해제
    await prisma.user.update({
      where: { id: req.user.id },
      data: { coupleId: null },
    });

    // 남은 멤버가 없으면 커플 자체를 삭제
    const remaining = couple.users.filter(u => u.id !== req.user.id);
    if (remaining.length === 0) {
      await prisma.couple.delete({ where: { id: coupleId } });
    }

    res.json({ message: '커플이 해제되었습니다.' });
  } catch (err) {
    console.error('Leave couple error:', err);
    res.status(500).json({ error: '커플 해제에 실패했습니다.' });
  }
});

// GET /couple/info
router.get('/info', requireCouple, async (req, res) => {
  try {
    const couple = await prisma.couple.findUnique({
      where: { id: req.user.coupleId },
      include: {
        users: {
          select: {
            id: true, email: true, nickname: true, profileImage: true,
            birthDate: true, zodiacSign: true, chineseZodiac: true,
            createdAt: true, updatedAt: true,
          },
        },
      },
    });

    const now = new Date();
    const diffTime = now.getTime() - new Date(couple.startDate).getTime();
    const daysTogether = Math.floor(diffTime / (1000 * 60 * 60 * 24)) + 1;

    res.json({ couple, daysTogether });
  } catch (err) {
    console.error('Get couple info error:', err);
    res.status(500).json({ error: '커플 정보 조회에 실패했습니다.' });
  }
});

// GET /couple/anniversaries
router.get('/anniversaries', requireCouple, async (req, res) => {
  try {
    const couple = await prisma.couple.findUnique({
      where: { id: req.user.coupleId },
    });

    const start = new Date(couple.startDate);
    const autoAnniversaries = [];

    // 100일 단위 (100, 200, 300, ... 1000)
    for (let d = 100; d <= 1000; d += 100) {
      const date = new Date(start);
      date.setDate(date.getDate() + d - 1);
      autoAnniversaries.push({ title: `${d}일`, date, type: 'auto' });
    }

    // 연 단위 (1~10주년)
    for (let y = 1; y <= 10; y++) {
      const date = new Date(start);
      date.setFullYear(date.getFullYear() + y);
      autoAnniversaries.push({ title: `${y}주년`, date, type: 'auto' });
    }

    // 사용자 등록 기념일
    const customAnniversaries = await prisma.calendarEvent.findMany({
      where: { coupleId: req.user.coupleId, isAnniversary: true },
      orderBy: { date: 'asc' },
    });

    res.json({
      auto: autoAnniversaries.sort((a, b) => a.date - b.date),
      custom: customAnniversaries,
    });
  } catch (err) {
    console.error('Get anniversaries error:', err);
    res.status(500).json({ error: '기념일 조회에 실패했습니다.' });
  }
});

export default router;

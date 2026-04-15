import { Router } from 'express';
import crypto from 'crypto';
import { authenticate, requireCouple } from '../middleware/auth.js';
import prisma from '../utils/prisma.js';
import { sendPushNotification } from '../utils/firebase.js';

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

    // 트랜잭션으로 race condition 방지
    const updated = await prisma.$transaction(async (tx) => {
      const couple = await tx.couple.findUnique({
        where: { inviteCode },
        include: { users: true },
      });

      if (!couple) {
        throw Object.assign(new Error('유효하지 않은 초대 코드입니다.'), { statusCode: 404 });
      }

      if (couple.users.length >= 2) {
        throw Object.assign(new Error('이미 커플이 완성되었습니다.'), { statusCode: 400 });
      }

      await tx.user.update({
        where: { id: req.user.id },
        data: { coupleId: couple.id },
      });

      return tx.couple.findUnique({
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
    }, { isolationLevel: 'Serializable' });

    res.json({ couple: updated });
  } catch (err) {
    if (err.statusCode) {
      return res.status(err.statusCode).json({ error: err.message });
    }
    console.error('Join couple error:', err);
    res.status(500).json({ error: '커플 연결에 실패했습니다.' });
  }
});

// GET /couple/members — 현재 커플 멤버 수 확인
router.get('/members', async (req, res) => {
  try {
    const { coupleId } = req.user;
    if (!coupleId) {
      return res.json({ memberCount: 0 });
    }

    const couple = await prisma.couple.findUnique({
      where: { id: coupleId },
      include: { users: { select: { id: true, nickname: true } } },
    });

    res.json({ memberCount: couple?.users.length ?? 0 });
  } catch (err) {
    res.json({ memberCount: 0 });
  }
});

// DELETE /couple/leave — 커플 해제
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

    // 남은 멤버 확인
    const remaining = couple.users.filter(u => u.id !== req.user.id);

    if (remaining.length === 0) {
      // 마지막 멤버가 나감 → 모든 커플 데이터 삭제
      await prisma.$transaction([
        prisma.feedLike.deleteMany({ where: { feed: { coupleId } } }),
        prisma.feedComment.deleteMany({ where: { feed: { coupleId } } }),
        prisma.feed.deleteMany({ where: { coupleId } }),
        prisma.message.deleteMany({ where: { coupleId } }),
        prisma.calendarEvent.deleteMany({ where: { coupleId } }),
        prisma.mood.deleteMany({ where: { coupleId } }),
        prisma.photo.deleteMany({ where: { coupleId } }),
        prisma.letter.deleteMany({ where: { coupleId } }),
        prisma.fight.deleteMany({ where: { coupleId } }),
        prisma.fortune.deleteMany({ where: { coupleId } }),
        prisma.coupleMission.deleteMany({ where: { coupleId } }),
        prisma.questionAnswer.deleteMany({ where: { question: { coupleId } } }),
        prisma.dailyQuestion.deleteMany({ where: { coupleId } }),
        prisma.wishItem.deleteMany({ where: { coupleId } }),
        prisma.couple.delete({ where: { id: coupleId } }),
      ]);

      res.json({ message: '커플이 해제되었습니다. 모든 데이터가 삭제되었습니다.', dataDeleted: true });
    } else {
      // 남은 상대에게 알림
      try {
        const partner = await prisma.user.findFirst({
          where: { coupleId, id: { not: req.user.id } },
          select: { id: true, fcmToken: true },
        });
        console.log('[Couple] Leave - partner:', partner?.id, 'fcmToken:', partner?.fcmToken ? 'exists' : 'null');
        if (partner?.fcmToken) {
          await sendPushNotification({
            token: partner.fcmToken,
            title: '커플 해제',
            body: `${req.user.nickname || '상대방'}님이 커플을 해제했습니다.`,
            data: { type: 'couple_left' },
          });
          console.log('[Couple] Push notification sent to partner');
        }
      } catch (pushErr) {
        console.error('[Couple] Push notification error:', pushErr);
      }

      res.json({ message: '커플이 해제되었습니다.', dataDeleted: false });
    }
  } catch (err) {
    console.error('Leave couple error:', err);
    res.status(500).json({ error: '커플 해제에 실패했습니다.' });
  }
});

// PATCH /couple/start-date — 사귄 날짜 수정
router.patch('/start-date', requireCouple, async (req, res) => {
  try {
    const { startDate } = req.body;
    if (!startDate) {
      return res.status(400).json({ error: '날짜를 입력해주세요.' });
    }

    const updated = await prisma.couple.update({
      where: { id: req.user.coupleId },
      data: { startDate: new Date(startDate) },
    });

    res.json({ couple: updated });
  } catch (err) {
    console.error('Update start date error:', err);
    res.status(500).json({ error: '날짜 수정에 실패했습니다.' });
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

    // 커플 정보는 자주 변하지 않음 — 5분 캐시
    res.set('Cache-Control', 'private, max-age=300');
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
      include: {
        users: { select: { id: true, nickname: true, birthDate: true } },
      },
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

    // 생일 (매년 반복)
    for (const user of couple.users) {
      if (user.birthDate) {
        const birth = new Date(user.birthDate);
        const now = new Date();
        // 올해 생일
        let thisYear = new Date(now.getFullYear(), birth.getMonth(), birth.getDate());
        // 내년 생일도 포함
        let nextYear = new Date(now.getFullYear() + 1, birth.getMonth(), birth.getDate());
        autoAnniversaries.push({
          title: `${user.nickname} 생일`,
          date: thisYear,
          type: 'auto',
          repeatType: 'YEARLY',
        });
        autoAnniversaries.push({
          title: `${user.nickname} 생일`,
          date: nextYear,
          type: 'auto',
          repeatType: 'YEARLY',
        });
      }
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

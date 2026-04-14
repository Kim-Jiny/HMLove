import { Router } from 'express';
import Anthropic from '@anthropic-ai/sdk';
import { authenticate, requireCouple } from '../middleware/auth.js';
import { fortuneLimiter } from '../middleware/rateLimit.js';
import prisma from '../utils/prisma.js';

const router = Router();
router.use(authenticate, requireCouple);
router.use(fortuneLimiter);

const anthropic = new Anthropic();

function getTodayDate() {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate());
}

async function generateFortune({ coupleId, today, todayStr, user1, user2, daysTogether }) {
  const u1Birthday = user1?.birthDate ? user1.birthDate.toISOString().split('T')[0] : '미정';
  const u2Birthday = user2?.birthDate ? user2.birthDate.toISOString().split('T')[0] : '미정';

  const prompt = `오늘은 ${todayStr}입니다.
커플 정보:
- ${user1?.nickname || '사용자1'}: ${user1?.zodiacSign || '미정'}, ${user1?.chineseZodiac || '미정'}, 생일 ${u1Birthday}
- ${user2?.nickname || '상대방'}: ${user2?.zodiacSign || '미정'}, ${user2?.chineseZodiac || '미정'}, 생일 ${u2Birthday}
- 사귄 지 ${daysTogether}일째

아래 형식으로 오늘의 커플 운세를 작성해주세요. 재미있고 따뜻하게 작성해주세요.
각 개인의 운세도 별자리와 띠를 기반으로 작성해주세요.
반드시 아래 JSON 형식으로만 응답해주세요:
{
  "generalLuck": "오늘의 전반적인 운세 (2-3문장)",
  "coupleLuck": "커플 관계 운세 (2-3문장)",
  "user1Luck": "${user1?.nickname || '사용자1'}의 개인 운세 (2-3문장, 별자리/띠 기반)",
  "user2Luck": "${user2?.nickname || '상대방'}의 개인 운세 (2-3문장, 별자리/띠 기반)",
  "dateTip": "오늘의 데이트 팁 (1-2문장)",
  "caution": "주의할 점 (1문장)",
  "luckyScore": 1에서 100 사이 정수
}`;

  const message = await anthropic.messages.create({
    model: 'claude-haiku-4-5-20251001',
    max_tokens: 1024,
    messages: [{ role: 'user', content: prompt }],
  });

  const text = message.content[0].text;
  const jsonMatch = text.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    throw new Error('운세 JSON 파싱 실패');
  }

  const data = JSON.parse(jsonMatch[0]);
  const score = parseInt(data.luckyScore, 10);

  // upsert로 race condition 방지
  const fortune = await prisma.fortune.upsert({
    where: { coupleId_date: { coupleId, date: today } },
    update: {},
    create: {
      coupleId,
      date: today,
      generalLuck: data.generalLuck || '',
      coupleLuck: data.coupleLuck || '',
      dateTip: data.dateTip || '',
      caution: data.caution || '',
      luckyScore: isNaN(score) ? 50 : Math.max(1, Math.min(100, score)),
      user1Id: user1?.id,
      user1Luck: data.user1Luck || '',
      user2Id: user2?.id,
      user2Luck: data.user2Luck || '',
    },
  });

  return fortune;
}

// GET /fortune/today
// ?check=true → 캐시 확인만 (신규 앱)
// ?check 없음 → 기존 동작 유지: 없으면 생성 (구버전 앱 하위호환)
router.get('/today', async (req, res) => {
  try {
    const today = getTodayDate();
    const checkOnly = req.query.check === 'true';

    const cached = await prisma.fortune.findUnique({
      where: {
        coupleId_date: {
          coupleId: req.user.coupleId,
          date: today,
        },
      },
    });

    if (cached) {
      // 운세는 하루 1회 변경 — 1시간 캐시
      res.set('Cache-Control', 'private, max-age=3600');
      return res.json({ fortune: cached, exists: true });
    }

    // 신규 앱: 확인만 하고 반환
    if (checkOnly) {
      return res.json({ fortune: null, exists: false });
    }

    // 구버전 앱 하위호환: 없으면 생성
    const couple = await prisma.couple.findUnique({
      where: { id: req.user.coupleId },
      include: {
        users: {
          select: { id: true, nickname: true, birthDate: true, zodiacSign: true, chineseZodiac: true },
        },
      },
    });

    const diffTime = new Date().getTime() - new Date(couple.startDate).getTime();
    const daysTogether = Math.floor(diffTime / (1000 * 60 * 60 * 24)) + 1;

    const user1 = couple.users[0];
    const user2 = couple.users[1];
    const todayStr = today.toISOString().split('T')[0];

    const fortune = await generateFortune({ coupleId: req.user.coupleId, today, todayStr, user1, user2, daysTogether });
    res.json({ fortune });
  } catch (err) {
    console.error('Get fortune error:', err);
    res.status(500).json({ error: '운세 조회에 실패했습니다.' });
  }
});

// POST /fortune/today — 운세 생성 (광고 시청 후 호출)
router.post('/today', async (req, res) => {
  try {
    const today = getTodayDate();

    // 중복 방지: 이미 존재하면 바로 반환
    const existing = await prisma.fortune.findUnique({
      where: {
        coupleId_date: {
          coupleId: req.user.coupleId,
          date: today,
        },
      },
    });

    if (existing) {
      return res.json({ fortune: existing, exists: true });
    }

    // 커플 정보 조회
    const couple = await prisma.couple.findUnique({
      where: { id: req.user.coupleId },
      include: {
        users: {
          select: { id: true, nickname: true, birthDate: true, zodiacSign: true, chineseZodiac: true },
        },
      },
    });

    const diffTime = new Date().getTime() - new Date(couple.startDate).getTime();
    const daysTogether = Math.floor(diffTime / (1000 * 60 * 60 * 24)) + 1;

    const user1 = couple.users[0];
    const user2 = couple.users[1];
    const todayStr = today.toISOString().split('T')[0];

    const fortune = await generateFortune({ coupleId: req.user.coupleId, today, todayStr, user1, user2, daysTogether });
    res.json({ fortune, exists: true });
  } catch (err) {
    console.error('Generate fortune error:', err);
    res.status(500).json({ error: '운세 생성에 실패했습니다.' });
  }
});

export default router;

import { Router } from 'express';
import Anthropic from '@anthropic-ai/sdk';
import { authenticate, requireCouple } from '../middleware/auth.js';
import prisma from '../utils/prisma.js';

const router = Router();
router.use(authenticate, requireCouple);

const anthropic = new Anthropic();

function getTodayDate() {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate());
}

// GET /fortune/today
router.get('/today', async (req, res) => {
  try {
    const today = getTodayDate();

    // 캐시 확인
    const cached = await prisma.fortune.findUnique({
      where: {
        coupleId_date: {
          coupleId: req.user.coupleId,
          date: today,
        },
      },
    });

    if (cached) {
      return res.json({ fortune: cached });
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

    const prompt = `오늘은 ${todayStr}입니다.
커플 정보:
- ${user1.nickname}: ${user1.zodiacSign}, ${user1.chineseZodiac}, 생일 ${user1.birthDate.toISOString().split('T')[0]}
- ${user2?.nickname || '상대방'}: ${user2?.zodiacSign || '미정'}, ${user2?.chineseZodiac || '미정'}, 생일 ${user2?.birthDate?.toISOString().split('T')[0] || '미정'}
- 사귄 지 ${daysTogether}일째

아래 형식으로 오늘의 커플 운세를 작성해주세요. 재미있고 따뜻하게 작성해주세요.
각 개인의 운세도 별자리와 띠를 기반으로 작성해주세요.
반드시 아래 JSON 형식으로만 응답해주세요:
{
  "generalLuck": "오늘의 전반적인 운세 (2-3문장)",
  "coupleLuck": "커플 관계 운세 (2-3문장)",
  "user1Luck": "${user1.nickname}의 개인 운세 (2-3문장, 별자리/띠 기반)",
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
      return res.status(500).json({ error: '운세 생성에 실패했습니다.' });
    }

    const data = JSON.parse(jsonMatch[0]);

    const fortune = await prisma.fortune.create({
      data: {
        coupleId: req.user.coupleId,
        date: today,
        generalLuck: data.generalLuck,
        coupleLuck: data.coupleLuck,
        dateTip: data.dateTip,
        caution: data.caution,
        luckyScore: Math.max(1, Math.min(100, data.luckyScore)),
        user1Id: user1.id,
        user1Luck: data.user1Luck,
        user2Id: user2?.id,
        user2Luck: data.user2Luck,
      },
    });

    res.json({ fortune });
  } catch (err) {
    console.error('Get fortune error:', err);
    res.status(500).json({ error: '운세 조회에 실패했습니다.' });
  }
});

export default router;

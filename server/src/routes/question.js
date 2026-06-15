import { Router } from 'express';
import prisma from '../utils/prisma.js';
import { authenticate, requireCouple } from '../middleware/auth.js';
import { notifyPartner } from '../utils/firebase.js';
import { QUESTION_POOL, getQuestionIndex } from '../utils/questions.js';

const router = Router();
router.use(authenticate, requireCouple);

const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

/**
 * 오늘 날짜 문자열 (KST 기준)
 */
function getTodayStr() {
  const now = new Date();
  const kst = new Date(now.getTime() + KST_OFFSET_MS);
  return `${kst.getUTCFullYear()}-${String(kst.getUTCMonth() + 1).padStart(2, '0')}-${String(kst.getUTCDate()).padStart(2, '0')}`;
}

/**
 * DB에 저장된 date(UTC 자정)로부터 해당 KST 날짜의 KST 자정(UTC) 시각을 구함
 * 예: DB date = 2026-04-16T00:00:00Z → KST 자정 = 2026-04-15T15:00:00Z
 */
function kstMidnightFromDbDate(dbDate) {
  return new Date(dbDate.getTime() - KST_OFFSET_MS);
}

/**
 * 해당 KST 날짜의 다음날 KST 자정까지 경과했는지 확인
 */
function isNextDayKST(dbDate) {
  const nextDayKstMidnight = new Date(kstMidnightFromDbDate(dbDate).getTime() + 24 * 60 * 60 * 1000);
  return Date.now() >= nextDayKstMidnight.getTime();
}

// 오늘 질문 + 답변 상태
router.get('/today', async (req, res) => {
  try {
    const { coupleId, id: userId } = req.user;

    const todayStr = getTodayStr();
    const todayDate = new Date(todayStr + 'T00:00:00.000Z');
    const questionIdx = getQuestionIndex(coupleId, todayStr);
    const questionText = QUESTION_POOL[questionIdx] || '오늘의 질문을 준비 중이에요.';

    // 둘 다 답변하지 않고 지나간 과거 질문은 정리 — 히스토리에서 빠지고, 같은 questionIdx가 미래에 다시 등장 가능.
    // 단, 어제 질문은 KST 자정 직후에도 한쪽이 답변 중일 수 있으므로 1일 유예를 둔다
    // (그러지 않으면 GET /today 가 어제 질문을 지우는 사이 POST answer 가 FK 에러로 실패).
    const yesterdayDate = new Date(todayDate.getTime() - 24 * 60 * 60 * 1000);
    await prisma.dailyQuestion.deleteMany({
      where: {
        coupleId,
        date: { lt: yesterdayDate },
        answers: { none: {} },
      },
    });

    // upsert: 오늘 질문이 없으면 생성
    const dailyQuestion = await prisma.dailyQuestion.upsert({
      where: { coupleId_date: { coupleId, date: todayDate } },
      update: {},
      create: {
        coupleId,
        questionIdx,
        date: todayDate,
      },
      include: {
        answers: {
          select: { id: true, userId: true, answer: true, createdAt: true },
        },
      },
    });

    // 둘 다 답변했는지 확인
    const bothAnswered = dailyQuestion.answers.length >= 2;
    // 다음날 KST 자정 경과 확인
    const elapsed = isNextDayKST(todayDate);
    const canReveal = bothAnswered || elapsed;

    // 내 답변과 파트너 답변 구분
    const myAnswer = dailyQuestion.answers.find(a => a.userId === userId);
    const partnerAnswer = dailyQuestion.answers.find(a => a.userId !== userId);

    res.json({
      id: dailyQuestion.id,
      questionIdx,
      questionText,
      date: todayStr,
      myAnswer: myAnswer || null,
      partnerAnswer: canReveal ? (partnerAnswer || null) : (partnerAnswer ? { answered: true } : null),
      bothAnswered,
      canReveal,
    });
  } catch (err) {
    console.error('GET /question/today error:', err);
    res.status(500).json({ error: '질문을 불러오는데 실패했습니다.' });
  }
});

// 답변 제출
router.post('/today/answer', async (req, res) => {
  try {
    const { coupleId, id: userId } = req.user;

    const { answer } = req.body;
    if (!answer || typeof answer !== 'string' || !answer.trim()) {
      return res.status(400).json({ error: '답변을 입력해주세요.' });
    }
    const trimmedAnswer = answer.trim();
    if (trimmedAnswer.length > 500) {
      return res.status(400).json({ error: '답변은 500자 이내로 입력해주세요.' });
    }

    const todayStr = getTodayStr();
    const todayDate = new Date(todayStr + 'T00:00:00.000Z');
    const questionIdx = getQuestionIndex(coupleId, todayStr);

    // 오늘 질문 가져오기 (없으면 생성)
    const dailyQuestion = await prisma.dailyQuestion.upsert({
      where: { coupleId_date: { coupleId, date: todayDate } },
      update: {},
      create: {
        coupleId,
        questionIdx,
        date: todayDate,
      },
    });

    // 답변 생성 (unique constraint로 중복 방지)
    let questionAnswer;
    try {
      questionAnswer = await prisma.questionAnswer.create({
        data: {
          questionId: dailyQuestion.id,
          userId,
          answer: trimmedAnswer,
        },
      });
    } catch (createErr) {
      if (createErr.code === 'P2002') {
        return res.status(400).json({ error: '이미 답변했습니다.' });
      }
      throw createErr;
    }

    // Socket.io broadcast
    const io = req.app.get('io');
    if (io) {
      io.to(`couple:${coupleId}`).emit('question:answered', {
        questionId: dailyQuestion.id,
        userId,
      });
    }

    // 파트너에게 푸시 알림
    notifyPartner({
      userId,
      coupleId,
      title: '오늘의 질문',
      body: '상대방이 오늘의 질문에 답변했어요!',
      data: { type: 'question' },
    });

    // 전체 답변 상태 반환
    const allAnswers = await prisma.questionAnswer.findMany({
      where: { questionId: dailyQuestion.id },
      select: { id: true, userId: true, answer: true, createdAt: true },
    });

    const bothAnswered = allAnswers.length >= 2;
    const elapsed = isNextDayKST(todayDate);
    const canReveal = bothAnswered || elapsed;
    const myAnswer = allAnswers.find(a => a.userId === userId);
    const partnerAnswer = allAnswers.find(a => a.userId !== userId);

    res.status(201).json({
      id: dailyQuestion.id,
      questionIdx,
      questionText: QUESTION_POOL[questionIdx] || '오늘의 질문을 준비 중이에요.',
      date: todayStr,
      myAnswer: myAnswer || null,
      partnerAnswer: canReveal ? (partnerAnswer || null) : (partnerAnswer ? { answered: true } : null),
      bothAnswered,
      canReveal,
    });
  } catch (err) {
    console.error('POST /question/today/answer error:', err);
    res.status(500).json({ error: '답변 제출에 실패했습니다.' });
  }
});

// 지난 질문 히스토리
router.get('/history', async (req, res) => {
  try {
    const { coupleId, id: userId } = req.user;

    const { cursor, limit: limitStr } = req.query;
    const limit = Math.max(1, Math.min(parseInt(limitStr) || 20, 50));

    const todayStr = getTodayStr();
    const todayDate = new Date(todayStr + 'T00:00:00.000Z');

    const questions = await prisma.dailyQuestion.findMany({
      where: {
        coupleId,
        date: { lt: todayDate },
        answers: { some: {} }, // 둘 다 답변하지 않은 날은 히스토리에서 제외
      },
      orderBy: { date: 'desc' },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: {
        answers: {
          select: { id: true, userId: true, answer: true, createdAt: true },
        },
      },
    });

    const hasMore = questions.length > limit;
    const items = questions.slice(0, limit).map(q => {
      const myAnswer = q.answers.find(a => a.userId === userId);
      const partnerAnswer = q.answers.find(a => a.userId !== userId);
      const dateStr = q.date.toISOString().split('T')[0];
      const bothAnswered = q.answers.length >= 2;
      // 파트너 답변 공개 조건: 둘 다 답변 OR 다음날 KST 자정 경과
      const elapsed = isNextDayKST(q.date);
      const canReveal = bothAnswered || elapsed;
      return {
        id: q.id,
        questionIdx: q.questionIdx,
        questionText: QUESTION_POOL[q.questionIdx] || '질문을 찾을 수 없습니다.',
        date: dateStr,
        myAnswer: myAnswer || null,
        partnerAnswer: canReveal ? (partnerAnswer || null) : (partnerAnswer ? { answered: true } : null),
        bothAnswered,
      };
    });

    const nextCursor = hasMore ? questions[limit - 1].id : null;

    res.json({ items, nextCursor });
  } catch (err) {
    console.error('GET /question/history error:', err);
    res.status(500).json({ error: '히스토리를 불러오는데 실패했습니다.' });
  }
});

export default router;

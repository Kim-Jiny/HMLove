import { Router } from 'express';
import { authenticate, requireCouple } from '../middleware/auth.js';
import prisma from '../utils/prisma.js';
import {
  DAILY_MISSIONS,
  WEEKLY_MISSIONS,
  getMonday,
  getToday,
  pickMission,
} from './mission.js';
import { QUESTION_POOL, getQuestionIndex } from '../utils/questions.js';

const router = Router();
router.use(authenticate, requireCouple);

const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

function getKstTodayStr() {
  const now = new Date();
  const kst = new Date(now.getTime() + KST_OFFSET_MS);
  return `${kst.getUTCFullYear()}-${String(kst.getUTCMonth() + 1).padStart(2, '0')}-${String(kst.getUTCDate()).padStart(2, '0')}`;
}

function isNextDayKST(dbDate) {
  const kstMidnight = new Date(dbDate.getTime() - KST_OFFSET_MS);
  return Date.now() >= kstMidnight.getTime() + 24 * 60 * 60 * 1000;
}

function formatSchedule(events) {
  const explicit = events.filter((event) => event._auto !== true);
  if (explicit.length === 0) return '';
  return explicit
    .slice(0, 3)
    .map((event) => `• ${event.title}`)
    .join('\n');
}

router.get('/summary', async (req, res) => {
  try {
    const { id: userId, coupleId } = req.user;
    const localDate = typeof req.query.date === 'string'
      ? req.query.date
      : getKstTodayStr();
    const month = typeof req.query.month === 'string'
      ? req.query.month
      : localDate.slice(0, 7);
    const lastSeenFeedAt = typeof req.query.lastSeenFeedAt === 'string'
      ? req.query.lastSeenFeedAt
      : null;

    const moodDate = new Date(`${localDate}T00:00:00.000Z`);
    const missionToday = getToday();
    const monday = getMonday(missionToday);
    const missionTodayStr = missionToday.toISOString().split('T')[0];
    const mondayStr = monday.toISOString().split('T')[0];
    const questionTodayStr = getKstTodayStr();
    const questionTodayDate = new Date(`${questionTodayStr}T00:00:00.000Z`);
    const questionIdx = getQuestionIndex(coupleId, questionTodayStr);

    const dailyPick = pickMission(DAILY_MISSIONS, coupleId, missionTodayStr);
    const weeklyPick = pickMission(WEEKLY_MISSIONS, coupleId, mondayStr);

    const [
      couple,
      moods,
      fortune,
      daily,
      weekly,
      _removedQuestions,
      dailyQuestion,
      wishlistItems,
      latestDoodle,
      notificationUnreadCount,
      chatUnreadCount,
      feedUnseenCount,
      todayEvents,
    ] = await prisma.$transaction(async (tx) => {
      const coupleQuery = tx.couple.findUnique({
        where: { id: coupleId },
        include: {
          users: {
            select: {
              id: true,
              email: true,
              nickname: true,
              profileImage: true,
              birthDate: true,
              zodiacSign: true,
              chineseZodiac: true,
              createdAt: true,
              updatedAt: true,
            },
          },
        },
      });
      const moodsQuery = tx.mood.findMany({
        where: { coupleId, date: moodDate },
        include: { user: { select: { id: true, nickname: true, profileImage: true } } },
      });
      const fortuneQuery = tx.fortune.findUnique({
        where: { coupleId_date: { coupleId, date: missionToday } },
      });
      const dailyQuery = tx.coupleMission.upsert({
        where: { coupleId_type_date: { coupleId, type: 'DAILY', date: missionToday } },
        update: {},
        create: {
          coupleId,
          type: 'DAILY',
          date: missionToday,
          title: dailyPick.title,
          description: dailyPick.description,
          emoji: dailyPick.emoji,
        },
      });
      const weeklyQuery = tx.coupleMission.upsert({
        where: { coupleId_type_date: { coupleId, type: 'WEEKLY', date: monday } },
        update: {},
        create: {
          coupleId,
          type: 'WEEKLY',
          date: monday,
          title: weeklyPick.title,
          description: weeklyPick.description,
          emoji: weeklyPick.emoji,
        },
      });
      const cleanupQuestionQuery = tx.dailyQuestion.deleteMany({
        where: {
          coupleId,
          date: { lt: questionTodayDate },
          answers: { none: {} },
        },
      });
      const questionQuery = tx.dailyQuestion.upsert({
        where: { coupleId_date: { coupleId, date: questionTodayDate } },
        update: {},
        create: { coupleId, questionIdx, date: questionTodayDate },
        include: {
          answers: {
            select: { id: true, userId: true, answer: true, createdAt: true },
          },
        },
      });
      const wishlistQuery = tx.wishItem.findMany({
        where: { coupleId },
        orderBy: [
          { isFavorite: 'desc' },
          { isCompleted: 'asc' },
          { createdAt: 'desc' },
        ],
      });
      const doodleQuery = tx.doodle.findFirst({
        where: { receiverId: userId },
        orderBy: { createdAt: 'desc' },
        include: { sender: { select: { id: true, nickname: true } } },
      });
      const notificationUnreadQuery = tx.notification.count({
        where: { userId, isRead: false },
      });
      const chatUnreadQuery = tx.message.count({
        where: {
          coupleId,
          senderId: { not: userId },
          isRead: false,
        },
      });
      const feedUnseenQuery = tx.feed.count({
        where: {
          coupleId,
          authorId: { not: userId },
          ...(lastSeenFeedAt && { createdAt: { gt: new Date(lastSeenFeedAt) } }),
        },
      });
      const start = new Date(`${localDate}T00:00:00.000Z`);
      const end = new Date(start);
      end.setUTCDate(end.getUTCDate() + 1);
      const todayEventsQuery = tx.calendarEvent.findMany({
        where: {
          coupleId,
          date: { gte: start, lt: end },
        },
        orderBy: { date: 'asc' },
      });

      return Promise.all([
        coupleQuery,
        moodsQuery,
        fortuneQuery,
        dailyQuery,
        weeklyQuery,
        cleanupQuestionQuery,
        questionQuery,
        wishlistQuery,
        doodleQuery,
        notificationUnreadQuery,
        chatUnreadQuery,
        feedUnseenQuery,
        todayEventsQuery,
      ]);
    });

    const bothAnswered = dailyQuestion.answers.length >= 2;
    const canReveal = bothAnswered || isNextDayKST(questionTodayDate);
    const myAnswer = dailyQuestion.answers.find((answer) => answer.userId === userId);
    const partnerAnswer = dailyQuestion.answers.find((answer) => answer.userId !== userId);

    res.set('Cache-Control', 'private, max-age=15');
    res.json({
      couple,
      moods,
      fortune: { fortune, exists: Boolean(fortune) },
      missions: { daily, weekly },
      question: {
        id: dailyQuestion.id,
        questionIdx,
        questionText: QUESTION_POOL[questionIdx] || '오늘의 질문을 준비 중이에요.',
        date: questionTodayStr,
        myAnswer: myAnswer || null,
        partnerAnswer: canReveal
          ? (partnerAnswer || null)
          : (partnerAnswer ? { answered: true } : null),
        bothAnswered,
        canReveal,
      },
      wishlist: { items: wishlistItems },
      doodle: { doodle: latestDoodle },
      badges: {
        unreadChatCount: chatUnreadCount,
        unseenFeedCount: feedUnseenCount,
      },
      notifications: { unreadCount: notificationUnreadCount },
      widgets: {
        month,
        todaySchedule: formatSchedule(todayEvents),
      },
    });
  } catch (err) {
    console.error('GET /home/summary error:', err);
    res.status(500).json({ error: '홈 데이터를 불러오지 못했습니다.' });
  }
});

export default router;

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

    const start = new Date(`${localDate}T00:00:00.000Z`);
    const end = new Date(start);
    end.setUTCDate(end.getUTCDate() + 1);

    // 읽기 전용 쿼리들은 트랜잭션 격리가 필요 없으므로 Promise.all로 병렬 실행
    const [
      couple,
      moods,
      fortune,
      wishlistItems,
      latestDoodle,
      notificationUnreadCount,
      chatUnreadCount,
      feedUnseenCount,
      todayEvents,
    ] = await Promise.all([
      prisma.couple.findUnique({
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
      }),
      prisma.mood.findMany({
        where: { coupleId, date: moodDate },
        include: { user: { select: { id: true, nickname: true, profileImage: true } } },
      }),
      prisma.fortune.findUnique({
        where: { coupleId_date: { coupleId, date: missionToday } },
      }),
      prisma.wishItem.findMany({
        where: { coupleId },
        orderBy: [
          { isFavorite: 'desc' },
          { isCompleted: 'asc' },
          { createdAt: 'desc' },
        ],
      }),
      prisma.doodle.findFirst({
        where: { receiverId: userId },
        orderBy: { createdAt: 'desc' },
        include: { sender: { select: { id: true, nickname: true } } },
      }),
      prisma.notification.count({
        where: { userId, isRead: false },
      }),
      prisma.message.count({
        where: {
          coupleId,
          senderId: { not: userId },
          isRead: false,
        },
      }),
      prisma.feed.count({
        where: {
          coupleId,
          authorId: { not: userId },
          ...(lastSeenFeedAt && { createdAt: { gt: new Date(lastSeenFeedAt) } }),
        },
      }),
      prisma.calendarEvent.findMany({
        where: {
          coupleId,
          OR: [
            // 오늘 날짜의 단발 일정
            { date: { gte: start, lt: end }, repeatType: 'NONE' },
            // 반복 일정은 전부 가져와 아래에서 오늘 해당분만 필터
            { repeatType: 'YEARLY' },
            { repeatType: 'MONTHLY' },
          ],
        },
        orderBy: { date: 'asc' },
      }),
    ]);

    // 반복 일정(매년/매월)이 오늘에 해당하면 "오늘의 일정"에 포함.
    // (캘린더 화면은 반복을 펼쳐 보여주는데 홈 위젯은 누락하던 문제)
    const todayMonth = start.getUTCMonth();
    const todayDay = start.getUTCDate();
    const todayScheduleEvents = todayEvents.filter((ev) => {
      if (ev.repeatType === 'YEARLY') {
        return ev.date.getUTCMonth() === todayMonth &&
          ev.date.getUTCDate() === todayDay;
      }
      if (ev.repeatType === 'MONTHLY') {
        return ev.date.getUTCDate() === todayDay;
      }
      return true; // NONE: 이미 오늘 윈도우로 필터됨
    });

    // 멱등 upsert/cleanup 쓰기 — 트랜잭션 격리 없이 병렬 실행
    const [daily, weekly, , dailyQuestion] = await Promise.all([
      prisma.coupleMission.upsert({
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
      }),
      prisma.coupleMission.upsert({
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
      }),
      prisma.dailyQuestion.deleteMany({
        where: {
          coupleId,
          date: { lt: questionTodayDate },
          answers: { none: {} },
        },
      }),
      prisma.dailyQuestion.upsert({
        where: { coupleId_date: { coupleId, date: questionTodayDate } },
        update: {},
        create: { coupleId, questionIdx, date: questionTodayDate },
        include: {
          answers: {
            select: { id: true, userId: true, answer: true, createdAt: true },
          },
        },
      }),
    ]);

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
        todaySchedule: formatSchedule(todayScheduleEvents),
      },
    });
  } catch (err) {
    console.error('GET /home/summary error:', err);
    res.status(500).json({ error: '홈 데이터를 불러오지 못했습니다.' });
  }
});

export default router;

import { Router } from 'express';
import prisma from '../utils/prisma.js';
import { authenticate } from '../middleware/auth.js';

const router = Router();
router.use(authenticate);

// ─── Mission Pools ───────────────────────────────────────────────

const DAILY_MISSIONS = [
  { emoji: '💬', title: '칭찬 릴레이', description: '상대방에게 칭찬 3가지를 채팅으로 보내보세요' },
  { emoji: '💕', title: '사랑 고백', description: '"사랑해"라고 진심을 담아 메시지를 보내보세요' },
  { emoji: '🙏', title: '감사 표현', description: '오늘 상대방에게 감사한 점을 공유해보세요' },
  { emoji: '🌅', title: '좋은 아침 인사', description: '상대방에게 따뜻한 아침 인사를 보내보세요' },
  { emoji: '🎵', title: '노래 공유', description: '상대방이 좋아할 만한 노래를 추천해보세요' },
  { emoji: '📸', title: '추억 사진 공유', description: '함께한 추억 사진을 하나 공유해보세요' },
  { emoji: '💪', title: '응원 메시지', description: '상대방에게 오늘 하루 응원 메시지를 보내보세요' },
  { emoji: '😂', title: '웃음 선물', description: '상대방이 웃을 만한 재미있는 이야기를 보내보세요' },
  { emoji: '🍽️', title: '맛있는 거 자랑', description: '오늘 먹은 맛있는 음식 사진을 공유해보세요' },
  { emoji: '💌', title: '짧은 편지', description: '상대방에게 짧은 편지를 작성해보세요' },
  { emoji: '🤔', title: '하루 일과 물어보기', description: '상대방의 하루가 어땠는지 물어봐주세요' },
  { emoji: '🌟', title: '장점 발견', description: '상대방의 매력 포인트 하나를 피드에 올려보세요' },
  { emoji: '📝', title: '기분 나누기', description: '오늘의 기분을 서로 공유해보세요' },
  { emoji: '🎯', title: '내일 데이트 계획', description: '다음에 만나면 하고 싶은 것을 이야기해보세요' },
];

const WEEKLY_MISSIONS = [
  { emoji: '🚶', title: '함께 산책', description: '함께 산책하고 인증 사진을 남겨보세요' },
  { emoji: '🍳', title: '같이 요리', description: '함께 요리를 해서 먹어보세요' },
  { emoji: '☕', title: '새로운 카페 탐방', description: '안 가본 카페에 함께 가보세요' },
  { emoji: '🎬', title: '영화 관람', description: '함께 영화를 보고 감상을 나눠보세요' },
  { emoji: '🤳', title: '커플 셀카', description: '오늘의 커플 셀카를 찍어보세요' },
  { emoji: '🏃', title: '함께 운동', description: '같이 운동을 하고 인증해보세요' },
  { emoji: '🍜', title: '맛집 도전', description: '새로운 맛집을 함께 도전해보세요' },
  { emoji: '🧺', title: '공원 피크닉', description: '공원에서 함께 피크닉을 즐겨보세요' },
  { emoji: '🎁', title: '작은 선물', description: '서로에게 작은 선물을 준비해보세요' },
  { emoji: '🌅', title: '일출/일몰 감상', description: '함께 일출이나 일몰을 감상해보세요' },
];

// ─── Helpers ─────────────────────────────────────────────────────

function getMonday(d) {
  const date = new Date(d);
  date.setUTCHours(0, 0, 0, 0);
  const day = date.getUTCDay();
  const diff = day === 0 ? -6 : 1 - day;
  date.setUTCDate(date.getUTCDate() + diff);
  return date;
}

function getToday() {
  const d = new Date();
  d.setUTCHours(0, 0, 0, 0);
  return d;
}

function pickMission(pool, coupleId, dateStr) {
  // Simple hash from coupleId + dateStr
  let hash = 0;
  const seed = coupleId + dateStr;
  for (let i = 0; i < seed.length; i++) {
    hash = ((hash << 5) - hash) + seed.charCodeAt(i);
    hash |= 0;
  }
  return pool[Math.abs(hash) % pool.length];
}

// ─── GET / ── Today's daily + this week's weekly mission ─────────

router.get('/', async (req, res) => {
  try {
    const coupleId = req.user.coupleId;
    if (!coupleId) return res.status(400).json({ message: '커플 연결이 필요합니다.' });

    const today = getToday();
    const monday = getMonday(today);
    const todayStr = today.toISOString().split('T')[0];
    const mondayStr = monday.toISOString().split('T')[0];

    // Upsert daily mission
    let daily = await prisma.coupleMission.findUnique({
      where: { coupleId_type_date: { coupleId, type: 'DAILY', date: today } },
    });
    if (!daily) {
      const pick = pickMission(DAILY_MISSIONS, coupleId, todayStr);
      daily = await prisma.coupleMission.create({
        data: { coupleId, type: 'DAILY', date: today, title: pick.title, description: pick.description, emoji: pick.emoji },
      });
    }

    // Upsert weekly mission
    let weekly = await prisma.coupleMission.findUnique({
      where: { coupleId_type_date: { coupleId, type: 'WEEKLY', date: monday } },
    });
    if (!weekly) {
      const pick = pickMission(WEEKLY_MISSIONS, coupleId, mondayStr);
      weekly = await prisma.coupleMission.create({
        data: { coupleId, type: 'WEEKLY', date: monday, title: pick.title, description: pick.description, emoji: pick.emoji },
      });
    }

    res.json({ daily, weekly });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ─── PATCH /:id/complete ── Mark mission as complete ─────────────

router.patch('/:id/complete', async (req, res) => {
  try {
    const mission = await prisma.coupleMission.findUnique({ where: { id: req.params.id } });
    if (!mission) return res.status(404).json({ message: '미션을 찾을 수 없습니다.' });
    if (mission.coupleId !== req.user.coupleId) return res.status(403).json({ message: '권한이 없습니다.' });
    if (mission.isCompleted) return res.json({ mission });

    const updated = await prisma.coupleMission.update({
      where: { id: req.params.id },
      data: { isCompleted: true, completedBy: req.user.id, completedAt: new Date() },
    });

    // Send push notification to partner
    const { notifyPartner } = await import('../utils/firebase.js');
    const user = await prisma.user.findUnique({ where: { id: req.user.id }, select: { nickname: true } });
    const typeLabel = mission.type === 'DAILY' ? '오늘의 미션' : '주간 미션';
    notifyPartner({
      userId: req.user.id,
      coupleId: req.user.coupleId,
      title: `${typeLabel} 완료!`,
      body: `${user?.nickname || '상대방'}님이 "${mission.title}" 미션을 완료했어요!`,
      data: { type: 'mission' },
    });

    // Socket: 실시간 미션 완료 이벤트
    const io = req.app.get('io');
    if (io) {
      io.to(`couple:${req.user.coupleId}`).emit('mission:complete', { mission: updated });
    }

    res.json({ mission: updated });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ─── PATCH /:id/cancel ── Cancel mission completion ──────────────

router.patch('/:id/cancel', async (req, res) => {
  try {
    const mission = await prisma.coupleMission.findUnique({ where: { id: req.params.id } });
    if (!mission) return res.status(404).json({ message: '미션을 찾을 수 없습니다.' });
    if (mission.coupleId !== req.user.coupleId) return res.status(403).json({ message: '권한이 없습니다.' });
    if (!mission.isCompleted) return res.json({ mission });

    const updated = await prisma.coupleMission.update({
      where: { id: req.params.id },
      data: { isCompleted: false, completedBy: null, completedAt: null },
    });

    // Socket: 실시간 미션 취소 이벤트
    const io = req.app.get('io');
    if (io) {
      io.to(`couple:${req.user.coupleId}`).emit('mission:cancel', { mission: updated });
    }

    res.json({ mission: updated });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ─── GET /calendar ── Completed missions for calendar display ────

router.get('/calendar', async (req, res) => {
  try {
    const coupleId = req.user.coupleId;
    if (!coupleId) return res.status(400).json({ message: '커플 연결이 필요합니다.' });

    const { month } = req.query; // 'YYYY-MM'
    if (!month) return res.status(400).json({ message: 'month 파라미터가 필요합니다.' });

    const [year, mon] = month.split('-').map(Number);
    const start = new Date(Date.UTC(year, mon - 1, 1));
    const end = new Date(Date.UTC(year, mon, 0, 23, 59, 59, 999));

    const missions = await prisma.coupleMission.findMany({
      where: {
        coupleId,
        isCompleted: true,
        date: { gte: start, lte: end },
      },
      select: { id: true, type: true, title: true, description: true, emoji: true, date: true, isCompleted: true, completedAt: true, completedBy: true },
      orderBy: { date: 'asc' },
    });

    // Group by mission date (assignment date)
    const byDate = {};
    missions.forEach(m => {
      const dateKey = m.date.toISOString().split('T')[0];
      if (!byDate[dateKey]) byDate[dateKey] = [];
      byDate[dateKey].push(m);
    });

    res.json({ completedDates: byDate });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ─── GET /history ── Past missions with cursor pagination ────────

router.get('/history', async (req, res) => {
  try {
    const coupleId = req.user.coupleId;
    if (!coupleId) return res.status(400).json({ message: '커플 연결이 필요합니다.' });

    const { cursor, limit = '20' } = req.query;
    const take = Math.min(parseInt(limit) || 20, 50);

    const missions = await prisma.coupleMission.findMany({
      where: { coupleId },
      orderBy: { date: 'desc' },
      take: take + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });

    const hasMore = missions.length > take;
    if (hasMore) missions.pop();

    res.json({
      missions,
      hasMore,
      nextCursor: hasMore ? missions[missions.length - 1].id : null,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

export default router;

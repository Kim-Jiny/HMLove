import { Router } from 'express';
import { authenticate, requireCouple } from '../middleware/auth.js';
import prisma from '../utils/prisma.js';
import { notifyPartner } from '../utils/firebase.js';

const router = Router();
router.use(authenticate, requireCouple);

const MAX_CONTENT = 5000;
const KINDS = ['SHARED', 'PRIVATE'];

const authorSelect = { select: { id: true, nickname: true } };

function parseDate(v) {
  if (v === undefined || v === null || v === '') return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? undefined : d;
}

// 교환일기는 둘 다, 개인일기는 쓴 사람만 볼 수 있다.
function visibleWhere(req, kind) {
  const base = { coupleId: req.user.coupleId, kind };
  return kind === 'PRIVATE' ? { ...base, authorId: req.user.id } : base;
}

// GET /diary?scope=shared|mine&cursor=&limit=
router.get('/', async (req, res) => {
  try {
    const scope = req.query.scope;
    const kind = { shared: 'SHARED', mine: 'PRIVATE' }[scope];
    if (!kind) return res.status(400).json({ error: 'scope 가 올바르지 않습니다.' });
    const limit = Math.min(parseInt(req.query.limit) || 20, 50);
    const cursor = req.query.cursor;

    const entries = await prisma.diaryEntry.findMany({
      where: visibleWhere(req, kind),
      orderBy: [{ entryDate: 'desc' }, { createdAt: 'desc' }],
      take: limit + 1,
      ...(cursor && { cursor: { id: cursor }, skip: 1 }),
      include: { author: authorSelect },
    });
    const hasMore = entries.length > limit;
    if (hasMore) entries.pop();
    res.json({
      entries,
      hasMore,
      nextCursor: hasMore ? entries[entries.length - 1].id : null,
    });
  } catch (err) {
    console.error('GET /diary error:', err);
    res.status(500).json({ error: '일기를 불러오지 못했습니다.' });
  }
});

// POST /diary { kind, content, mood?, entryDate? }
router.post('/', async (req, res) => {
  try {
    const { kind = 'SHARED', mood } = req.body ?? {};
    const content = typeof req.body?.content === 'string' ? req.body.content.trim() : '';
    if (!KINDS.includes(kind)) return res.status(400).json({ error: '일기 종류가 올바르지 않습니다.' });
    if (!content) return res.status(400).json({ error: '내용을 입력해 주세요.' });
    if (content.length > MAX_CONTENT) {
      return res.status(400).json({ error: `일기는 ${MAX_CONTENT}자까지 쓸 수 있어요.` });
    }
    const entryDate = parseDate(req.body?.entryDate);
    if (entryDate === undefined) {
      return res.status(400).json({ error: '날짜가 올바르지 않습니다.' });
    }

    const entry = await prisma.diaryEntry.create({
      data: {
        coupleId: req.user.coupleId,
        authorId: req.user.id,
        kind,
        content,
        mood: typeof mood === 'string' && mood.length <= 20 ? mood : null,
        ...(entryDate && { entryDate }),
      },
      include: { author: authorSelect },
    });

    if (kind === 'SHARED') {
      notifyPartner({
        userId: req.user.id,
        coupleId: req.user.coupleId,
        title: '교환일기',
        body: `${req.user.nickname || '상대방'}님이 교환일기를 썼어요`,
        data: { type: 'diary', diaryId: entry.id },
      }).catch((e) => console.error('diary notify error:', e));
    }

    res.status(201).json({ entry });
  } catch (err) {
    console.error('POST /diary error:', err);
    res.status(500).json({ error: '일기를 저장하지 못했습니다.' });
  }
});

// PATCH /diary/:id — 내가 쓴 일기만
router.patch('/:id', async (req, res) => {
  try {
    const existing = await prisma.diaryEntry.findFirst({
      where: { id: req.params.id, coupleId: req.user.coupleId, authorId: req.user.id },
    });
    if (!existing) return res.status(404).json({ error: '일기를 찾을 수 없습니다.' });

    const data = {};
    if (req.body?.content !== undefined) {
      const content = typeof req.body.content === 'string' ? req.body.content.trim() : '';
      if (!content || content.length > MAX_CONTENT) {
        return res.status(400).json({ error: '내용이 올바르지 않습니다.' });
      }
      data.content = content;
    }
    if (req.body?.mood !== undefined) {
      data.mood = typeof req.body.mood === 'string' && req.body.mood.length <= 20 ? req.body.mood : null;
    }
    if (req.body?.entryDate !== undefined) {
      const d = parseDate(req.body.entryDate);
      if (!d) return res.status(400).json({ error: '날짜가 올바르지 않습니다.' });
      data.entryDate = d;
    }
    const entry = await prisma.diaryEntry.update({
      where: { id: existing.id },
      data,
      include: { author: authorSelect },
    });
    res.json({ entry });
  } catch (err) {
    console.error('PATCH /diary error:', err);
    res.status(500).json({ error: '일기를 수정하지 못했습니다.' });
  }
});

// DELETE /diary/:id — 내가 쓴 일기만
router.delete('/:id', async (req, res) => {
  try {
    const { count } = await prisma.diaryEntry.deleteMany({
      where: { id: req.params.id, coupleId: req.user.coupleId, authorId: req.user.id },
    });
    if (!count) return res.status(404).json({ error: '일기를 찾을 수 없습니다.' });
    res.json({ ok: true });
  } catch (err) {
    console.error('DELETE /diary error:', err);
    res.status(500).json({ error: '일기를 삭제하지 못했습니다.' });
  }
});

export default router;

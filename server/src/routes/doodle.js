import { Router } from 'express';
import multer from 'multer';
import sharp from 'sharp';
import { authenticate, requireCouple } from '../middleware/auth.js';
import prisma from '../utils/prisma.js';
import { uploadFile, deleteFile } from '../utils/storage.js';
import { notifyPartner, notifyPartnerSilent } from '../utils/firebase.js';

const router = Router();
router.use(authenticate, requireCouple);

// 메모리에 버퍼로 받기 → 정사각형 PNG로 표준화 후 업로드
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) cb(null, true);
    else cb(new Error('이미지 파일만 업로드 가능합니다.'));
  },
});

function getUploadedDoodleFile(req) {
  if (req.file) return req.file;
  return req.files?.image?.[0] || req.files?.doodle?.[0] || null;
}

// GET /doodle?cursor=xxx&limit=30  → 받은/보낸 그림 히스토리(최신순)
router.get('/', async (req, res) => {
  try {
    const { cursor } = req.query;
    const limit = Math.min(parseInt(req.query.limit) || 30, 100);

    const doodles = await prisma.doodle.findMany({
      where: { coupleId: req.user.coupleId },
      orderBy: { createdAt: 'desc' },
      take: limit + 1,
      ...(cursor && { cursor: { id: cursor }, skip: 1 }),
      include: {
        sender: { select: { id: true, nickname: true } },
        receiver: { select: { id: true, nickname: true } },
      },
    });

    const hasMore = doodles.length > limit;
    if (hasMore) doodles.pop();
    const nextCursor = hasMore ? doodles[doodles.length - 1].id : null;

    res.json({ doodles, hasMore, nextCursor });
  } catch (err) {
    console.error('Get doodles error:', err);
    res.status(500).json({ error: '그림 조회에 실패했습니다.' });
  }
});

// GET /doodle/latest → 내가 마지막으로 받은 그림 1장(위젯/홈 미리보기용)
router.get('/latest', async (req, res) => {
  try {
    const doodle = await prisma.doodle.findFirst({
      where: { receiverId: req.user.id },
      orderBy: { createdAt: 'desc' },
      include: {
        sender: { select: { id: true, nickname: true } },
      },
    });
    res.json({ doodle });
  } catch (err) {
    console.error('Get latest doodle error:', err);
    res.status(500).json({ error: '최신 그림 조회에 실패했습니다.' });
  }
});

// POST /doodle  (multipart: image)
router.post(
  '/',
  upload.fields([
    { name: 'image', maxCount: 1 },
    { name: 'doodle', maxCount: 1 },
  ]),
  async (req, res) => {
    try {
      const file = getUploadedDoodleFile(req);
      if (!file) {
        return res.status(400).json({ error: '그림을 첨부해주세요.' });
      }

      // 상대방 찾기
      const partner = await prisma.user.findFirst({
        where: { coupleId: req.user.coupleId, id: { not: req.user.id } },
        select: { id: true, nickname: true },
      });
      if (!partner) {
        return res.status(400).json({ error: '커플 상대방이 없습니다.' });
      }

      // 2x2 위젯에서만 사용 → 512px 정사각형 + 팔레트 PNG로 표준화.
      // 선화 위주라 팔레트(인덱스 컬러) PNG가 트루컬러 대비 수십 KB 단위로 줄어듦.
      // (Android RemoteViews IPC 한도, 모바일 데이터 사용량, 위젯 디스크 캐시 절약 모두에 유리)
      const pngBuffer = await sharp(file.buffer)
        .resize(512, 512, { fit: 'cover' })
        .png({
          compressionLevel: 9,
          palette: true,
          quality: 80,
          effort: 7,
        })
        .toBuffer();

      const timestamp = Date.now();
      const rand = Math.random().toString(36).slice(2);
      const key = `doodles/${timestamp}-${rand}.png`;
      const imageUrl = await uploadFile(pngBuffer, key, 'image/png');

      const doodle = await prisma.doodle.create({
        data: {
          coupleId: req.user.coupleId,
          senderId: req.user.id,
          receiverId: partner.id,
          imageUrl,
        },
        include: {
          sender: { select: { id: true, nickname: true } },
          receiver: { select: { id: true, nickname: true } },
        },
      });

      // 상대방에게 푸시 알림 + 위젯 갱신용 silent 푸시
      notifyPartner({
        userId: req.user.id,
        coupleId: req.user.coupleId,
        title: req.user.nickname || '상대방',
        body: '🎨 그림이 도착했어요!',
        data: { type: 'doodle', doodleId: doodle.id },
        silentData: { type: 'doodle_widget_refresh', doodleId: doodle.id },
      });

      res.status(201).json({ doodle });
    } catch (err) {
      console.error('Upload doodle error:', err);
      res.status(500).json({ error: '그림 전송에 실패했습니다.' });
    }
  },
);

// DELETE /doodle/:id  (보낸 사람만 삭제 가능)
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const doodle = await prisma.doodle.findUnique({ where: { id } });
    if (!doodle || doodle.coupleId !== req.user.coupleId) {
      return res.status(404).json({ error: '그림을 찾을 수 없습니다.' });
    }
    if (doodle.senderId !== req.user.id) {
      return res.status(403).json({ error: '본인이 보낸 그림만 삭제할 수 있습니다.' });
    }

    const key = doodle.imageUrl.split('/').slice(-2).join('/');
    await Promise.allSettled([deleteFile(key)]);
    await prisma.doodle.delete({ where: { id } });

    // 상대방 위젯이 마지막 그림을 표시 중이었다면 삭제 후 latest/empty 상태로 갱신.
    // 오래된 그림 삭제여도 최신 데이터를 재조회하는 정도라 안전하다.
    await notifyPartnerSilent({
      userId: req.user.id,
      coupleId: req.user.coupleId,
      data: { type: 'doodle_widget_refresh', doodleId: id, action: 'deleted' },
    });

    res.json({ message: '그림이 삭제되었습니다.' });
  } catch (err) {
    console.error('Delete doodle error:', err);
    res.status(500).json({ error: '그림 삭제에 실패했습니다.' });
  }
});

export default router;

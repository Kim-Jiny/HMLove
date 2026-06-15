import { Router } from 'express';
import multer from 'multer';
import sharp from 'sharp';
import ExifParser from 'exif-parser';
import { authenticate, requireCouple } from '../middleware/auth.js';
import prisma from '../utils/prisma.js';
import { loadCoupleOwned } from '../utils/coupleScope.js';
import { uploadFile, deleteFile } from '../utils/storage.js';

const router = Router();
router.use(authenticate, requireCouple);

// 메모리에 버퍼로 받기 (MinIO Storage로 업로드)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 20 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) cb(null, true);
    else cb(new Error('이미지 파일만 업로드 가능합니다.'));
  },
});

function getUploadedPhotoFile(req) {
  if (req.file) return req.file;

  const imageFile = req.files?.image?.[0];
  if (imageFile) return imageFile;

  const photoFile = req.files?.photo?.[0];
  if (photoFile) return photoFile;

  return null;
}

function extractExifGps(buffer) {
  try {
    const parser = ExifParser.create(buffer);
    const result = parser.parse();
    const { GPSLatitude, GPSLongitude, DateTimeOriginal } = result.tags;
    return {
      latitude: GPSLatitude || null,
      longitude: GPSLongitude || null,
      takenAt: DateTimeOriginal ? new Date(DateTimeOriginal * 1000) : null,
    };
  } catch {
    return { latitude: null, longitude: null, takenAt: null };
  }
}

// GET /photo?from=2026-01-01&to=2026-02-28&cursor=xxx&limit=20
router.get('/', async (req, res) => {
  try {
    const { from, to, cursor } = req.query;
    const limit = Math.min(parseInt(req.query.limit) || 20, 50);
    const where = { coupleId: req.user.coupleId };

    if (from || to) {
      where.createdAt = {};
      if (from) where.createdAt.gte = new Date(from);
      if (to) where.createdAt.lte = new Date(to + 'T23:59:59.999Z');
    }

    const photos = await prisma.photo.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: limit + 1,
      ...(cursor && { cursor: { id: cursor }, skip: 1 }),
      include: {
        author: { select: { id: true, nickname: true } },
      },
    });

    const hasMore = photos.length > limit;
    if (hasMore) photos.pop();
    const nextCursor = hasMore ? photos[photos.length - 1].id : null;

    res.json({ photos, hasMore, nextCursor });
  } catch (err) {
    console.error('Get photos error:', err);
    res.status(500).json({ error: '사진 조회에 실패했습니다.' });
  }
});

// GET /photo/map
router.get('/map', async (req, res) => {
  try {
    const photos = await prisma.photo.findMany({
      where: {
        coupleId: req.user.coupleId,
        latitude: { not: null },
        longitude: { not: null },
      },
      select: {
        id: true,
        coupleId: true,
        authorId: true,
        imageUrl: true,
        latitude: true,
        longitude: true,
        caption: true,
        address: true,
        thumbnailUrl: true,
        takenAt: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
      take: 500,
    });

    res.json({ photos });
  } catch (err) {
    console.error('Get photo map error:', err);
    res.status(500).json({ error: '지도용 사진 조회에 실패했습니다.' });
  }
});

// POST /photo
router.post(
  '/',
  upload.fields([
    { name: 'photo', maxCount: 1 },
    { name: 'image', maxCount: 1 },
  ]),
  async (req, res) => {
  try {
    const uploadedFile = getUploadedPhotoFile(req);
    if (!uploadedFile) {
      return res.status(400).json({ error: '사진을 첨부해주세요.' });
    }

    const { caption } = req.body;
    const buffer = uploadedFile.buffer;
    const timestamp = Date.now();
    const rand = Math.random().toString(36).slice(2);

    // EXIF GPS 추출
    const exif = extractExifGps(buffer);

    // 원본 EXIF 회전 적용 후 업로드
    const rotatedBuffer = await sharp(buffer)
      .rotate()
      .toBuffer();
    const fileName = `photos/${timestamp}-${rand}.jpg`;
    const imageUrl = await uploadFile(rotatedBuffer, fileName, uploadedFile.mimetype);

    // 썸네일 생성 + 업로드
    const thumbBuffer = await sharp(rotatedBuffer)
      .resize(300, 300, { fit: 'cover' })
      .jpeg({ quality: 80 })
      .toBuffer();
    const thumbName = `thumbnails/${timestamp}-${rand}.jpg`;
    const thumbnailUrl = await uploadFile(thumbBuffer, thumbName, 'image/jpeg');

    const photo = await prisma.photo.create({
      data: {
        coupleId: req.user.coupleId,
        authorId: req.user.id,
        imageUrl,
        thumbnailUrl,
        caption,
        latitude: exif.latitude,
        longitude: exif.longitude,
        takenAt: exif.takenAt,
      },
      include: {
        author: { select: { id: true, nickname: true } },
      },
    });

    // 하위 호환: 구버전 앱은 top-level photo 객체를, 신버전은 nested photo를 읽을 수 있음
    res.status(201).json({ ...photo, photo });
  } catch (err) {
    console.error('Upload photo error:', err);
    res.status(500).json({ error: '사진 업로드에 실패했습니다.' });
  }
});

// DELETE /photo/:id
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const photo = await loadCoupleOwned(prisma.photo, id, req.user.coupleId);
    if (!photo) {
      return res.status(404).json({ error: '사진을 찾을 수 없습니다.' });
    }
    if (photo.authorId !== req.user.id) {
      return res.status(403).json({ error: '본인이 업로드한 사진만 삭제할 수 있습니다.' });
    }

    // MinIO Storage에서 파일 삭제
    const imageKey = photo.imageUrl.split('/').slice(-2).join('/');
    const thumbKey = photo.thumbnailUrl.split('/').slice(-2).join('/');
    await Promise.allSettled([deleteFile(imageKey), deleteFile(thumbKey)]);

    await prisma.photo.delete({ where: { id } });
    res.json({ message: '사진이 삭제되었습니다.' });
  } catch (err) {
    console.error('Delete photo error:', err);
    res.status(500).json({ error: '사진 삭제에 실패했습니다.' });
  }
});

export default router;

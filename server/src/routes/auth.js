import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import multer from 'multer';
import sharp from 'sharp';
import { mkdirSync, existsSync } from 'fs';
import prisma from '../utils/prisma.js';
import { getZodiacSign, getChineseZodiac } from '../utils/zodiac.js';
import { authenticate } from '../middleware/auth.js';

const PROFILE_DIR = 'uploads/profile';
if (!existsSync(PROFILE_DIR)) mkdirSync(PROFILE_DIR, { recursive: true });

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) cb(null, true);
    else cb(new Error('이미지 파일만 업로드 가능합니다.'));
  },
});

const router = Router();

function generateAccessToken(userId) {
  return jwt.sign({ userId }, process.env.JWT_SECRET, { expiresIn: '1h' });
}

function generateRefreshToken(userId) {
  return jwt.sign({ userId, type: 'refresh' }, process.env.JWT_REFRESH_SECRET, { expiresIn: '30d' });
}

// POST /auth/register
router.post('/register', async (req, res) => {
  try {
    const { email, password, nickname, birthDate } = req.body;

    if (!email || !password || !nickname) {
      return res.status(400).json({ error: '이메일, 비밀번호, 닉네임을 입력해주세요.' });
    }

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      return res.status(409).json({ error: '이미 사용 중인 이메일입니다.' });
    }

    const hashedPassword = await bcrypt.hash(password, 12);
    const birth = birthDate ? new Date(birthDate) : null;
    const zodiacSign = birth ? getZodiacSign(birth) : null;
    const chineseZodiac = birth ? getChineseZodiac(birth) : null;

    const user = await prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        nickname,
        ...(birth && { birthDate: birth }),
        ...(zodiacSign && { zodiacSign }),
        ...(chineseZodiac && { chineseZodiac }),
      },
      select: { id: true, email: true, nickname: true, profileImage: true, birthDate: true, zodiacSign: true, chineseZodiac: true, coupleId: true, createdAt: true, updatedAt: true },
    });

    const accessToken = generateAccessToken(user.id);
    const refreshToken = generateRefreshToken(user.id);

    res.status(201).json({ user, accessToken, refreshToken });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ error: '회원가입에 실패했습니다.' });
  }
});

// POST /auth/login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: '이메일과 비밀번호를 입력해주세요.' });
    }

    const user = await prisma.user.findUnique({
      where: { email },
      include: { couple: { select: { inviteCode: true, _count: { select: { users: true } } } } },
    });
    if (!user) {
      return res.status(401).json({ error: '이메일 또는 비밀번호가 올바르지 않습니다.' });
    }

    const valid = await bcrypt.compare(password, user.password);
    if (!valid) {
      return res.status(401).json({ error: '이메일 또는 비밀번호가 올바르지 않습니다.' });
    }

    const accessToken = generateAccessToken(user.id);
    const refreshToken = generateRefreshToken(user.id);

    const isCoupleComplete = user.couple ? user.couple._count.users >= 2 : false;
    const pendingInviteCode = (user.couple && !isCoupleComplete) ? user.couple.inviteCode : null;

    res.json({
      user: {
        id: user.id,
        email: user.email,
        nickname: user.nickname,
        profileImage: user.profileImage,
        birthDate: user.birthDate,
        coupleId: user.coupleId,
        zodiacSign: user.zodiacSign,
        chineseZodiac: user.chineseZodiac,
        isCoupleComplete,
        pendingInviteCode,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      accessToken,
      refreshToken,
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: '로그인에 실패했습니다.' });
  }
});

// GET /auth/me - 현재 로그인한 유저 정보
router.get('/me', async (req, res) => {
  try {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      return res.status(401).json({ error: '인증 토큰이 필요합니다.' });
    }

    const token = header.split(' ')[1];
    const payload = jwt.verify(token, process.env.JWT_SECRET);

    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
      select: {
        id: true,
        email: true,
        nickname: true,
        profileImage: true,
        birthDate: true,
        zodiacSign: true,
        chineseZodiac: true,
        coupleId: true,
        createdAt: true,
        updatedAt: true,
        couple: { select: { inviteCode: true, _count: { select: { users: true } } } },
      },
    });

    if (!user) {
      return res.status(401).json({ error: '유효하지 않은 사용자입니다.' });
    }

    const { couple, ...userData } = user;
    const isCoupleComplete = couple ? couple._count.users >= 2 : false;
    const pendingInviteCode = (couple && !isCoupleComplete) ? couple.inviteCode : null;

    res.json({ ...userData, isCoupleComplete, pendingInviteCode });
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: '토큰이 만료되었습니다.' });
    }
    res.status(401).json({ error: '유효하지 않은 토큰입니다.' });
  }
});

// POST /auth/refresh
router.post('/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({ error: '리프레시 토큰이 필요합니다.' });
    }

    const payload = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
    if (payload.type !== 'refresh') {
      return res.status(401).json({ error: '유효하지 않은 토큰입니다.' });
    }

    const user = await prisma.user.findUnique({ where: { id: payload.userId } });
    if (!user) {
      return res.status(401).json({ error: '유효하지 않은 사용자입니다.' });
    }

    const accessToken = generateAccessToken(user.id);
    res.json({ accessToken });
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: '리프레시 토큰이 만료되었습니다. 다시 로그인해주세요.' });
    }
    res.status(401).json({ error: '유효하지 않은 토큰입니다.' });
  }
});

// POST /auth/fcm-token — FCM 토큰 저장
router.post('/fcm-token', async (req, res) => {
  try {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      return res.status(401).json({ error: '인증 토큰이 필요합니다.' });
    }

    const token = header.split(' ')[1];
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    const { fcmToken } = req.body;

    if (!fcmToken) {
      return res.status(400).json({ error: 'FCM 토큰이 필요합니다.' });
    }

    await prisma.user.update({
      where: { id: payload.userId },
      data: { fcmToken },
    });

    res.json({ message: 'FCM 토큰이 저장되었습니다.' });
  } catch (err) {
    console.error('FCM token error:', err);
    res.status(500).json({ error: 'FCM 토큰 저장에 실패했습니다.' });
  }
});

// PATCH /auth/profile — 프로필 수정
router.patch('/profile', authenticate, async (req, res) => {
  try {
    const { nickname, birthDate } = req.body;
    const data = {};

    if (nickname && nickname.trim().length > 0) {
      data.nickname = nickname.trim();
    }
    if (birthDate) {
      const birth = new Date(birthDate);
      data.birthDate = birth;
      data.zodiacSign = getZodiacSign(birth);
      data.chineseZodiac = getChineseZodiac(birth);
    }

    if (Object.keys(data).length === 0) {
      return res.status(400).json({ error: '수정할 항목이 없습니다.' });
    }

    const user = await prisma.user.update({
      where: { id: req.user.id },
      data,
      select: {
        id: true, email: true, nickname: true, profileImage: true,
        birthDate: true, zodiacSign: true, chineseZodiac: true,
        coupleId: true, createdAt: true, updatedAt: true,
      },
    });

    res.json({ user });
  } catch (err) {
    console.error('Update profile error:', err);
    res.status(500).json({ error: '프로필 수정에 실패했습니다.' });
  }
});

// POST /auth/profile/image — 프로필 이미지 업로드
router.post('/profile/image', authenticate, upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: '이미지를 첨부해주세요.' });
    }

    const fileName = `${Date.now()}_${req.user.id}.webp`;
    const filePath = `${PROFILE_DIR}/${fileName}`;

    await sharp(req.file.buffer)
      .resize(400, 400, { fit: 'cover' })
      .webp({ quality: 80 })
      .toFile(filePath);

    const baseUrl = `${req.protocol}://${req.get('host')}`;
    const imageUrl = `${baseUrl}/${filePath}`;

    const user = await prisma.user.update({
      where: { id: req.user.id },
      data: { profileImage: imageUrl },
      select: {
        id: true, email: true, nickname: true, profileImage: true,
        birthDate: true, zodiacSign: true, chineseZodiac: true,
        coupleId: true, createdAt: true, updatedAt: true,
      },
    });

    res.json({ user });
  } catch (err) {
    console.error('Upload profile image error:', err);
    res.status(500).json({ error: '이미지 업로드에 실패했습니다.' });
  }
});

export default router;

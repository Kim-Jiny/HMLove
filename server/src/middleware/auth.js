import jwt from 'jsonwebtoken';
import prisma from '../utils/prisma.js';

export async function authenticate(req, res, next) {
  try {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      return res.status(401).json({ error: '인증 토큰이 필요합니다.' });
    }

    const token = header.split(' ')[1];
    const payload = jwt.verify(token, process.env.JWT_SECRET);

    const user = await prisma.user.findUnique({
      where: { id: payload.userId },
      select: { id: true, email: true, nickname: true, coupleId: true },
    });

    if (!user) {
      return res.status(401).json({ error: '유효하지 않은 사용자입니다.' });
    }

    req.user = user;
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: '토큰이 만료되었습니다.' });
    }
    return res.status(401).json({ error: '유효하지 않은 토큰입니다.' });
  }
}

/**
 * 커플 연결 여부를 확인하는 미들웨어 (authenticate 이후에 사용)
 */
export async function requireCouple(req, res, next) {
  if (!req.user.coupleId) {
    return res.status(403).json({ error: '커플 연결이 필요합니다.' });
  }
  next();
}

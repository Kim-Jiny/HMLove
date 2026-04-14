import rateLimit from 'express-rate-limit';

// 글로벌: 15분에 100회
export const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.' },
});

// 로그인/회원가입: 15분에 10회
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: '로그인 시도가 너무 많습니다. 15분 후 다시 시도해주세요.' },
});

// 운세 (Claude API): 1시간에 10회
export const fortuneLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: '운세 조회는 1시간에 10회까지 가능합니다.' },
});

// 파일 업로드: 15분에 30회
export const uploadLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: '업로드 요청이 너무 많습니다. 잠시 후 다시 시도해주세요.' },
});

import rateLimit, { ipKeyGenerator } from 'express-rate-limit';

// 글로벌: 15분에 200회
export const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 200,
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

// 그림 보내기: 1분에 10회 (사용자별). 상대 위젯/푸시가 연달아 울리는 걸 막는다.
export const doodleLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  // authenticate 이후에 쓰므로 사용자 id 로 구분하고, 없으면 IP 로 폴백
  keyGenerator: (req) => req.user?.id || ipKeyGenerator(req.ip),
  message: { error: '그림을 너무 빠르게 보내고 있어요. 잠시 후 다시 시도해주세요.' },
});

// 콕 보내기: 1분에 8회 (사용자별). 연타로 상대 기기가 계속 울리는 걸 막는다.
export const pokeLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 8,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => req.user?.id || ipKeyGenerator(req.ip),
  message: { error: '콕을 너무 빠르게 보내고 있어요. 잠시 후 다시 보내주세요.' },
});

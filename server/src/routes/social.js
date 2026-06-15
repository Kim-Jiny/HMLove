import { Router } from 'express';
import jwt from 'jsonwebtoken';
import prisma from '../utils/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { authLimiter } from '../middleware/rateLimit.js';
import { getZodiacSign, getChineseZodiac } from '../utils/zodiac.js';
import { verifySocialToken, normalizeProvider, SUPPORTED_PROVIDERS } from '../utils/socialAuth.js';

const router = Router();

const NICKNAME_MAX_LENGTH = 20;
const SIGNUP_TOKEN_TTL = '10m';

function generateAccessToken(userId) {
  return jwt.sign({ userId }, process.env.JWT_SECRET, { expiresIn: '1h' });
}

function generateRefreshToken(userId) {
  return jwt.sign({ userId, type: 'refresh' }, process.env.JWT_REFRESH_SECRET, { expiresIn: '30d' });
}

/**
 * 가입 미완료 상태 토큰. 검증된 provider 정보만 담고 짧게 살아있음.
 */
function generateSignupToken({ provider, providerId, email, name, picture }) {
  return jwt.sign(
    { type: 'social_signup', provider, providerId, email, name, picture },
    process.env.JWT_SECRET,
    { expiresIn: SIGNUP_TOKEN_TTL }
  );
}

function verifySignupToken(token) {
  const payload = jwt.verify(token, process.env.JWT_SECRET);
  if (payload.type !== 'social_signup') {
    throw new Error('잘못된 가입 토큰입니다.');
  }
  return payload;
}

async function buildLoginResponse(userId) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: {
      couple: { select: { inviteCode: true, _count: { select: { users: true } } } },
    },
  });

  const accessToken = generateAccessToken(user.id);
  const refreshToken = generateRefreshToken(user.id);

  const isCoupleComplete = user.couple ? user.couple._count.users >= 2 : false;
  const pendingInviteCode = user.couple && !isCoupleComplete ? user.couple.inviteCode : null;

  let hasExistingCoupleData = false;
  if (user.coupleId && !isCoupleComplete) {
    const dataCheck =
      (await prisma.feed.findFirst({ where: { coupleId: user.coupleId }, select: { id: true } })) ||
      (await prisma.message.findFirst({ where: { coupleId: user.coupleId }, select: { id: true } })) ||
      (await prisma.calendarEvent.findFirst({ where: { coupleId: user.coupleId }, select: { id: true } }));
    hasExistingCoupleData = !!dataCheck;
  }

  return {
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
      hasExistingCoupleData,
      pendingInviteCode,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    },
    accessToken,
    refreshToken,
  };
}

/**
 * POST /auth/social/login
 * body: { provider: 'GOOGLE'|'APPLE'|'KAKAO', idToken?, identityToken?, accessToken? }
 *
 * 동작:
 *   1) provider 토큰 검증
 *   2) (provider, providerId) 로 SocialAccount 조회
 *      → 있으면 그 유저로 로그인 응답
 *   3) 없으면 검증된 이메일로 User 조회
 *      → 있으면 EMAIL_EXISTS (사용자가 이메일로 로그인 후 연동 진행)
 *   4) 둘 다 없으면 needsSignup + signupToken 반환 (닉네임/생일 입력 화면으로 유도)
 */
router.post('/login', authLimiter, async (req, res) => {
  try {
    const provider = normalizeProvider(req.body?.provider);
    if (!provider) {
      return res.status(400).json({ error: '지원하지 않는 provider 입니다.' });
    }

    let verified;
    try {
      verified = await verifySocialToken(provider, req.body || {});
    } catch (err) {
      console.warn(`[Social] ${provider} 토큰 검증 실패:`, err.message);
      return res.status(401).json({ error: '소셜 인증에 실패했습니다.' });
    }

    // 검증되지 않은 이메일은 신뢰하지 않는다. 미인증 이메일로 기존 계정을 조회/연동하면
    // 공격자가 임의 이메일로 피해자 계정과 충돌시켜 계정 탈취 흐름을 유발할 수 있다.
    const trustedEmail = verified.emailVerified ? verified.email : null;

    // 1) 이미 연동된 계정 → 바로 로그인
    const existingLink = await prisma.socialAccount.findUnique({
      where: { provider_providerId: { provider, providerId: verified.providerId } },
      include: { user: { select: { id: true } } },
    });
    if (existingLink) {
      const result = await buildLoginResponse(existingLink.user.id);
      return res.json(result);
    }

    // 2) 같은 이메일 유저 존재 → 연동 안내 (사용자가 이메일 로그인 후 link)
    if (trustedEmail) {
      const userByEmail = await prisma.user.findUnique({
        where: { email: trustedEmail },
        select: { id: true },
      });
      if (userByEmail) {
        return res.status(409).json({
          error: 'EMAIL_EXISTS',
          message: '이미 가입된 이메일입니다. 로그인 후 연동해주세요.',
          email: trustedEmail,
          provider,
        });
      }
    }

    // 3) 신규 가입 → 가입 토큰 발급 (검증된 이메일만 담는다)
    const signupToken = generateSignupToken({
      provider,
      providerId: verified.providerId,
      email: trustedEmail,
      name: verified.name || null,
      picture: verified.picture || null,
    });

    return res.json({
      needsSignup: true,
      signupToken,
      profile: {
        email: trustedEmail,
        name: verified.name || null,
        picture: verified.picture || null,
        provider,
      },
    });
  } catch (err) {
    console.error('Social login error:', err);
    res.status(500).json({ error: '소셜 로그인에 실패했습니다.' });
  }
});

/**
 * POST /auth/social/complete-signup
 * body: { signupToken, nickname, birthDate? }
 *
 * /login 에서 받은 signupToken 으로 신규 유저 생성 + SocialAccount 연동.
 */
router.post('/complete-signup', authLimiter, async (req, res) => {
  try {
    const { signupToken, nickname, birthDate } = req.body || {};

    if (!signupToken) {
      return res.status(400).json({ error: '가입 토큰이 필요합니다.' });
    }
    if (!nickname || typeof nickname !== 'string' || nickname.trim().length === 0) {
      return res.status(400).json({ error: '닉네임을 입력해주세요.' });
    }
    if (nickname.length > NICKNAME_MAX_LENGTH) {
      return res.status(400).json({ error: `닉네임은 ${NICKNAME_MAX_LENGTH}자 이내로 입력해주세요.` });
    }

    let payload;
    try {
      payload = verifySignupToken(signupToken);
    } catch (err) {
      if (err.name === 'TokenExpiredError') {
        return res.status(401).json({ error: '가입 토큰이 만료되었습니다. 다시 시도해주세요.' });
      }
      return res.status(401).json({ error: '유효하지 않은 가입 토큰입니다.' });
    }

    const { provider, providerId, email: providerEmail, picture } = payload;

    // 동시 요청 / 재실행 안전성: 다시 한번 SocialAccount 확인
    const existingLink = await prisma.socialAccount.findUnique({
      where: { provider_providerId: { provider, providerId } },
      include: { user: { select: { id: true } } },
    });
    if (existingLink) {
      const result = await buildLoginResponse(existingLink.user.id);
      return res.json(result);
    }

    let birth = null;
    if (birthDate) {
      birth = new Date(birthDate);
      if (isNaN(birth.getTime()) || birth > new Date()) {
        return res.status(400).json({ error: '올바른 생년월일을 입력해주세요.' });
      }
    }

    // 이메일 처리: provider 가 이메일을 줬고 그 이메일이 비어있으면 사용.
    // 이미 같은 이메일 유저가 있으면 (race) 차단 → 사용자가 그쪽으로 로그인 후 link.
    let emailToUse = providerEmail;
    if (emailToUse) {
      const conflict = await prisma.user.findUnique({
        where: { email: emailToUse },
        select: { id: true },
      });
      if (conflict) {
        return res.status(409).json({
          error: 'EMAIL_EXISTS',
          message: '이미 가입된 이메일입니다. 로그인 후 연동해주세요.',
          email: emailToUse,
          provider,
        });
      }
    } else {
      // provider 가 이메일을 안 준 경우 (Apple 의 hide-my-email 미설정 / Kakao 동의 거부 등)
      // unique 제약 회피용 placeholder. 사용자에게는 노출하지 않음.
      emailToUse = `${provider.toLowerCase()}_${providerId}@social.local`;
    }

    const zodiacSign = birth ? getZodiacSign(birth) : null;
    const chineseZodiac = birth ? getChineseZodiac(birth) : null;

    const user = await prisma.$transaction(async (tx) => {
      const created = await tx.user.create({
        data: {
          email: emailToUse,
          password: null,
          nickname: nickname.trim(),
          ...(picture && { profileImage: picture }),
          ...(birth && { birthDate: birth }),
          ...(zodiacSign && { zodiacSign }),
          ...(chineseZodiac && { chineseZodiac }),
        },
      });
      await tx.socialAccount.create({
        data: {
          userId: created.id,
          provider,
          providerId,
          email: providerEmail || null,
        },
      });
      return created;
    });

    const result = await buildLoginResponse(user.id);
    res.status(201).json(result);
  } catch (err) {
    console.error('Social complete-signup error:', err);
    res.status(500).json({ error: '가입에 실패했습니다.' });
  }
});

/**
 * POST /auth/social/link
 * 인증된 사용자가 자신의 계정에 새 provider 를 연동.
 * body: { provider, idToken/identityToken/accessToken }
 */
router.post('/link', authenticate, async (req, res) => {
  try {
    const provider = normalizeProvider(req.body?.provider);
    if (!provider) {
      return res.status(400).json({ error: '지원하지 않는 provider 입니다.' });
    }

    let verified;
    try {
      verified = await verifySocialToken(provider, req.body || {});
    } catch (err) {
      console.warn(`[Social link] ${provider} 토큰 검증 실패:`, err.message);
      return res.status(401).json({ error: '소셜 인증에 실패했습니다.' });
    }

    // 다른 사람의 계정에 이미 연결돼있다면 차단
    const existing = await prisma.socialAccount.findUnique({
      where: { provider_providerId: { provider, providerId: verified.providerId } },
    });
    if (existing) {
      if (existing.userId === req.user.id) {
        return res.status(200).json({ message: '이미 연동된 계정입니다.', provider });
      }
      return res.status(409).json({
        error: 'ALREADY_LINKED_TO_OTHER',
        message: '이 소셜 계정은 다른 사용자에게 연결되어 있습니다.',
      });
    }

    try {
      await prisma.socialAccount.create({
        data: {
          userId: req.user.id,
          provider,
          providerId: verified.providerId,
          email: verified.email || null,
        },
      });
    } catch (err) {
      // Prisma P2002: unique 제약 위반 (이미 같은 provider 연동되어 있는 경우)
      if (err.code === 'P2002') {
        return res.status(409).json({
          error: 'PROVIDER_ALREADY_LINKED',
          message: '이미 같은 종류의 소셜 계정이 연동되어 있습니다.',
        });
      }
      throw err;
    }

    res.status(201).json({ message: '연동되었습니다.', provider });
  } catch (err) {
    console.error('Social link error:', err);
    res.status(500).json({ error: '연동에 실패했습니다.' });
  }
});

/**
 * DELETE /auth/social/:provider
 * 연동 해제. 단, 비번이 없는 유저는 마지막 provider 해제 차단 (계정 잠금 방지).
 */
router.delete('/:provider', authenticate, async (req, res) => {
  try {
    const provider = normalizeProvider(req.params.provider);
    if (!provider) {
      return res.status(400).json({ error: '지원하지 않는 provider 입니다.' });
    }

    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { password: true, socialAccounts: { select: { provider: true } } },
    });

    const linked = user.socialAccounts.map((s) => s.provider);
    if (!linked.includes(provider)) {
      return res.status(404).json({ error: '연동되어 있지 않습니다.' });
    }

    // 마지막 로그인 수단 차단
    const hasPassword = !!user.password;
    if (!hasPassword && linked.length === 1) {
      return res.status(400).json({
        error: 'LAST_LOGIN_METHOD',
        message: '비밀번호가 없는 계정은 마지막 소셜 연동을 해제할 수 없습니다. 먼저 비밀번호를 설정해주세요.',
      });
    }

    await prisma.socialAccount.deleteMany({
      where: { userId: req.user.id, provider },
    });

    res.json({ message: '연동이 해제되었습니다.', provider });
  } catch (err) {
    console.error('Social unlink error:', err);
    res.status(500).json({ error: '연동 해제에 실패했습니다.' });
  }
});

/**
 * GET /auth/social/linked
 * 현재 사용자의 연동 현황.
 */
router.get('/linked', authenticate, async (req, res) => {
  try {
    const accounts = await prisma.socialAccount.findMany({
      where: { userId: req.user.id },
      select: { provider: true, email: true, createdAt: true },
    });
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { password: true },
    });

    res.json({
      hasPassword: !!user.password,
      providers: SUPPORTED_PROVIDERS.map((p) => {
        const found = accounts.find((a) => a.provider === p);
        return {
          provider: p,
          linked: !!found,
          email: found?.email || null,
          linkedAt: found?.createdAt || null,
        };
      }),
    });
  } catch (err) {
    console.error('Social linked list error:', err);
    res.status(500).json({ error: '연동 정보 조회에 실패했습니다.' });
  }
});

export default router;

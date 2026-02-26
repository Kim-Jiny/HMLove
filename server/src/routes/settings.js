import { Router } from 'express';
import prisma from '../utils/prisma.js';

const router = Router();

// GET /settings/:key - 공개 API (인증 불필요)
router.get('/:key', async (req, res) => {
  try {
    const setting = await prisma.appSettings.findUnique({
      where: { key: req.params.key },
    });
    if (!setting) {
      return res.status(404).json({ error: '설정을 찾을 수 없습니다.' });
    }
    res.json({ key: setting.key, value: setting.value, updatedAt: setting.updatedAt });
  } catch (err) {
    console.error('Settings get error:', err);
    res.status(500).json({ error: '설정 조회에 실패했습니다.' });
  }
});

export default router;

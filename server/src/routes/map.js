import { Router } from 'express';
import { authenticate, requireCouple } from '../middleware/auth.js';

const router = Router();

const NCP_CLIENT_ID = process.env.NCP_MAP_CLIENT_ID || '';
const NCP_CLIENT_SECRET = process.env.NCP_MAP_CLIENT_SECRET || '';

// 인증 필수
router.use(authenticate, requireCouple);

// GET /api/map/static?lat=37.5665&lng=126.9780&w=600&h=300&zoom=15
router.get('/static', async (req, res) => {
  try {
    const { lat, lng, w = '600', h = '300', zoom = '15' } = req.query;
    if (!lat || !lng) {
      return res.status(400).json({ message: 'lat, lng 파라미터가 필요합니다.' });
    }

    // 숫자 검증
    if (isNaN(Number(lat)) || isNaN(Number(lng)) || isNaN(Number(w)) || isNaN(Number(h)) || isNaN(Number(zoom))) {
      return res.status(400).json({ message: '파라미터는 숫자여야 합니다.' });
    }

    if (!NCP_CLIENT_ID || !NCP_CLIENT_SECRET) {
      return res.status(500).json({ message: 'NCP Map 환경변수가 설정되지 않았습니다.' });
    }

    const url = `https://maps.apigw.ntruss.com/map-static/v2/raster`
      + `?center=${lng},${lat}`
      + `&level=${zoom}`
      + `&w=${w}&h=${h}`
      + `&maptype=basic`
      + `&markers=type:d|size:mid|pos:${lng} ${lat}|color:red`;

    const response = await fetch(url, {
      headers: {
        'X-NCP-APIGW-API-KEY-ID': NCP_CLIENT_ID,
        'X-NCP-APIGW-API-KEY': NCP_CLIENT_SECRET,
      },
    });

    if (!response.ok) {
      const text = await response.text();
      console.error('[Map] Static map error:', response.status, text);
      return res.status(response.status).json({ message: 'Static map 요청 실패' });
    }

    res.set('Content-Type', response.headers.get('content-type') || 'image/png');
    res.set('Cache-Control', 'public, max-age=86400');
    const buffer = Buffer.from(await response.arrayBuffer());
    res.send(buffer);
  } catch (err) {
    console.error('[Map] Proxy error:', err.message);
    res.status(500).json({ message: '지도 이미지 요청에 실패했습니다.' });
  }
});

export default router;

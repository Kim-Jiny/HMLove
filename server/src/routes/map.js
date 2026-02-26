import { Router } from 'express';

const router = Router();

const NCP_CLIENT_ID = process.env.NCP_MAP_CLIENT_ID || '8hmfjdafvp';
const NCP_CLIENT_SECRET = process.env.NCP_MAP_CLIENT_SECRET || '';

// GET /api/map/static?lat=37.5665&lng=126.9780&w=600&h=300&zoom=15
// → Naver Static Map 이미지를 프록시해서 반환
router.get('/static', async (req, res) => {
  try {
    const { lat, lng, w = '600', h = '300', zoom = '15' } = req.query;
    if (!lat || !lng) {
      return res.status(400).json({ message: 'lat, lng 파라미터가 필요합니다.' });
    }

    console.log('[Map] Using Client ID:', NCP_CLIENT_ID, 'Secret length:', NCP_CLIENT_SECRET.length);

    if (!NCP_CLIENT_SECRET) {
      return res.status(500).json({ message: 'NCP_MAP_CLIENT_SECRET 환경변수가 설정되지 않았습니다.' });
    }

    const url = `https://naveropenapi.apigw.ntruss.com/map-static/v2/raster`
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
      return res.status(response.status).json({ message: 'Static map 요청 실패', detail: text, naverStatus: response.status });
    }

    // 이미지 프록시
    res.set('Content-Type', response.headers.get('content-type') || 'image/png');
    res.set('Cache-Control', 'public, max-age=86400'); // 24시간 캐시
    const buffer = Buffer.from(await response.arrayBuffer());
    res.send(buffer);
  } catch (err) {
    console.error('[Map] Proxy error:', err.message);
    res.status(500).json({ message: err.message });
  }
});

// 디버그용 (나중에 제거)
router.get('/debug', (req, res) => {
  res.json({
    clientId: NCP_CLIENT_ID,
    secretLength: NCP_CLIENT_SECRET.length,
    secretPrefix: NCP_CLIENT_SECRET.substring(0, 4) + '...',
    envSet: {
      id: !!process.env.NCP_MAP_CLIENT_ID,
      secret: !!process.env.NCP_MAP_CLIENT_SECRET,
    },
  });
});

// Static Map 테스트 페이지
router.get('/test', async (req, res) => {
  const lat = req.query.lat || '37.5665';
  const lng = req.query.lng || '126.9780';
  const zoom = req.query.zoom || '15';
  const w = '600';
  const h = '300';

  const naverUrl = `https://naveropenapi.apigw.ntruss.com/map-static/v2/raster`
    + `?center=${lng},${lat}&level=${zoom}&w=${w}&h=${h}&maptype=basic`
    + `&markers=type:d|size:mid|pos:${lng} ${lat}|color:red`;

  let result = { status: null, error: null, headers: {} };

  try {
    const response = await fetch(naverUrl, {
      headers: {
        'X-NCP-APIGW-API-KEY-ID': NCP_CLIENT_ID,
        'X-NCP-APIGW-API-KEY': NCP_CLIENT_SECRET,
      },
    });
    result.status = response.status;
    result.headers = Object.fromEntries(response.headers.entries());
    if (!response.ok) {
      result.error = await response.text();
    }
  } catch (err) {
    result.error = err.message;
  }

  const isOk = result.status === 200;
  const proxyImgUrl = `/api/map/static?lat=${lat}&lng=${lng}&w=${w}&h=${h}&zoom=${zoom}`;

  res.send(`<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Static Map Test</title>
<style>
  body { font-family: -apple-system, sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; }
  h1 { color: #C2185B; }
  .status { padding: 12px 20px; border-radius: 8px; margin: 16px 0; font-weight: bold; }
  .ok { background: #E8F5E9; color: #2E7D32; }
  .fail { background: #FFEBEE; color: #C62828; }
  pre { background: #F5F5F5; padding: 16px; border-radius: 8px; overflow-x: auto; font-size: 13px; }
  img { max-width: 100%; border-radius: 8px; border: 1px solid #eee; }
  table { border-collapse: collapse; width: 100%; }
  td, th { text-align: left; padding: 8px 12px; border-bottom: 1px solid #eee; }
  th { color: #888; font-weight: normal; width: 180px; }
</style></head><body>
<h1>🗺️ Naver Static Map Test</h1>

<div class="status ${isOk ? 'ok' : 'fail'}">
  ${isOk ? '✅ 성공 — Static Map API 정상 작동' : '❌ 실패 — HTTP ' + result.status}
</div>

<h2>요청 정보</h2>
<table>
  <tr><th>Client ID</th><td>${NCP_CLIENT_ID}</td></tr>
  <tr><th>Secret</th><td>${NCP_CLIENT_SECRET.substring(0, 6)}...(${NCP_CLIENT_SECRET.length}자)</td></tr>
  <tr><th>좌표</th><td>lat=${lat}, lng=${lng}</td></tr>
  <tr><th>Naver API URL</th><td style="word-break:break-all;font-size:12px">${naverUrl}</td></tr>
</table>

<h2>응답</h2>
<table>
  <tr><th>HTTP Status</th><td>${result.status}</td></tr>
  <tr><th>Response Headers</th><td><pre>${JSON.stringify(result.headers, null, 2)}</pre></td></tr>
  ${result.error ? '<tr><th>Error Body</th><td><pre>' + result.error + '</pre></td></tr>' : ''}
</table>

${isOk ? '<h2>미리보기</h2><img src="' + proxyImgUrl + '" alt="Static Map" />' : ''}

<h2>curl 재현 명령어</h2>
<pre>curl -v "https://naveropenapi.apigw.ntruss.com/map-static/v2/raster?center=${lng},${lat}&level=${zoom}&w=${w}&h=${h}&maptype=basic" \\
  -H "X-NCP-APIGW-API-KEY-ID: ${NCP_CLIENT_ID}" \\
  -H "X-NCP-APIGW-API-KEY: ${NCP_CLIENT_SECRET}"</pre>

<p style="color:#999;margin-top:40px">Generated at ${new Date().toISOString()}</p>
</body></html>`);
});

export default router;

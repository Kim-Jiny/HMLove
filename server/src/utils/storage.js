import { S3Client, PutObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { promises as fs } from 'fs';
import path from 'path';
import os from 'os';

// STORAGE_MODE
//   'minio' (default, 운영) — MinIO/S3 호환 스토리지로 업로드. 위젯/앱이 STORAGE_PUBLIC_URL/<bucket>/<key> 로 가져감.
//   'local'                — 서버 프로세스의 ./uploads 폴더에 직접 저장. 클라이언트는 서버의 /uploads/<key> 로 가져감.
//                             로컬 dev 에서 MinIO 안 띄우고 빠르게 테스트할 때 사용.
const STORAGE_MODE = (process.env.STORAGE_MODE || 'minio').toLowerCase();
const BUCKET = process.env.MINIO_BUCKET || 'hmlove';
const LOCAL_UPLOAD_DIR = path.resolve('uploads');

/// 위젯/앱은 LAN IP로 서버에 붙는다. STORAGE_PUBLIC_URL이 비어있으면 자동으로
/// 호스트의 비-internal IPv4 인터페이스 주소를 골라 ${IP}:${PORT} 로 폴백.
/// 그래야 사용자가 .env.local에 IP를 박지 않아도 위젯이 이미지 URL을 열 수 있다.
function detectLanBaseUrl() {
  const port = process.env.PORT || 4000;
  const ifaces = os.networkInterfaces();
  for (const name of Object.keys(ifaces)) {
    for (const iface of ifaces[name] || []) {
      if (iface.family === 'IPv4' && !iface.internal) {
        return `http://${iface.address}:${port}`;
      }
    }
  }
  return `http://localhost:${port}`;
}

// PUBLIC_URL 결정 규칙:
//  - local 모드: .env 에 박혀있을 수 있는 운영용 STORAGE_PUBLIC_URL 은 절대 쓰지 않음
//    (그러면 위젯/앱이 운영 도메인으로 이미지 가져와서 깨짐). .env.local 에 명시한
//    LOCAL_STORAGE_BASE_URL 우선, 없으면 LAN IP 자동탐지.
//  - minio 모드 (기본/운영): STORAGE_PUBLIC_URL 그대로. 운영 도메인 동작 변경 없음.
const PUBLIC_URL = STORAGE_MODE === 'local'
  ? (process.env.LOCAL_STORAGE_BASE_URL || detectLanBaseUrl())
  : (process.env.STORAGE_PUBLIC_URL || 'http://localhost:9000');

// S3 클라이언트는 minio 모드에서만 실제로 사용. local 모드에서도 import 부작용은 없음.
const s3 = STORAGE_MODE === 'minio'
  ? new S3Client({
      endpoint: process.env.MINIO_ENDPOINT || 'http://localhost:9000',
      region: 'us-east-1',
      credentials: {
        accessKeyId: process.env.MINIO_ACCESS_KEY || 'minioadmin',
        secretAccessKey: process.env.MINIO_SECRET_KEY || 'minioadmin',
      },
      forcePathStyle: true,
    })
  : null;

if (STORAGE_MODE === 'local') {
  console.log(`[storage] local mode — uploads → ${LOCAL_UPLOAD_DIR}, served from ${PUBLIC_URL}/uploads/`);
}

export async function uploadFile(buffer, key, contentType) {
  if (STORAGE_MODE === 'local') {
    const filePath = path.join(LOCAL_UPLOAD_DIR, key);
    await fs.mkdir(path.dirname(filePath), { recursive: true });
    await fs.writeFile(filePath, buffer);
    return `${PUBLIC_URL}/uploads/${key}`;
  }

  await s3.send(new PutObjectCommand({
    Bucket: BUCKET,
    Key: key,
    Body: buffer,
    ContentType: contentType,
  }));
  return `${PUBLIC_URL}/${BUCKET}/${key}`;
}

export async function deleteFile(key) {
  if (STORAGE_MODE === 'local') {
    const filePath = path.join(LOCAL_UPLOAD_DIR, key);
    try {
      await fs.unlink(filePath);
    } catch (err) {
      if (err.code !== 'ENOENT') throw err;
    }
    return;
  }

  await s3.send(new DeleteObjectCommand({
    Bucket: BUCKET,
    Key: key,
  }));
}

/**
 * 저장된 공개 URL 에서 스토리지 key 를 뽑는다.
 * 이 서버의 스토리지 URL 이 아니거나(다른 도메인, PUBLIC_URL 변경 전 URL 등) 경로가
 * 의심스러우면 null — 이 경우 삭제하지 않는다.
 */
export function keyFromUrl(url) {
  if (typeof url !== 'string' || !url) return null;
  const prefix = STORAGE_MODE === 'local'
    ? `${PUBLIC_URL}/uploads/`
    : `${PUBLIC_URL}/${BUCKET}/`;
  if (!url.startsWith(prefix)) return null;
  let key;
  try {
    key = decodeURIComponent(url.slice(prefix.length).split('?')[0]);
  } catch {
    return null;
  }
  if (!key || key.startsWith('/') || key.split('/').includes('..')) return null;
  return key;
}

/**
 * URL 목록의 파일을 모두 지운다. 일부가 실패해도 나머지는 계속 지우고,
 * 호출한 요청을 막지 않도록 예외는 던지지 않는다. 지운 개수를 돌려준다.
 */
export async function deleteFilesByUrls(urls) {
  const keys = [...new Set(urls.map(keyFromUrl).filter(Boolean))];
  const results = await Promise.allSettled(keys.map((key) => deleteFile(key)));
  const failed = results.filter((r) => r.status === 'rejected').length;
  if (failed > 0) {
    console.error(`[storage] ${failed}/${keys.length} files failed to delete`);
  }
  return keys.length - failed;
}

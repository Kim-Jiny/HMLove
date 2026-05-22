// env 부트스트랩 — index.js 의 *맨 첫 번째* import 가 되어야 한다.
// @prisma/client 가 import 되는 순간 자기가 .env 를 자동 로드해버리므로,
// 그 전에 .env.local 을 먼저 process.env 에 박아두기 위해 별도 모듈로 분리.
//
// ESM import 는 코드 실행 전에 모듈 그래프를 전부 적재한다. 따라서
// "src/index.js 안에서 loadEnv() 호출" 보다 "별도 모듈의 top-level 부수효과"
// 가 import 순서대로 더 먼저 실행된다는 점을 활용.

import { config as loadEnv } from 'dotenv';
import { existsSync } from 'fs';

// 로컬 dev: .env.local 이 있으면 먼저 로드 (gitignore됨, prod 에서는 NODE_ENV 가드로 스킵).
if (process.env.NODE_ENV !== 'production' && existsSync('.env.local')) {
  loadEnv({ path: '.env.local' });
}
// 그 다음 .env — dotenv 는 기본적으로 이미 set 된 값을 override 하지 않음.
loadEnv();

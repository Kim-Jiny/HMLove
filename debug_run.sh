#!/usr/bin/env bash
# debug_run.sh — 호스트 머신의 LAN IP를 잡아 flutter run 에 --dart-define 으로 넣어준다.
# 서버는 별도 터미널에서 `cd server && npm run dev` 로 띄우는 걸 가정.
#
# 사용법:
#   ./debug_run.sh                  # IP 자동 + 기본 device 로 실행
#   ./debug_run.sh -d <device>      # 특정 device 지정 (flutter devices 로 확인)
#   PORT=4000 ./debug_run.sh        # 서버 포트 명시
#   API_HOST=192.168.0.5 ./debug_run.sh  # IP 자동탐지 대신 강제 지정
#
# 추가 인자는 그대로 flutter run 으로 전달됨.

set -euo pipefail

PORT="${PORT:-4000}"

# 1) IP 결정. 환경변수로 강제 지정이 있으면 그걸 쓰고, 아니면 wifi(en0) → en1 순.
HOST="${API_HOST:-}"
if [ -z "$HOST" ]; then
  for iface in en0 en1 en2; do
    candidate="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
    if [ -n "$candidate" ]; then
      HOST="$candidate"
      break
    fi
  done
fi

if [ -z "$HOST" ]; then
  echo "❌ LAN IP를 찾지 못했어요. 와이파이/이더넷이 연결돼 있는지 확인하거나,"
  echo "   API_HOST=192.168.x.x ./debug_run.sh 형태로 강제 지정하세요."
  exit 1
fi

API_BASE_URL="http://${HOST}:${PORT}"

cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  HMLove debug run
  • host       : ${HOST}
  • port       : ${PORT}
  • API base   : ${API_BASE_URL}
  • 서버는 별도 터미널에서: cd server && npm run dev
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

# 2) Flutter 디렉토리에서 실행. 추가 인자 그대로 전달.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/app"

exec flutter run \
  --dart-define="API_BASE_URL=${API_BASE_URL}" \
  "$@"

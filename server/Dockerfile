FROM node:20-alpine

WORKDIR /app

# 비-root 사용자 생성
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# 의존성 설치
COPY package*.json ./
RUN npm install --omit=dev

# 소스 복사
COPY . .

# Prisma 클라이언트 생성
RUN npx prisma generate

# 엔트리포인트 스크립트 실행 권한
RUN chmod +x docker-entrypoint.sh

# 파일 소유권 변경
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 3000

ENTRYPOINT ["./docker-entrypoint.sh"]

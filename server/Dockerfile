FROM node:20-alpine

WORKDIR /app

# Prisma config requires DATABASE_URL to exist during `prisma generate`,
# even though client generation itself does not need a live database.
ARG DATABASE_URL=postgresql://placeholder:placeholder@localhost:5432/placeholder
ENV DATABASE_URL=${DATABASE_URL}

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

USER root

EXPOSE 3000

ENTRYPOINT ["./docker-entrypoint.sh"]

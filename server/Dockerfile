FROM node:20-alpine

WORKDIR /app

# 의존성 설치
COPY package*.json ./
RUN npm install --omit=dev

# 소스 복사
COPY . .

# Prisma 클라이언트 생성
RUN npx prisma generate

EXPOSE 3000

CMD ["node", "src/index.js"]

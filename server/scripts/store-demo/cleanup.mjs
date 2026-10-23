// seed.mjs 로 만든 데모 계정/커플/파일을 모두 지운다.
// 사용: node --env-file=.env.local scripts/store-demo/cleanup.mjs
import prisma from '../../src/utils/prisma.js';
import { deleteFilesByUrls } from '../../src/utils/storage.js';
import { collectCoupleFileUrls } from '../../src/utils/storageCleanup.js';

const EMAILS = ['demo-a@example.com', 'demo-b@example.com'];
const users = await prisma.user.findMany({ where: { email: { in: EMAILS } }, select: { id: true, coupleId: true } });
if (users.length === 0) { console.log('데모 계정이 없어요.'); await prisma.$disconnect(); process.exit(0); }

const coupleIds = [...new Set(users.map((u) => u.coupleId).filter(Boolean))];
for (const coupleId of coupleIds) {
  const urls = await collectCoupleFileUrls(coupleId);
  await prisma.$transaction([
    prisma.feedLike.deleteMany({ where: { feed: { coupleId } } }),
    prisma.feedComment.deleteMany({ where: { feed: { coupleId } } }),
    prisma.feed.deleteMany({ where: { coupleId } }),
    prisma.message.deleteMany({ where: { coupleId } }),
    prisma.calendarEvent.deleteMany({ where: { coupleId } }),
    prisma.mood.deleteMany({ where: { coupleId } }),
    prisma.photo.deleteMany({ where: { coupleId } }),
    prisma.letter.deleteMany({ where: { coupleId } }),
    prisma.fight.deleteMany({ where: { coupleId } }),
    prisma.fortune.deleteMany({ where: { coupleId } }),
    prisma.coupleMission.deleteMany({ where: { coupleId } }),
    prisma.questionAnswer.deleteMany({ where: { question: { coupleId } } }),
    prisma.dailyQuestion.deleteMany({ where: { coupleId } }),
    prisma.wishItem.deleteMany({ where: { coupleId } }),
    prisma.doodle.deleteMany({ where: { coupleId } }),
    prisma.user.updateMany({ where: { coupleId }, data: { coupleId: null } }),
    prisma.couple.delete({ where: { id: coupleId } }),
  ]);
  const n = await deleteFilesByUrls(urls);
  console.log(`커플 ${coupleId} 삭제, 파일 ${n}개 삭제`);
}
await prisma.notification.deleteMany({ where: { userId: { in: users.map((u) => u.id) } } });
await prisma.user.deleteMany({ where: { email: { in: EMAILS } } });
console.log('데모 계정 삭제 완료');
await prisma.$disconnect();

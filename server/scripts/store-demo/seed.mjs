// 스토어 스크린샷용 데모 데이터 입력.
// 사용: node --env-file=.env.local scripts/store-demo/seed.mjs <이미지폴더>
// 되돌리기: node --env-file=.env.local scripts/store-demo/cleanup.mjs
import fs from 'fs';
import path from 'path';
import bcrypt from 'bcryptjs';
import prisma from '../../src/utils/prisma.js';
import { uploadFile } from '../../src/utils/storage.js';
import { getQuestionIndex } from '../../src/utils/questions.js';
import { getZodiacSign, getChineseZodiac } from '../../src/utils/zodiac.js';

const IMG = process.argv[2];
if (!IMG) throw new Error('이미지 폴더를 인자로 주세요 (make_images.py 출력)');

export const DEMO_EMAILS = ['demo-a@example.com', 'demo-b@example.com'];
const PASSWORD = 'Demo1234!';

if (await prisma.user.findFirst({ where: { email: { in: DEMO_EMAILS } } })) {
  throw new Error('데모 계정이 이미 있어요. cleanup.mjs 를 먼저 실행하세요.');
}

const KST = 9 * 3600 * 1000;
const now = new Date();
const ago = (days, hours = 0, mins = 0) => new Date(now.getTime() - days * 86400000 - hours * 3600000 - mins * 60000);
const kst = new Date(now.getTime() + KST);
const todayStr = `${kst.getUTCFullYear()}-${String(kst.getUTCMonth() + 1).padStart(2, '0')}-${String(kst.getUTCDate()).padStart(2, '0')}`;
const dateOnly = (offsetDays = 0) => new Date(Date.UTC(kst.getUTCFullYear(), kst.getUTCMonth(), kst.getUTCDate() + offsetDays));
const eventDate = (offsetDays) => dateOnly(offsetDays);

async function up(file, key, type) {
  return uploadFile(fs.readFileSync(path.join(IMG, file)), key, type);
}
const stamp = Date.now();

const hash = await bcrypt.hash(PASSWORD, 10);
const bdayA = new Date('1996-05-14'); const bdayB = new Date('1995-11-02');
const A = await prisma.user.create({ data: { email: DEMO_EMAILS[0], password: hash, nickname: '지니', zodiacSign: getZodiacSign(bdayA), chineseZodiac: getChineseZodiac(bdayA) } });
const B = await prisma.user.create({ data: { email: DEMO_EMAILS[1], password: hash, nickname: '하루', zodiacSign: getZodiacSign(bdayB), chineseZodiac: getChineseZodiac(bdayB) } });

const couple = await prisma.couple.create({
  data: { inviteCode: 'DEMOAB', startDate: new Date('2024-03-14'), users: { connect: [{ id: A.id }, { id: B.id }] } },
});
const cid = couple.id;

// 기분
await prisma.mood.createMany({ data: [
  { userId: A.id, coupleId: cid, emoji: 'happy', date: dateOnly(0) },
  { userId: B.id, coupleId: cid, emoji: 'love', date: dateOnly(0) },
] });

// 오늘의 질문 (둘 다 답변 → 공개) + 지난 질문 2개
const qIdx = getQuestionIndex(cid, todayStr);
const q0 = await prisma.dailyQuestion.create({ data: { coupleId: cid, questionIdx: qIdx, date: dateOnly(0) } });
await prisma.questionAnswer.createMany({ data: [
  { questionId: q0.id, userId: A.id, answer: '같이 있으면 시간이 너무 빨리 가는 게 제일 좋아! 오늘도 퇴근하고 바로 만나자 😊', createdAt: ago(0, 3) },
  { questionId: q0.id, userId: B.id, answer: '네가 웃을 때 눈이 반달이 되는 거. 그 순간만 기다려지는 하루야.', createdAt: ago(0, 2) },
] });
for (const [d, ia, ib, ta, tb] of [[1, 11, 57, '처음 만났던 날 비 왔던 거 아직도 기억나!', '우산 같이 쓰자고 한 거 너 맞지? ㅋㅋ'], [2, 30, 103, '주말엔 집에서 같이 영화 보고 싶어.', '그럼 내가 팝콘 담당할게!']]) {
  const q = await prisma.dailyQuestion.create({ data: { coupleId: cid, questionIdx: (qIdx + ia) % 200, date: dateOnly(-d) } });
  await prisma.questionAnswer.createMany({ data: [{ questionId: q.id, userId: A.id, answer: ta }, { questionId: q.id, userId: B.id, answer: tb }] });
}

// 운세 (AI 호출 없이 미리 채움)
await prisma.fortune.create({ data: {
  coupleId: cid, date: dateOnly(0), luckyScore: 92,
  generalLuck: '오늘은 작은 행운이 연달아 찾아오는 날이에요. 평소 미뤄뒀던 일을 시작하기에도 좋아요.',
  coupleLuck: '서로의 하루를 궁금해하는 마음이 관계를 더 단단하게 만들어줘요. 저녁에 짧게라도 통화해 보세요.',
  dateTip: '따뜻한 카페에서 서로에게 쓰는 짧은 편지를 교환해 보는 건 어때요?',
  caution: '사소한 말투 때문에 오해가 생길 수 있으니 한 번 더 웃으며 말해요.',
  user1Id: A.id, user1Luck: '황소자리인 지니님은 오늘 마음이 한결 가벼워요. 좋아하는 일에 집중하면 성과가 보여요.',
  user2Id: B.id, user2Luck: '전갈자리인 하루님은 직감이 잘 맞는 날이에요. 중요한 결정은 오후에 내려보세요.',
} });

// 피드(일기)
const imgs = {
  picnic: await up('feed_picnic.jpg', `feed/demo-${stamp}-picnic.jpg`, 'image/jpeg'),
  cafe: await up('feed_cafe.jpg', `feed/demo-${stamp}-cafe.jpg`, 'image/jpeg'),
  sakura: await up('feed_sakura.jpg', `feed/demo-${stamp}-sakura.jpg`, 'image/jpeg'),
  cake: await up('feed_cake.jpg', `feed/demo-${stamp}-cake.jpg`, 'image/jpeg'),
  chat: await up('chat_sunset.jpg', `chat/demo-${stamp}-sunset.jpg`, 'image/jpeg'),
};
const feeds = [
  [A, '오늘 한강에서 피크닉! 돗자리 펴자마자 바람이 딱 좋아서 한참 누워 있었어. 이런 날이 계속되면 좋겠다 🧺', [imgs.picnic], ago(0, 5)],
  [B, '퇴근길에 발견한 카페인데 라떼 위에 하트가 올라와 있었어. 사진 찍어서 바로 보여주고 싶었어 ☕', [imgs.cafe], ago(1, 2)],
  [A, '벚꽃이 이렇게 예쁜 줄 몰랐어. 내년에도 같은 자리에서 사진 찍자, 약속!', [imgs.sakura], ago(3, 4)],
  [B, '우리 1000일까지 이제 얼마 안 남았네. 조금 이르지만 케이크 미리 연습해봤어 🎂', [imgs.cake], ago(5, 1)],
  [A, '오늘은 아무 일도 없었는데도 하루 끝에 네 얼굴 보니까 다 괜찮아졌어.', [], ago(7, 3)],
];
const createdFeeds = [];
for (const [u, content, imageUrls, createdAt] of feeds) {
  createdFeeds.push(await prisma.feed.create({ data: { coupleId: cid, authorId: u.id, content, imageUrls, type: imageUrls.length ? 'PHOTO' : 'DIARY', createdAt } }));
}
await prisma.feedLike.createMany({ data: [
  { feedId: createdFeeds[0].id, userId: B.id }, { feedId: createdFeeds[1].id, userId: A.id },
  { feedId: createdFeeds[2].id, userId: B.id }, { feedId: createdFeeds[3].id, userId: A.id },
] });
await prisma.feedComment.createMany({ data: [
  { feedId: createdFeeds[0].id, authorId: B.id, content: '다음 주말에도 가자! 이번엔 내가 샌드위치 쌀게 🥪', createdAt: ago(0, 4) },
  { feedId: createdFeeds[1].id, authorId: A.id, content: '와 하트 라떼 너무 귀엽다ㅠㅠ 다음엔 같이 가자', createdAt: ago(1, 1) },
] });

// 캘린더
const evs = [
  [A, '한강 피크닉', 0, false, '#EC5F8E'], [B, '저녁 데이트 (파스타)', 0, false, '#F59E6C'], [B, '영화 보기', 4, false, '#9B8CE8'], [A, '맛집 데이트', 6, false, '#F59E6C'],
  [A, '부모님 댁 방문', 12, false, '#4DBFA0'], [B, '하루 생일', 18, true, '#E9B93C'],
  [A, '벚꽃 드라이브', -3, false, '#5BA8F0'], [B, '카페 투어', 1, false, '#F59E6C'],
];
for (const [u, title, off, ann, color] of evs) {
  await prisma.calendarEvent.create({ data: { coupleId: cid, authorId: u.id, title, date: eventDate(off), isAnniversary: ann, color, repeatType: ann ? 'YEARLY' : 'NONE' } });
}

// 채팅
const chat = [
  [B, '일어났어? 오늘 날씨 진짜 좋다', 0, 5, 30], [A, '방금 일어남ㅋㅋ 같이 피크닉 갈래?', 0, 5, 24], [B, '좋지! 샌드위치는 내가 챙겨갈게', 0, 5, 20],
  [A, '그럼 난 음료랑 돗자리 담당 ☀️', 0, 5, 15], [B, '4시쯤 한강에서 볼까?', 0, 5, 10], [A, '응응 도착하면 연락할게!', 0, 5, 6],
  [B, '사진 보여줘 ㅎㅎ', 0, 2, 20], [A, null, 0, 2, 12, imgs.chat], [A, '노을 진짜 예쁘지', 0, 2, 11], [B, '너랑 같이 보니까 더 예쁜 것 같아 💕', 0, 2, 5], [A, '오늘도 고마워, 푹 자!', 0, 0, 20],
];
for (const [u, content, d, h, m, img] of chat) {
  await prisma.message.create({ data: { coupleId: cid, senderId: u.id, content: content ?? undefined, imageUrls: img ? [img] : [], isRead: true, createdAt: ago(d, h, m) } });
}

// 편지
await prisma.letter.createMany({ data: [
  { coupleId: cid, writerId: B.id, receiverId: A.id, title: '우리 1000일, 미리 쓰는 편지', status: 'DELIVERED', isRead: false, deliveryDate: ago(1), createdAt: ago(2),
    content: '지니야, 벌써 1000일이 코앞이라니 믿기지 않아.\n처음 만났던 날보다 지금이 더 설레는 건 네가 매일 조금씩 더 좋은 사람이라서일 거야.\n앞으로의 1000일도 같이 웃으면서 보내자. 사랑해.' },
  { coupleId: cid, writerId: A.id, receiverId: B.id, title: '고마운 마음 전해요', status: 'DELIVERED', isRead: true, deliveryDate: ago(9), createdAt: ago(10),
    content: '하루야, 힘든 날에도 늘 옆에 있어줘서 고마워. 작은 것까지 기억해주는 네 마음에 매일 감동하고 있어.' },
  { coupleId: cid, writerId: A.id, receiverId: B.id, title: '생일에 열어봐!', status: 'SCHEDULED', isRead: false, deliveryDate: ago(-18), createdAt: ago(1),
    content: '생일 축하해! 미리 쓴 편지니까 그날 아침에 열어봐. 깜짝 선물도 준비해 뒀어.' },
] });

// 위시리스트
const wishes = [
  [A, 'PLACE', '제주도 2박 3일 여행', true, false], [B, 'FOOD', '오마카세 같이 가기', true, false], [A, 'ACTIVITY', '커플 원데이 클래스 (도자기)', true, false],
  [B, 'PLACE', '벚꽃 명소 사진 찍기', false, true], [A, 'OTHER', '둘이 커플 앨범 만들기', true, false], [B, 'FOOD', '홈카페에서 브런치 만들기', false, false],
  [A, 'ACTIVITY', '야경 보며 드라이브', false, false], [B, 'PLACE', '바다 보이는 캠핑', true, false],
];
for (const [u, category, title, isFavorite, isCompleted] of wishes) {
  await prisma.wishItem.create({ data: { coupleId: cid, authorId: u.id, category, title, isFavorite, isCompleted, completedBy: isCompleted ? u.id : null, completedAt: isCompleted ? ago(4) : null } });
}

// 다툼 기록 (해결됨)
await prisma.fight.create({ data: { coupleId: cid, authorId: A.id, date: ago(14), reason: '약속 시간에 늦어서 서운했어요', resolution: '미리 연락하기로 약속했어요', reflection: '서로 이야기하니 금방 풀렸어요', isResolved: true } });

// 그림
const d1 = await up('doodle_1.png', `doodles/demo-${stamp}-1.png`, 'image/png');
const d2 = await up('doodle_2.png', `doodles/demo-${stamp}-2.png`, 'image/png');
await prisma.doodle.createMany({ data: [
  { coupleId: cid, senderId: B.id, receiverId: A.id, imageUrl: d1, createdAt: ago(0, 1) },
  { coupleId: cid, senderId: A.id, receiverId: B.id, imageUrl: d2, createdAt: ago(1) },
] });

console.log(JSON.stringify({ ok: true, coupleId: cid, users: DEMO_EMAILS, password: PASSWORD }));
await prisma.$disconnect();

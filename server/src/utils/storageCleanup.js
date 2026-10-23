// 커플/계정 삭제 시 DB 행과 함께 사라지는 이미지 파일의 URL 을 모은다.
// 행을 지우기 *전에* 호출하고, 삭제가 성공한 뒤 deleteFilesByUrls 로 파일을 지운다.
import prisma from './prisma.js';

const hasImages = { NOT: { imageUrls: { isEmpty: true } } };

/** 커플 전체(피드·채팅·사진·그림)의 파일 URL. 커플의 마지막 멤버가 나갈 때 쓴다. */
export async function collectCoupleFileUrls(coupleId) {
  const [feeds, messages, photos, doodles] = await Promise.all([
    prisma.feed.findMany({ where: { coupleId, ...hasImages }, select: { imageUrls: true } }),
    prisma.message.findMany({ where: { coupleId, ...hasImages }, select: { imageUrls: true } }),
    prisma.photo.findMany({ where: { coupleId }, select: { imageUrl: true, thumbnailUrl: true } }),
    prisma.doodle.findMany({ where: { coupleId }, select: { imageUrl: true } }),
  ]);
  return [
    ...feeds.flatMap((f) => f.imageUrls),
    ...messages.flatMap((m) => m.imageUrls),
    ...photos.flatMap((p) => [p.imageUrl, p.thumbnailUrl]),
    ...doodles.map((d) => d.imageUrl),
  ].filter(Boolean);
}

/** 한 사용자가 지워질 때 함께 사라지는 파일 URL (본인이 올린 것 + 본인이 주고받은 그림). */
export async function collectUserFileUrls(userId) {
  const [feeds, messages, photos, doodles] = await Promise.all([
    prisma.feed.findMany({ where: { authorId: userId, ...hasImages }, select: { imageUrls: true } }),
    prisma.message.findMany({ where: { senderId: userId, ...hasImages }, select: { imageUrls: true } }),
    prisma.photo.findMany({ where: { authorId: userId }, select: { imageUrl: true, thumbnailUrl: true } }),
    prisma.doodle.findMany({
      where: { OR: [{ senderId: userId }, { receiverId: userId }] },
      select: { imageUrl: true },
    }),
  ]);
  return [
    ...feeds.flatMap((f) => f.imageUrls),
    ...messages.flatMap((m) => m.imageUrls),
    ...photos.flatMap((p) => [p.imageUrl, p.thumbnailUrl]),
    ...doodles.map((d) => d.imageUrl),
  ].filter(Boolean);
}

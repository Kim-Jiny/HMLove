-- CreateTable
CREATE TABLE "Doodle" (
    "id" TEXT NOT NULL,
    "coupleId" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "receiverId" TEXT NOT NULL,
    "imageUrl" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Doodle_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Doodle_coupleId_createdAt_idx" ON "Doodle"("coupleId", "createdAt");

-- CreateIndex
CREATE INDEX "Doodle_receiverId_createdAt_idx" ON "Doodle"("receiverId", "createdAt");

-- AddForeignKey
ALTER TABLE "Doodle" ADD CONSTRAINT "Doodle_coupleId_fkey" FOREIGN KEY ("coupleId") REFERENCES "Couple"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Doodle" ADD CONSTRAINT "Doodle_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Doodle" ADD CONSTRAINT "Doodle_receiverId_fkey" FOREIGN KEY ("receiverId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

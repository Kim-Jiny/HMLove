-- CreateTable
CREATE TABLE "Poke" (
    "id" TEXT NOT NULL,
    "coupleId" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "receiverId" TEXT NOT NULL,
    "kind" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Poke_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Poke_receiverId_createdAt_idx" ON "Poke"("receiverId", "createdAt");

-- CreateIndex
CREATE INDEX "Poke_coupleId_createdAt_idx" ON "Poke"("coupleId", "createdAt");

-- AddForeignKey
ALTER TABLE "Poke" ADD CONSTRAINT "Poke_coupleId_fkey" FOREIGN KEY ("coupleId") REFERENCES "Couple"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Poke" ADD CONSTRAINT "Poke_senderId_fkey" FOREIGN KEY ("senderId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Poke" ADD CONSTRAINT "Poke_receiverId_fkey" FOREIGN KEY ("receiverId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

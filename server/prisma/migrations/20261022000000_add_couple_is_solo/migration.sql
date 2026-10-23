-- AlterTable
ALTER TABLE "Couple" ADD COLUMN "isSolo" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "Couple" ADD COLUMN "pendingPartnerName" TEXT;

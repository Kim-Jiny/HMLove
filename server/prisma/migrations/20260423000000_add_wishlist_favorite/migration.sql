ALTER TABLE "WishItem"
ADD COLUMN "isFavorite" BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX "WishItem_coupleId_isFavorite_isCompleted_idx"
ON "WishItem"("coupleId", "isFavorite", "isCompleted");

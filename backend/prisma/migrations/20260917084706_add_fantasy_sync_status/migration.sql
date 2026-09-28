-- CreateTable
CREATE TABLE "fantasy_sync_status" (
    "id" TEXT NOT NULL DEFAULT 'fantasy',
    "lastAttemptAt" TIMESTAMP(3),
    "lastSuccessAt" TIMESTAMP(3),
    "lastFailureAt" TIMESTAMP(3),
    "lastStatus" TEXT,
    "lastError" TEXT,
    "lastSummary" JSONB,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "fantasy_sync_status_pkey" PRIMARY KEY ("id")
);

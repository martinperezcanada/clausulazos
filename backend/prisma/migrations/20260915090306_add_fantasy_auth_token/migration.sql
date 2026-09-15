-- CreateTable
CREATE TABLE "fantasy_auth_tokens" (
    "id" TEXT NOT NULL DEFAULT 'laliga',
    "refreshToken" TEXT NOT NULL,
    "accessToken" TEXT,
    "accessTokenExpiresAt" TIMESTAMP(3),
    "refreshTokenExpiresAt" TIMESTAMP(3),
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "fantasy_auth_tokens_pkey" PRIMARY KEY ("id")
);

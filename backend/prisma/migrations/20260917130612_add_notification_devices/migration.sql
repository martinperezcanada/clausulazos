-- CreateTable
CREATE TABLE "notification_devices" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "token" TEXT NOT NULL,
    "platform" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "notification_devices_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "notification_devices_token_key" ON "notification_devices"("token");

-- CreateIndex
CREATE INDEX "notification_devices_userId_idx" ON "notification_devices"("userId");

-- AddForeignKey
ALTER TABLE "notification_devices" ADD CONSTRAINT "notification_devices_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

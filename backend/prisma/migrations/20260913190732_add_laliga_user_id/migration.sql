/*
  Warnings:

  - A unique constraint covering the columns `[laligaUserId]` on the table `users` will be added. If there are existing duplicate values, this will fail.

*/
-- AlterTable
ALTER TABLE "users" ADD COLUMN     "laligaUserId" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "users_laligaUserId_key" ON "users"("laligaUserId");

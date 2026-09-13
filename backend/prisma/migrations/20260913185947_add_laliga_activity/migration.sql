/*
  Warnings:

  - A unique constraint covering the columns `[laligaActivityId]` on the table `clauses` will be added. If there are existing duplicate values, this will fail.

*/
-- AlterTable
ALTER TABLE "clauses" ADD COLUMN     "laligaActivityId" TEXT,
ADD COLUMN     "playerMasterId" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "clauses_laligaActivityId_key" ON "clauses"("laligaActivityId");

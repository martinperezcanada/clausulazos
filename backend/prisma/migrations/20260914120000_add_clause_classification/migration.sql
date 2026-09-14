-- CreateEnum
CREATE TYPE "ClauseClassification" AS ENUM ('PENDING', 'CLAUSE', 'AGREED');

-- AlterTable
-- Safe backfill: every existing clause (all of which represented real
-- clausulazos before this feature existed) becomes CLAUSE by default, so
-- it keeps counting toward the 2-slot limits exactly as it did before.
-- New rows explicitly set their own value at insert time (PENDING from
-- the LALIGA sync, CLAUSE from manual creation), so this DEFAULT only
-- ever applies retroactively to pre-existing rows and as a safety net.
ALTER TABLE "clauses" ADD COLUMN     "classification" "ClauseClassification" NOT NULL DEFAULT 'CLAUSE',
ADD COLUMN     "fromConfirmation" "ClauseClassification",
ADD COLUMN     "toConfirmation" "ClauseClassification";

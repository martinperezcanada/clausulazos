// A slot (performed or received) is occupied for exactly 7 x 24 hours.
export const CLAUSE_DURATION_MS = 7 * 24 * 60 * 60 * 1000;

// Maximum number of simultaneously active clauses per direction (performed / received).
export const MAX_ACTIVE_CLAUSES = 2;

export function computeExpiresAt(createdAt: Date): Date {
  return new Date(createdAt.getTime() + CLAUSE_DURATION_MS);
}

export type Confirmation = 'PENDING' | 'CLAUSE' | 'AGREED' | null | undefined;

/**
 * Resolves the final classification of a movement from each participant's
 * individual confirmation. This is the single source of truth for the
 * "no one can unilaterally remove a clause from the stats" rule:
 *
 * - Only becomes AGREED when BOTH sides independently confirmed AGREED.
 * - A single CLAUSE vote from either side is enough to lock it in as a
 *   counting clause — that's the safe direction, since it can't be used
 *   to escape the limits.
 * - Any discrepancy (one CLAUSE, one AGREED) resolves to CLAUSE, never to
 *   AGREED, per spec.
 * - With no votes yet (or only an AGREED vote from one side and nothing
 *   from the other), the movement stays PENDING.
 */
export function resolveClassification(
  fromConfirmation: Confirmation,
  toConfirmation: Confirmation,
): 'PENDING' | 'CLAUSE' | 'AGREED' {
  if (fromConfirmation === 'AGREED' && toConfirmation === 'AGREED') {
    return 'AGREED';
  }
  if (fromConfirmation === 'CLAUSE' || toConfirmation === 'CLAUSE') {
    return 'CLAUSE';
  }
  return 'PENDING';
}

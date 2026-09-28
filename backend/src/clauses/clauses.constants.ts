// A slot (performed or received) is occupied for exactly 7 x 24 hours.
export const CLAUSE_DURATION_MS = 7 * 24 * 60 * 60 * 1000;

// Maximum number of simultaneously active clauses per direction (performed / received).
export const MAX_ACTIVE_CLAUSES = 2;

export function computeExpiresAt(createdAt: Date): Date {
  return new Date(createdAt.getTime() + CLAUSE_DURATION_MS);
}

export type Confirmation = 'PENDING' | 'CLAUSE' | 'AGREED' | null | undefined;

/**
 * Final classification of a movement from each participant's confirmation.
 * - AGREED only when both sides confirmed AGREED.
 * - A CLAUSE vote from either side, or a CLAUSE/AGREED mismatch, resolves to CLAUSE, so nobody can
 *   leave the limits unilaterally.
 * - With no votes, or a single AGREED vote, it stays PENDING.
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

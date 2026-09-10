// A slot (performed or received) is occupied for exactly 7 x 24 hours.
export const CLAUSE_DURATION_MS = 7 * 24 * 60 * 60 * 1000;

// Maximum number of simultaneously active clauses per direction (performed / received).
export const MAX_ACTIVE_CLAUSES = 2;

export function computeExpiresAt(createdAt: Date): Date {
  return new Date(createdAt.getTime() + CLAUSE_DURATION_MS);
}

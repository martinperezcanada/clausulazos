import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ClauseClassification, ClauseStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  MAX_ACTIVE_CLAUSES,
  computeExpiresAt,
  resolveClassification,
} from './clauses.constants';

export interface SlotStats {
  active: number;
  limit: number;
  available: number;
  nextReleaseAt: Date | null;
}

export interface UserStats {
  performed: SlotStats;
  received: SlotStats;
}

@Injectable()
export class ClausesService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Creates a new "clausulazo" from `fromUserId` to `toUserId`.
   *
   * Concurrency safety: within a single DB transaction we take a
   * Postgres advisory lock on BOTH participating user ids (always in a
   * fixed order to avoid deadlocks) before counting active clauses and
   * inserting. Any other transaction trying to touch either user's
   * slots blocks until this one commits or rolls back, which makes the
   * "count < 2 then insert" check atomic and race-free — two
   * simultaneous requests against the same user can never both succeed
   * past the limit.
   */
  async create(fromUserId: string, toUserId: string) {
    if (fromUserId === toUserId) {
      throw new BadRequestException('No puedes clausularte a ti mismo');
    }

    const toUser = await this.prisma.user.findUnique({ where: { id: toUserId } });
    if (!toUser) {
      throw new NotFoundException('El jugador destino no existe');
    }

    return this.prisma.$transaction(async (tx) => {
      await this.lockUsersForUpdate(tx, fromUserId, toUserId);

      const now = new Date();

      const activePerformedCount = await this.countActive(tx, {
        fromUserId,
        now,
      });
      if (activePerformedCount >= MAX_ACTIVE_CLAUSES) {
        throw new ForbiddenException(
          'Has alcanzado el límite de 2 cláusulazos realizados activos',
        );
      }

      const activeReceivedCount = await this.countActive(tx, {
        toUserId,
        now,
      });
      if (activeReceivedCount >= MAX_ACTIVE_CLAUSES) {
        throw new ForbiddenException(
          'Ese jugador ya tiene 2 cláusulazos recibidos activos',
        );
      }

      const createdAt = now;
      const expiresAt = computeExpiresAt(createdAt);

      const clause = await tx.clause.create({
        data: {
          fromUserId,
          toUserId,
          createdAt,
          expiresAt,
          status: ClauseStatus.ACTIVE,
          classification: ClauseClassification.CLAUSE,
        },
        include: { fromUser: true, toUser: true },
      });

      return clause;
    });
  }

  async cancel(clauseId: string, requesterId: string) {
    return this.prisma.$transaction(async (tx) => {
      const clause = await tx.clause.findUnique({ where: { id: clauseId } });
      if (!clause) {
        throw new NotFoundException('Cláusulazo no encontrado');
      }
      if (clause.fromUserId !== requesterId) {
        throw new ForbiddenException(
          'Solo quien realizó el cláusulazo puede eliminarlo',
        );
      }
      if (clause.status === ClauseStatus.CANCELLED) {
        return clause;
      }

      return tx.clause.update({
        where: { id: clauseId },
        data: { status: ClauseStatus.CANCELLED, cancelledAt: new Date() },
      });
    });
  }

  /**
   * Records `requesterId`'s own vote on what a PENDING (or still-disputed)
   * movement was. The requester must be one of the two participants — the
   * backend never trusts Flutter for this. The final `classification` is
   * always recomputed from BOTH sides' confirmations via
   * `resolveClassification`, so a single participant can never unilaterally
   * push a movement into AGREED.
   */
  async confirmClassification(
    clauseId: string,
    requesterId: string,
    classification: 'CLAUSE' | 'AGREED',
  ) {
    return this.prisma.$transaction(async (tx) => {
      const clause = await tx.clause.findUnique({ where: { id: clauseId } });
      if (!clause) {
        throw new NotFoundException('Movimiento no encontrado');
      }

      const isFromUser = clause.fromUserId === requesterId;
      const isToUser = clause.toUserId === requesterId;
      if (!isFromUser && !isToUser) {
        throw new ForbiddenException(
          'Solo los participantes de este movimiento pueden confirmarlo',
        );
      }

      const nextFromConfirmation = isFromUser
        ? (classification as ClauseClassification)
        : clause.fromConfirmation;
      const nextToConfirmation = isToUser
        ? (classification as ClauseClassification)
        : clause.toConfirmation;

      const resolved = resolveClassification(nextFromConfirmation, nextToConfirmation);

      return tx.clause.update({
        where: { id: clauseId },
        data: {
          fromConfirmation: nextFromConfirmation,
          toConfirmation: nextToConfirmation,
          classification: ClauseClassification[resolved],
        },
        include: { fromUser: true, toUser: true },
      });
    });
  }

  async findAll() {
    return this.prisma.clause.findMany({
      orderBy: { createdAt: 'desc' },
      include: { fromUser: true, toUser: true },
    });
  }

  async findForUser(userId: string) {
    return this.prisma.clause.findMany({
      where: { OR: [{ fromUserId: userId }, { toUserId: userId }] },
      orderBy: { createdAt: 'desc' },
      include: { fromUser: true, toUser: true },
    });
  }

  /**
   * A clause counts as "active" only if:
   *   - status is ACTIVE (i.e. not manually cancelled),
   *   - expiresAt is still in the future, AND
   *   - classification is CLAUSE (PENDING movements awaiting confirmation
   *     and AGREED pacted transfers never occupy a slot, however recent).
   * Expired/cancelled/agreed clauses are kept in the table for history but
   * never count against the 2-slot limit. `active` is intentionally NOT
   * clamped to the limit, so callers can detect and warn about an excess
   * (e.g. a third LALIGA-detected clause) instead of silently hiding it.
   */
  async getStatsForUser(userId: string): Promise<UserStats> {
    const now = new Date();

    const [activePerformed, activeReceived] = await Promise.all([
      this.prisma.clause.findMany({
        where: {
          fromUserId: userId,
          status: ClauseStatus.ACTIVE,
          classification: ClauseClassification.CLAUSE,
          expiresAt: { gt: now },
        },
        orderBy: { expiresAt: 'asc' },
      }),
      this.prisma.clause.findMany({
        where: {
          toUserId: userId,
          status: ClauseStatus.ACTIVE,
          classification: ClauseClassification.CLAUSE,
          expiresAt: { gt: now },
        },
        orderBy: { expiresAt: 'asc' },
      }),
    ]);

    return {
      performed: this.buildSlotStats(activePerformed),
      received: this.buildSlotStats(activeReceived),
    };
  }

  private buildSlotStats(activeClauses: { expiresAt: Date }[]): SlotStats {
    const active = activeClauses.length;
    return {
      active,
      limit: MAX_ACTIVE_CLAUSES,
      available: Math.max(0, MAX_ACTIVE_CLAUSES - active),
      nextReleaseAt: active > 0 ? activeClauses[0].expiresAt : null,
    };
  }

  private async countActive(
    tx: Prisma.TransactionClient,
    where: { fromUserId?: string; toUserId?: string; now: Date },
  ) {
    const { now, ...rest } = where;
    return tx.clause.count({
      where: {
        ...rest,
        status: ClauseStatus.ACTIVE,
        classification: ClauseClassification.CLAUSE,
        expiresAt: { gt: now },
      },
    });
  }

  // Locks both users' "slot rows" in a fixed, deterministic order (by id)
  // so two concurrent transactions involving the same pair of users can
  // never deadlock against each other.
  private async lockUsersForUpdate(
    tx: Prisma.TransactionClient,
    userIdA: string,
    userIdB: string,
  ) {
    const [first, second] = [userIdA, userIdB].sort();
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${first}))`;
    if (second !== first) {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${second}))`;
    }
  }
}

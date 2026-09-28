import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  ClauseClassification,
  ClauseStatus,
  NotificationType,
  Prisma,
} from '@prisma/client';
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
   * Creates a clausulazo from `fromUserId` to `toUserId`. Runs in a transaction that takes a Postgres
   * advisory lock on both users (in a fixed order, to avoid deadlocks) before counting active clauses,
   * so two concurrent requests can't both get past the limit.
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
   * Admin-only removal of any movement (`cancel()` is limited to the creator). Authorization is done at
   * the route level (JwtAuthGuard + AdminGuard). Uses the same CANCELLED transition as `cancel()`, so
   * history behaves the same.
   */
  async adminCancel(clauseId: string) {
    return this.prisma.$transaction(async (tx) => {
      const clause = await tx.clause.findUnique({ where: { id: clauseId } });
      if (!clause) {
        throw new NotFoundException('Movimiento no encontrado');
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
   * Records `requesterId`'s vote on a PENDING (or disputed) movement. The requester must be a
   * participant. The final classification is recomputed from both votes with `resolveClassification`,
   * so one side can't force AGREED.
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

  /**
   * "Avisar a..." from the Activity screen: `requesterId` reminds the participant who hasn't voted on a
   * PENDING movement. Persists a `Notification` row and returns what the caller needs to send the FCM
   * push (recipient and requester names). Sending is left to the controller so this service can be
   * built with only `PrismaService`. A reminder for the same clause and recipient created in the last
   * 10 minutes is reused.
   */
  async remindParticipant(clauseId: string, requesterId: string) {
    const clause = await this.prisma.clause.findUnique({
      where: { id: clauseId },
      include: { fromUser: true, toUser: true },
    });
    if (!clause) {
      throw new NotFoundException('Movimiento no encontrado');
    }

    const isFromUser = clause.fromUserId === requesterId;
    const isToUser = clause.toUserId === requesterId;
    if (!isFromUser && !isToUser) {
      throw new ForbiddenException(
        'Solo los participantes de este movimiento pueden avisar',
      );
    }

    if (clause.classification !== ClauseClassification.PENDING) {
      throw new BadRequestException(
        'Este movimiento ya no está pendiente de confirmación',
      );
    }

    const recipientId = isFromUser ? clause.toUserId : clause.fromUserId;
    const recipientAlreadyConfirmed = isFromUser
      ? clause.toConfirmation !== null
      : clause.fromConfirmation !== null;
    if (recipientAlreadyConfirmed) {
      throw new BadRequestException(
        'Ese participante ya ha confirmado este movimiento',
      );
    }

    const requesterName = isFromUser ? clause.fromUser.name : clause.toUser.name;
    const recipientName = isFromUser ? clause.toUser.name : clause.fromUser.name;

    const recent = await this.prisma.notification.findFirst({
      where: {
        userId: recipientId,
        clauseId,
        type: NotificationType.CLAUSE_CONFIRMATION_REMINDER,
        createdAt: { gt: new Date(Date.now() - 10 * 60 * 1000) },
      },
      orderBy: { createdAt: 'desc' },
    });

    const playerLabel = clause.playerName ?? 'un jugador';

    const notification =
      recent ??
      (await this.prisma.notification.create({
        data: {
          userId: recipientId,
          clauseId,
          type: NotificationType.CLAUSE_CONFIRMATION_REMINDER,
          message: `${requesterName} te ha avisado de que tienes pendiente confirmar el movimiento de ${playerLabel}.`,
        },
      }));

    return { notification, recipientId, recipientName, requesterName };
  }

  // CANCELLED movements are left out of both listings so they disappear from Activity. The row is kept
  // for audit and is still reachable by id.
  async findAll() {
    return this.prisma.clause.findMany({
      where: { status: { not: ClauseStatus.CANCELLED } },
      orderBy: { createdAt: 'desc' },
      include: { fromUser: true, toUser: true },
    });
  }

  async findForUser(userId: string) {
    return this.prisma.clause.findMany({
      where: {
        OR: [{ fromUserId: userId }, { toUserId: userId }],
        status: { not: ClauseStatus.CANCELLED },
      },
      orderBy: { createdAt: 'desc' },
      include: { fromUser: true, toUser: true },
    });
  }

  /**
   * A clause is active if its status is ACTIVE, `expiresAt` is in the future and its classification is
   * CLAUSE (PENDING and AGREED movements never occupy a slot). `active` is deliberately not clamped to
   * the limit, so callers can detect an excess (e.g. a third LALIGA-detected clause).
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

  // Lock both users in id order so concurrent transactions on the same pair can't deadlock.
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

import { Test } from '@nestjs/testing';
import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ClausesService } from './clauses.service';
import { computeExpiresAt } from './clauses.constants';

/**
 * Integration tests for `remindParticipant`, using the same real database as
 * `clauses.service.spec.ts`. Kept in its own file because that spec builds its module without
 * Firebase/Notifications.
 */
describe('ClausesService.remindParticipant (integration)', () => {
  let prisma: PrismaService;
  let service: ClausesService;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [PrismaService, ClausesService],
    }).compile();
    prisma = moduleRef.get(PrismaService);
    service = moduleRef.get(ClausesService);
    await prisma.$connect();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  beforeEach(async () => {
    await prisma.notification.deleteMany();
    await prisma.clause.deleteMany();
    await prisma.user.deleteMany();
  });

  async function makeUser(name: string) {
    return prisma.user.create({
      data: { name, email: `${name.toLowerCase()}@remind.local`, password: 'x' },
    });
  }

  async function makePendingClause(fromId: string, toId: string) {
    const createdAt = new Date();
    return prisma.clause.create({
      data: {
        fromUserId: fromId,
        toUserId: toId,
        createdAt,
        expiresAt: computeExpiresAt(createdAt),
        status: 'ACTIVE',
        classification: 'PENDING',
      },
    });
  }

  it('identifica correctamente al destinatario (el otro participante)', async () => {
    const a = await makeUser('R1A');
    const b = await makeUser('R1B');
    const clause = await makePendingClause(a.id, b.id);

    const result = await service.remindParticipant(clause.id, a.id);
    expect(result.recipientId).toBe(b.id);
    expect(result.recipientName).toBe('R1B');
    expect(result.requesterName).toBe('R1A');
  });

  it('funciona igual en el sentido contrario (el receptor avisa al emisor)', async () => {
    const a = await makeUser('R2A');
    const b = await makeUser('R2B');
    const clause = await makePendingClause(a.id, b.id);

    const result = await service.remindParticipant(clause.id, b.id);
    expect(result.recipientId).toBe(a.id);
    expect(result.recipientName).toBe('R2A');
  });

  it('un usuario que no participa no puede avisar', async () => {
    const a = await makeUser('R3A');
    const b = await makeUser('R3B');
    const outsider = await makeUser('R3X');
    const clause = await makePendingClause(a.id, b.id);

    await expect(service.remindParticipant(clause.id, outsider.id)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('no se puede avisar sobre un movimiento que ya no está PENDING', async () => {
    const a = await makeUser('R4A');
    const b = await makeUser('R4B');
    const createdAt = new Date();
    const clause = await prisma.clause.create({
      data: {
        fromUserId: a.id,
        toUserId: b.id,
        createdAt,
        expiresAt: computeExpiresAt(createdAt),
        status: 'ACTIVE',
        classification: 'CLAUSE',
      },
    });

    await expect(service.remindParticipant(clause.id, a.id)).rejects.toBeInstanceOf(BadRequestException);
  });

  it('no se puede avisar a alguien que ya confirmó', async () => {
    const a = await makeUser('R5A');
    const b = await makeUser('R5B');
    const clause = await makePendingClause(a.id, b.id);
    // b already voted — nothing left to remind them about.
    await service.confirmClassification(clause.id, b.id, 'CLAUSE');

    await expect(service.remindParticipant(clause.id, a.id)).rejects.toBeInstanceOf(BadRequestException);
  });

  it('reutiliza el aviso reciente en lugar de duplicarlo', async () => {
    const a = await makeUser('R6A');
    const b = await makeUser('R6B');
    const clause = await makePendingClause(a.id, b.id);

    const first = await service.remindParticipant(clause.id, a.id);
    const second = await service.remindParticipant(clause.id, a.id);
    expect(second.notification.id).toBe(first.notification.id);

    const count = await prisma.notification.count({ where: { clauseId: clause.id } });
    expect(count).toBe(1);
  });

  // El destinatario siempre es el otro participante y `create()` ya rechaza fromUserId === toUserId,
  // así que no hay forma de montar el escenario.
});

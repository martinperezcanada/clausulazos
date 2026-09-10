import { Test } from '@nestjs/testing';
import { ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ClausesService } from './clauses.service';
import { computeExpiresAt, CLAUSE_DURATION_MS } from './clauses.constants';

/**
 * These are integration tests: they run against a REAL PostgreSQL
 * database (see README "Ejecutar los tests"), because the whole point
 * of tests 12 ("dos peticiones simultáneas") and 11 ("expiración
 * exacta") is to exercise real DB transactions/locks and real dates,
 * which a mocked Prisma client cannot faithfully reproduce.
 *
 * Each test creates its own throw-away users so tests don't interfere
 * with each other, and the whole DB is wiped in `beforeEach`.
 */
describe('ClausesService (integration)', () => {
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
    await prisma.clause.deleteMany();
    await prisma.user.deleteMany();
  });

  async function makeUser(name: string) {
    return prisma.user.create({
      data: { name, email: `${name.toLowerCase()}@test.local`, password: 'x' },
    });
  }

  async function makeClause(opts: {
    fromId: string;
    toId: string;
    createdAt: Date;
    status?: 'ACTIVE' | 'EXPIRED' | 'CANCELLED';
  }) {
    return prisma.clause.create({
      data: {
        fromUserId: opts.fromId,
        toUserId: opts.toId,
        createdAt: opts.createdAt,
        expiresAt: computeExpiresAt(opts.createdAt),
        status: (opts.status as any) ?? 'ACTIVE',
      },
    });
  }

  // --- Test 1 ---
  it('usuario con 0 activos puede hacer cláusulazo', async () => {
    const a = await makeUser('A1');
    const b = await makeUser('B1');
    const clause = await service.create(a.id, b.id);
    expect(clause.fromUserId).toBe(a.id);
    expect(clause.toUserId).toBe(b.id);
  });

  // --- Test 2 ---
  it('usuario con 1 activo puede hacer otro', async () => {
    const a = await makeUser('A2');
    const b = await makeUser('B2');
    const c = await makeUser('C2');
    await makeClause({ fromId: a.id, toId: b.id, createdAt: new Date() });
    const second = await service.create(a.id, c.id);
    expect(second.toUserId).toBe(c.id);
  });

  // --- Test 3 ---
  it('usuario con 2 activos NO puede hacer otro', async () => {
    const a = await makeUser('A3');
    const b = await makeUser('B3');
    const c = await makeUser('C3');
    const d = await makeUser('D3');
    await makeClause({ fromId: a.id, toId: b.id, createdAt: new Date() });
    await makeClause({ fromId: a.id, toId: c.id, createdAt: new Date() });
    await expect(service.create(a.id, d.id)).rejects.toBeInstanceOf(ForbiddenException);
  });

  // --- Test 4 ---
  it('cuando uno de los dos expira, puede volver a hacer otro', async () => {
    const a = await makeUser('A4');
    const b = await makeUser('B4');
    const c = await makeUser('C4');
    const d = await makeUser('D4');
    const eightDaysAgo = new Date(Date.now() - 8 * 24 * 60 * 60 * 1000);
    await makeClause({ fromId: a.id, toId: b.id, createdAt: eightDaysAgo }); // already expired
    await makeClause({ fromId: a.id, toId: c.id, createdAt: new Date() }); // still active
    const third = await service.create(a.id, d.id);
    expect(third.toUserId).toBe(d.id);
  });

  // --- Test 5 ---
  it('usuario con 0 recibidos puede recibir', async () => {
    const a = await makeUser('A5');
    const b = await makeUser('B5');
    const clause = await service.create(a.id, b.id);
    expect(clause.toUserId).toBe(b.id);
  });

  // --- Test 6 ---
  it('usuario con 1 recibido puede recibir otro', async () => {
    const a = await makeUser('A6');
    const b = await makeUser('B6');
    const c = await makeUser('C6');
    await makeClause({ fromId: a.id, toId: c.id, createdAt: new Date() });
    const clause = await service.create(b.id, c.id);
    expect(clause.toUserId).toBe(c.id);
  });

  // --- Test 7 ---
  it('usuario con 2 recibidos activos NO puede recibir otro', async () => {
    const a = await makeUser('A7');
    const b = await makeUser('B7');
    const c = await makeUser('C7');
    const target = await makeUser('T7');
    await makeClause({ fromId: a.id, toId: target.id, createdAt: new Date() });
    await makeClause({ fromId: b.id, toId: target.id, createdAt: new Date() });
    await expect(service.create(c.id, target.id)).rejects.toBeInstanceOf(ForbiddenException);
  });

  // --- Test 8 ---
  it('cuando uno recibido expira, puede recibir otro', async () => {
    const a = await makeUser('A8');
    const b = await makeUser('B8');
    const c = await makeUser('C8');
    const target = await makeUser('T8');
    const eightDaysAgo = new Date(Date.now() - 8 * 24 * 60 * 60 * 1000);
    await makeClause({ fromId: a.id, toId: target.id, createdAt: eightDaysAgo });
    await makeClause({ fromId: b.id, toId: target.id, createdAt: new Date() });
    const clause = await service.create(c.id, target.id);
    expect(clause.toUserId).toBe(target.id);
  });

  // --- Test 9 ---
  it('no puede clausularse a sí mismo', async () => {
    const a = await makeUser('A9');
    await expect(service.create(a.id, a.id)).rejects.toThrow();
  });

  // --- Test 10 ---
  it('un cláusulazo recién creado tiene expiresAt = createdAt + 7 días', async () => {
    const a = await makeUser('A10');
    const b = await makeUser('B10');
    const clause = await service.create(a.id, b.id);
    const diff = clause.expiresAt.getTime() - clause.createdAt.getTime();
    expect(diff).toBe(CLAUSE_DURATION_MS);
  });

  // --- Test 11 ---
  it('un cláusulazo exactamente en su fecha de expiración ya NO cuenta como activo', async () => {
    const a = await makeUser('A11');
    const b = await makeUser('B11');
    const c = await makeUser('C11');
    // createdAt exactly 7 days ago => expiresAt is exactly now (or in the past by the
    // time this line runs), so it must NOT be counted as active ("now < expiresAt").
    const sevenDaysAgo = new Date(Date.now() - CLAUSE_DURATION_MS);
    await makeClause({ fromId: a.id, toId: c.id, createdAt: sevenDaysAgo });
    const stats = await service.getStatsForUser(a.id);
    expect(stats.performed.active).toBe(0);
    // and the slot must be usable again
    const clause = await service.create(a.id, b.id);
    expect(clause.toUserId).toBe(b.id);
  });

  // --- Test 12 ---
  it('dos peticiones simultáneas no pueden provocar 3 activos', async () => {
    const a = await makeUser('A12');
    const b = await makeUser('B12');
    const target = await makeUser('T12');
    // target already has 1/2 received slots occupied.
    await makeClause({ fromId: b.id, toId: target.id, createdAt: new Date() });

    const c = await makeUser('C12');
    // a and c race to occupy target's last received slot.
    const results = await Promise.allSettled([
      service.create(a.id, target.id),
      service.create(c.id, target.id),
    ]);

    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    const rejected = results.filter((r) => r.status === 'rejected');
    expect(fulfilled).toHaveLength(1);
    expect(rejected).toHaveLength(1);

    const stats = await service.getStatsForUser(target.id);
    expect(stats.received.active).toBe(2); // never 3
  });

  // --- Test 13 ---
  it('cancelar cláusulazo libera ambas plazas', async () => {
    const a = await makeUser('A13');
    const b = await makeUser('B13');
    const clause = await service.create(a.id, b.id);

    let statsA = await service.getStatsForUser(a.id);
    let statsB = await service.getStatsForUser(b.id);
    expect(statsA.performed.active).toBe(1);
    expect(statsB.received.active).toBe(1);

    await service.cancel(clause.id, a.id);

    statsA = await service.getStatsForUser(a.id);
    statsB = await service.getStatsForUser(b.id);
    expect(statsA.performed.active).toBe(0);
    expect(statsB.received.active).toBe(0);
  });

  // --- Test 14 ---
  it('cláusulazos expirados siguen apareciendo en historial', async () => {
    const a = await makeUser('A14');
    const b = await makeUser('B14');
    const eightDaysAgo = new Date(Date.now() - 8 * 24 * 60 * 60 * 1000);
    const clause = await makeClause({ fromId: a.id, toId: b.id, createdAt: eightDaysAgo });

    const history = await service.findForUser(a.id);
    expect(history.some((c) => c.id === clause.id)).toBe(true);
  });
});

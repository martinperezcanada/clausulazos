import { Test } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

/**
 * End-to-end test of the full HTTP flow: register -> login -> create a
 * clause -> read stats. Requires a real PostgreSQL database reachable
 * via DATABASE_URL (see README).
 */
describe('Clausulazos API (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaService;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    await app.init();

    prisma = moduleRef.get(PrismaService);
    await prisma.clause.deleteMany();
    await prisma.user.deleteMany({ where: { email: { contains: '@e2e.local' } } });
  });

  afterAll(async () => {
    await prisma.clause.deleteMany();
    await prisma.user.deleteMany({ where: { email: { contains: '@e2e.local' } } });
    await app.close();
  });

  it('registers, logs in, creates a clause, and blocks fromUserId spoofing', async () => {
    const reg = await request(app.getHttpServer()).post('/auth/register').send({
      name: 'E2E Martin',
      email: 'martin@e2e.local',
      password: 'secret123',
      confirmPassword: 'secret123',
    });
    expect(reg.status).toBe(201);
    const token = reg.body.accessToken;

    const reg2 = await request(app.getHttpServer()).post('/auth/register').send({
      name: 'E2E Juan',
      email: 'juan@e2e.local',
      password: 'secret123',
      confirmPassword: 'secret123',
    });
    const juanId = reg2.body.user.id;

    // Attempting to spoof fromUserId must be rejected by whitelist validation.
    const spoofed = await request(app.getHttpServer())
      .post('/clauses')
      .set('Authorization', `Bearer ${token}`)
      .send({ toUserId: juanId, fromUserId: 'someone-else' });
    expect(spoofed.status).toBe(400);

    const created = await request(app.getHttpServer())
      .post('/clauses')
      .set('Authorization', `Bearer ${token}`)
      .send({ toUserId: juanId });
    expect(created.status).toBe(201);
    expect(created.body.fromUserId).not.toBe('someone-else');

    const stats = await request(app.getHttpServer())
      .get('/users/me/stats')
      .set('Authorization', `Bearer ${token}`);
    expect(stats.status).toBe(200);
    expect(stats.body.performed.active).toBe(1);
  });

  it('rejects requests without a valid JWT', async () => {
    const res = await request(app.getHttpServer()).get('/users/me');
    expect(res.status).toBe(401);
  });
});

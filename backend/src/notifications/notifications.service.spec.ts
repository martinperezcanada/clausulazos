import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from './notifications.service';
import { FirebaseAdminService } from './firebase-admin.service';

/**
 * Integration tests against a real PostgreSQL database, like `clauses.service.spec.ts`. Firebase is not
 * exercised: without FIREBASE_* credentials `sendToUser` must report NOT_CONFIGURED instead of throwing.
 */
describe('NotificationsService (integration)', () => {
  let prisma: PrismaService;
  let service: NotificationsService;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [PrismaService, NotificationsService, FirebaseAdminService, ConfigService],
    }).compile();

    prisma = moduleRef.get(PrismaService);
    service = moduleRef.get(NotificationsService);
    await prisma.$connect();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  beforeEach(async () => {
    await prisma.notificationDevice.deleteMany();
    await prisma.notification.deleteMany();
    await prisma.clause.deleteMany();
    await prisma.user.deleteMany();
  });

  async function makeUser(name: string) {
    return prisma.user.create({
      data: { name, email: `${name.toLowerCase()}@notif.local`, password: 'x' },
    });
  }

  it('registra un token nuevo', async () => {
    const user = await makeUser('N1');
    await service.registerDevice(user.id, 'token-n1', 'android');

    const devices = await service.getDevicesForUser(user.id);
    expect(devices).toHaveLength(1);
    expect(devices[0].token).toBe('token-n1');
    expect(devices[0].platform).toBe('android');
  });

  it('registrar el mismo token dos veces es idempotente (no duplica)', async () => {
    const user = await makeUser('N2');
    await service.registerDevice(user.id, 'token-n2', 'android');
    await service.registerDevice(user.id, 'token-n2', 'android');

    const devices = await service.getDevicesForUser(user.id);
    expect(devices).toHaveLength(1);
  });

  it('un usuario puede tener varios dispositivos', async () => {
    const user = await makeUser('N3');
    await service.registerDevice(user.id, 'token-n3-a', 'android');
    await service.registerDevice(user.id, 'token-n3-b', 'web');

    const devices = await service.getDevicesForUser(user.id);
    expect(devices).toHaveLength(2);
  });

  it('un token existente se reasigna al usuario que vuelve a registrarlo (mismo dispositivo, otra cuenta)', async () => {
    const userA = await makeUser('N4A');
    const userB = await makeUser('N4B');
    await service.registerDevice(userA.id, 'token-n4', 'android');
    await service.registerDevice(userB.id, 'token-n4', 'android');

    expect(await service.getDevicesForUser(userA.id)).toHaveLength(0);
    expect(await service.getDevicesForUser(userB.id)).toHaveLength(1);
  });

  it('sendToUser sin dispositivos registrados devuelve NO_DEVICE sin lanzar', async () => {
    const user = await makeUser('N5');
    const result = await service.sendToUser(user.id, { title: 't', body: 'b' });
    expect(result).toEqual({ devicesNotified: 0, reason: 'NO_DEVICE' });
  });

  it('sendToUser sin Firebase Admin configurado devuelve NOT_CONFIGURED sin lanzar', async () => {
    const user = await makeUser('N6');
    await service.registerDevice(user.id, 'token-n6', 'android');

    const result = await service.sendToUser(user.id, { title: 't', body: 'b' });
    expect(result).toEqual({ devicesNotified: 0, reason: 'NOT_CONFIGURED' });
  });
});

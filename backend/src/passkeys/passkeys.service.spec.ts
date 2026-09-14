import { Test } from '@nestjs/testing';
import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PasskeysService } from './passkeys.service';

describe('PasskeysService (integration)', () => {
  let prisma: PrismaService;
  let service: PasskeysService;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [PrismaService, PasskeysService],
    }).compile();
    prisma = moduleRef.get(PrismaService);
    service = moduleRef.get(PasskeysService);
    await prisma.$connect();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  beforeEach(async () => {
  await prisma.passkeyCredential.deleteMany();
  await prisma.webAuthnChallenge.deleteMany();
  await prisma.clause.deleteMany();
  await prisma.user.deleteMany();
});

  async function makeUser(name: string) {
    return prisma.user.create({
      data: { name, email: `${name.toLowerCase()}@test.local`, password: 'x' },
    });
  }

  async function makeCredential(userId: string, credentialId: string) {
    return prisma.passkeyCredential.create({
      data: {
        userId,
        credentialId,
        publicKey: Buffer.from('fake-public-key'),
        counter: 0,
        transports: ['internal'],
        deviceType: 'singleDevice',
        backedUp: false,
        name: 'iPhone de prueba',
      },
    });
  }

  it('lista solo las passkeys del usuario indicado', async () => {
    const a = await makeUser('A1');
    const b = await makeUser('B1');
    await makeCredential(a.id, 'cred-a-1');
    await makeCredential(b.id, 'cred-b-1');

    const listA = await service.listForUser(a.id);
    expect(listA).toHaveLength(1);
    expect(listA[0].name).toBe('iPhone de prueba');
    // Never exposes verification material.
    expect((listA[0] as any).publicKey).toBeUndefined();
    expect((listA[0] as any).credentialId).toBeUndefined();
  });

  it('un usuario NO puede eliminar la passkey de otro usuario', async () => {
    const a = await makeUser('A2');
    const b = await makeUser('B2');
    const credentialOfA = await makeCredential(a.id, 'cred-a-2');

    await expect(service.remove(b.id, credentialOfA.id)).rejects.toBeInstanceOf(ForbiddenException);

    // Still there afterwards.
    const stillThere = await prisma.passkeyCredential.findUnique({ where: { id: credentialOfA.id } });
    expect(stillThere).not.toBeNull();
  });

  it('un usuario SÍ puede eliminar su propia passkey', async () => {
    const a = await makeUser('A3');
    const credential = await makeCredential(a.id, 'cred-a-3');

    const result = await service.remove(a.id, credential.id);
    expect(result.success).toBe(true);

    const gone = await prisma.passkeyCredential.findUnique({ where: { id: credential.id } });
    expect(gone).toBeNull();
  });

  it('eliminar una passkey inexistente lanza NotFoundException', async () => {
    const a = await makeUser('A4');
    await expect(service.remove(a.id, 'does-not-exist')).rejects.toBeInstanceOf(NotFoundException);
  });
});

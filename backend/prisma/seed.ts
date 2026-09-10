import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import * as bcrypt from 'bcrypt';

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter } as any);

// Development-only credentials. See README for details.
const DEV_PASSWORD = 'clausulazo123';

const players = [
  { name: 'Martín', email: 'martin@example.com' },
  { name: 'Juan', email: 'juan@example.com' },
  { name: 'Pedro', email: 'pedro@example.com' },
  { name: 'Antonio', email: 'antonio@example.com' },
  { name: 'Carlos', email: 'carlos@example.com' },
  { name: 'Dani', email: 'dani@example.com' },
  { name: 'Pablo', email: 'pablo@example.com' },
  { name: 'Miguel', email: 'miguel@example.com' },
];

async function main() {
  const hashedPassword = await bcrypt.hash(DEV_PASSWORD, 10);

  const created: Record<string, string> = {};
  for (const player of players) {
    const user = await prisma.user.upsert({
      where: { email: player.email },
      update: {},
      create: {
        name: player.name,
        email: player.email,
        password: hashedPassword,
      },
    });
    created[player.name] = user.id;
  }

  // A couple of sample clauses so the app has non-empty data on first run.
  const existingClauses = await prisma.clause.count();
  if (existingClauses === 0) {
    const now = new Date();
    const sevenDays = 7 * 24 * 60 * 60 * 1000;

    await prisma.clause.create({
      data: {
        fromUserId: created['Martín'],
        toUserId: created['Juan'],
        createdAt: now,
        expiresAt: new Date(now.getTime() + sevenDays),
      },
    });

    // An already-expired clause, to demonstrate history behaviour.
    const past = new Date(now.getTime() - 8 * 24 * 60 * 60 * 1000);
    await prisma.clause.create({
      data: {
        fromUserId: created['Pedro'],
        toUserId: created['Antonio'],
        createdAt: past,
        expiresAt: new Date(past.getTime() + sevenDays),
      },
    });
  }

  // eslint-disable-next-line no-console
  console.log('Seed completado. Contraseña de desarrollo para todos:', DEV_PASSWORD);
}

main()
  .catch((e) => {
    // eslint-disable-next-line no-console
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

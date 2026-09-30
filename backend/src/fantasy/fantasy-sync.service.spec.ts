import { Test } from '@nestjs/testing';
import { PrismaService } from '../prisma/prisma.service';
import { ClausesService } from '../clauses/clauses.service';
import { computeExpiresAt } from '../clauses/clauses.constants';
import { FantasyAuthService } from './fantasy-auth.service';
import { FantasySyncService } from './fantasy-sync.service';

/**
 * Integration tests for the LALIGA activity sync against a real PostgreSQL database, with the LALIGA API
 * stubbed through `fetch`. They wipe the clause/user tables, so they refuse to run unless DATABASE_URL
 * points at a database whose name ends in `_test`.
 */
const databaseName = (process.env.DATABASE_URL ?? '')
  .split('?')[0]
  .split('/')
  .pop();
// Same URL shape as the pictures LALIGA returns in `playerMaster.images`.
const img = (id: string) =>
  `https://assets-fantasy.llt-services.com/players/t1/p${id}/256x256/p${id}_t1_1_001_000.png`;

const describeOnTestDb = databaseName?.endsWith('_test')
  ? describe
  : describe.skip;

describeOnTestDb('FantasySyncService.syncActivity (integration)', () => {
  let prisma: PrismaService;
  let sync: FantasySyncService;
  let clauses: ClausesService;

  // What the stubbed LALIGA API returns.
  let activities: any[];
  let playerNames: Record<string, string | null>;
  let playerImages: Record<string, string>;
  let playerRequests: number;
  let activityRequests: number;
  // Set to an HTTP error status to make LALIGA's activity endpoint fail.
  let activityStatus: number;

  const originalFetch = global.fetch;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      providers: [
        PrismaService,
        ClausesService,
        FantasySyncService,
        {
          provide: FantasyAuthService,
          useValue: { getAccessToken: async () => 'test-token' },
        },
      ],
    }).compile();

    prisma = moduleRef.get(PrismaService);
    sync = moduleRef.get(FantasySyncService);
    clauses = moduleRef.get(ClausesService);
    await prisma.$connect();

    global.fetch = jest.fn(async (input: any) => {
      const url = String(input);
      if (url.includes('/activity/')) {
        activityRequests++;
        return new Response(JSON.stringify(activities), {
          status: activityStatus,
        });
      }
      const player = url.match(/\/player\/([^/]+)\//);
      if (player) {
        playerRequests++;
        const name = playerNames[player[1]];
        const image = playerImages[player[1]];
        // Same shape as LALIGA's real player payload.
        return name
          ? new Response(
              JSON.stringify({
                playerMaster: {
                  name,
                  ...(image
                    ? { images: { transparent: { '256x256': image } } }
                    : {}),
                },
              }),
              { status: 200 },
            )
          : new Response('{}', { status: 503 });
      }
      throw new Error(`Unexpected fetch ${url}`);
    }) as any;
  });

  afterAll(async () => {
    global.fetch = originalFetch;
    await prisma.$disconnect();
  });

  beforeEach(async () => {
    activities = [];
    playerNames = {};
    playerImages = {};
    playerRequests = 0;
    activityRequests = 0;
    activityStatus = 200;
    await prisma.notification.deleteMany();
    await prisma.clause.deleteMany();
    await prisma.user.deleteMany();
    await prisma.fantasySyncStatus.deleteMany();
  });

  async function makeUser(name: string, laligaUserId: string) {
    return prisma.user.create({
      data: {
        name,
        email: `${name.toLowerCase()}@test.local`,
        password: 'x',
        laligaUserId,
      },
    });
  }

  function clauseActivity(opts: {
    id: number;
    from: string;
    to: string;
    playerMasterId: number;
    amount: number;
    at: Date;
  }) {
    return {
      id: opts.id,
      activityTypeId: 1,
      user1Id: Number(opts.from),
      user2Id: Number(opts.to),
      playerMasterId: opts.playerMasterId,
      amount: opts.amount,
      createdAt: opts.at.toISOString(),
    };
  }

  // What the app lists (Inicio/Actividad): every non-cancelled movement.
  const visibleClauses = () => clauses.findAll();

  const minutesAgo = (minutes: number) =>
    new Date(Date.now() - minutes * 60 * 1000);

  it('completes the incomplete movement registered by hand instead of duplicating it', async () => {
    const martin = await makeUser('Martin', '111');
    const alex = await makeUser('Alex', '222');

    // 1. The movement is registered in the app first: name only, no player or amount.
    const provisional = await clauses.create(martin.id, alex.id);
    let visible = await visibleClauses();
    expect(visible).toHaveLength(1);
    expect(visible[0].playerName).toBeNull();
    expect(visible[0].amount).toBeNull();

    // 2. The sync then detects it in LALIGA with the full data.
    const officialAt = minutesAgo(20);
    activities = [
      clauseActivity({
        id: 9001,
        from: '111',
        to: '222',
        playerMasterId: 55,
        amount: 12345678,
        at: officialAt,
      }),
    ];
    playerNames = { '55': 'Pedri' };

    const result = await sync.syncActivity();
    expect(result.created).toBe(0);
    expect(result.reconciled).toBe(1);

    // 3. One movement, the same row, now with the LALIGA data.
    visible = await visibleClauses();
    expect(visible).toHaveLength(1);
    const clause = visible[0];
    expect(clause.id).toBe(provisional.id);
    expect(clause.laligaActivityId).toBe('9001');
    expect(clause.playerMasterId).toBe('55');
    expect(clause.playerName).toBe('Pedri');
    expect(clause.amount).toBe(12345678);
    expect(clause.fromUser.name).toBe('Martin');
    expect(clause.toUser.name).toBe('Alex');
    expect(clause.createdAt.getTime()).toBe(officialAt.getTime());
    expect(clause.expiresAt.getTime()).toBe(
      computeExpiresAt(officialAt).getTime(),
    );
    // Registered by hand as a cláusulazo: it keeps counting.
    expect(clause.classification).toBe('CLAUSE');
  });

  it('running the sync again does not create duplicates', async () => {
    const martin = await makeUser('Martin', '111');
    const alex = await makeUser('Alex', '222');
    await clauses.create(martin.id, alex.id);
    activities = [
      clauseActivity({
        id: 9001,
        from: '111',
        to: '222',
        playerMasterId: 55,
        amount: 100,
        at: minutesAgo(5),
      }),
    ];
    playerNames = { '55': 'Pedri' };
    playerImages = { '55': img('55') };

    await sync.syncActivity();
    const second = await sync.syncActivity();
    const third = await sync.syncActivity();

    for (const run of [second, third]) {
      expect(run.created).toBe(0);
      expect(run.reconciled).toBe(0);
      expect(run.updated).toBe(0);
      expect(run.alreadyExists).toBe(1);
    }
    expect(await prisma.clause.count()).toBe(1);
    expect(await visibleClauses()).toHaveLength(1);
    // The player name is only looked up while a row still needs it.
    expect(playerRequests).toBe(1);
  });

  it('the same activity synced 20 times is still a single movement', async () => {
    await makeUser('Martin', '111');
    await makeUser('Alex', '222');
    activities = [
      clauseActivity({
        id: 9001,
        from: '111',
        to: '222',
        playerMasterId: 55,
        amount: 100,
        at: minutesAgo(5),
      }),
    ];
    playerNames = { '55': 'Pedri' };
    playerImages = { '55': img('55') };

    let created = 0;
    for (let run = 0; run < 20; run++) {
      const result = await sync.runScheduledSync();
      expect(result.detectedClauseTransfers).toBe(1);
      created += result.created;
    }

    expect(created).toBe(1);
    expect(await prisma.clause.count()).toBe(1);
    expect(
      await prisma.clause.count({ where: { laligaActivityId: '9001' } }),
    ).toBe(1);
  });

  it('two imports of the same activities at the same time store each movement once', async () => {
    const martin = await makeUser('Martin', '111');
    const alex = await makeUser('Alex', '222');
    // One movement already registered by hand, one only known to LALIGA.
    await clauses.create(martin.id, alex.id);
    activities = [
      clauseActivity({
        id: 9001,
        from: '111',
        to: '222',
        playerMasterId: 55,
        amount: 100,
        at: minutesAgo(5),
      }),
      clauseActivity({
        id: 9002,
        from: '222',
        to: '111',
        playerMasterId: 56,
        amount: 200,
        at: minutesAgo(3),
      }),
    ];
    playerNames = { '55': 'Pedri', '56': 'Gavi' };

    // `syncActivity` directly, bypassing the single-run guard of `runScheduledSync`.
    const [a, b] = await Promise.all([
      sync.syncActivity(),
      sync.syncActivity(),
    ]);

    expect(a.created + b.created).toBe(1);
    expect(a.reconciled + b.reconciled).toBe(1);
    expect(await prisma.clause.count()).toBe(2);
    const visible = await visibleClauses();
    expect(visible.map((c) => c.laligaActivityId).sort()).toEqual([
      '9001',
      '9002',
    ]);
  });

  it('a sync requested while another is running joins it instead of starting a second one', async () => {
    await makeUser('Martin', '111');
    await makeUser('Alex', '222');
    activities = [
      clauseActivity({
        id: 9001,
        from: '111',
        to: '222',
        playerMasterId: 55,
        amount: 100,
        at: minutesAgo(5),
      }),
    ];
    playerNames = { '55': 'Pedri' };

    const [a, b, c] = await Promise.all([
      sync.runScheduledSync(),
      sync.runScheduledSync(),
      sync.runScheduledSync(),
    ]);

    expect(activityRequests).toBe(1);
    expect(a.created).toBe(1);
    expect(b).toBe(a);
    expect(c).toBe(a);
    expect(await prisma.clause.count()).toBe(1);

    // The slot is free again once that run has finished.
    const next = await sync.runScheduledSync();
    expect(activityRequests).toBe(2);
    expect(next.created).toBe(0);
    expect(next.alreadyExists).toBe(1);
  });

  it('a failed sync keeps lastSuccessfulSyncAt and does not block the next one', async () => {
    await makeUser('Martin', '111');
    await makeUser('Alex', '222');

    await sync.runScheduledSync();
    const afterSuccess = await sync.getStatus();
    expect(afterSuccess.lastStatus).toBe('SUCCESS');
    expect(afterSuccess.lastSuccessfulSyncAt).not.toBeNull();

    activityStatus = 503;
    await expect(sync.runScheduledSync()).rejects.toThrow(
      'LALIGA API respondió 503',
    );
    const afterFailure = await sync.getStatus();
    expect(afterFailure.lastStatus).toBe('FAILURE');
    expect(afterFailure.lastSuccessfulSyncAt).toEqual(
      afterSuccess.lastSuccessfulSyncAt,
    );

    // LALIGA is back, with a movement that happened meanwhile: the next run imports it.
    activityStatus = 200;
    activities = [
      clauseActivity({
        id: 9001,
        from: '111',
        to: '222',
        playerMasterId: 55,
        amount: 100,
        at: minutesAgo(5),
      }),
    ];
    playerNames = { '55': 'Pedri' };
    const retry = await sync.runScheduledSync();
    expect(retry.created).toBe(1);

    const afterRetry = await sync.getStatus();
    expect(afterRetry.lastStatus).toBe('SUCCESS');
    expect(afterRetry.lastSuccessfulSyncAt!.getTime()).toBeGreaterThanOrEqual(
      afterSuccess.lastSuccessfulSyncAt!.getTime(),
    );
  });

  it('consolidates an existing duplicate (incomplete + LALIGA rows) into a single movement', async () => {
    const martin = await makeUser('Martin', '111');
    const alex = await makeUser('Alex', '222');
    const officialAt = minutesAgo(60);

    // The state the old sync left behind: the hand-registered row and a second LALIGA row.
    const provisional = await clauses.create(martin.id, alex.id);
    const official = await prisma.clause.create({
      data: {
        laligaActivityId: '9001',
        playerMasterId: '55',
        playerName: 'Pedri',
        amount: 100,
        fromUserId: martin.id,
        toUserId: alex.id,
        createdAt: officialAt,
        expiresAt: computeExpiresAt(officialAt),
        status: 'ACTIVE',
        classification: 'PENDING',
      },
    });
    expect(await visibleClauses()).toHaveLength(2);

    activities = [
      clauseActivity({
        id: 9001,
        from: '111',
        to: '222',
        playerMasterId: 55,
        amount: 100,
        at: officialAt,
      }),
    ];

    const result = await sync.syncActivity();
    expect(result.reconciled).toBe(1);

    const visible = await visibleClauses();
    expect(visible).toHaveLength(1);
    expect(visible[0].id).toBe(official.id);
    expect(visible[0].playerName).toBe('Pedri');
    // The hand-registered "cláusulazo" carries over instead of going back to PENDING.
    expect(visible[0].classification).toBe('CLAUSE');

    // The incomplete row is kept for audit, cancelled.
    const leftover = await prisma.clause.findUnique({
      where: { id: provisional.id },
    });
    expect(leftover?.status).toBe('CANCELLED');

    // And stays that way.
    const again = await sync.syncActivity();
    expect(again.reconciled).toBe(0);
    expect(await visibleClauses()).toHaveLength(1);
  });

  it('folds a movement registered by hand after the sync had already imported it', async () => {
    const martin = await makeUser('Martin', '111');
    const alex = await makeUser('Alex', '222');
    activities = [
      clauseActivity({
        id: 9001,
        from: '111',
        to: '222',
        playerMasterId: 55,
        amount: 100,
        at: minutesAgo(30),
      }),
    ];
    playerNames = { '55': 'Pedri' };

    await sync.syncActivity();
    await clauses.create(martin.id, alex.id);
    expect(await visibleClauses()).toHaveLength(2);

    await sync.syncActivity();
    const visible = await visibleClauses();
    expect(visible).toHaveLength(1);
    expect(visible[0].laligaActivityId).toBe('9001');
    expect(visible[0].playerName).toBe('Pedri');
  });

  it('completes a LALIGA movement first stored without player name on a later sync', async () => {
    await makeUser('Martin', '111');
    await makeUser('Alex', '222');
    activities = [
      clauseActivity({
        id: 9001,
        from: '111',
        to: '222',
        playerMasterId: 55,
        amount: 100,
        at: minutesAgo(10),
      }),
    ];

    // LALIGA's player endpoint fails on the first run.
    playerNames = { '55': null };
    const first = await sync.syncActivity();
    expect(first.created).toBe(1);
    expect((await visibleClauses())[0].playerName).toBeNull();

    playerNames = { '55': 'Pedri' };
    const second = await sync.syncActivity();
    expect(second.created).toBe(0);
    expect(second.updated).toBe(1);

    const visible = await visibleClauses();
    expect(visible).toHaveLength(1);
    expect(visible[0].playerName).toBe('Pedri');
  });

  it('leaves historical movements and unrelated manual clauses alone', async () => {
    const martin = await makeUser('Martin', '111');
    const alex = await makeUser('Alex', '222');
    const lucia = await makeUser('Lucia', '333');

    const oldAt = minutesAgo(5 * 24 * 60);
    const history = [
      clauseActivity({
        id: 8001,
        from: '111',
        to: '222',
        playerMasterId: 1,
        amount: 10,
        at: oldAt,
      }),
      clauseActivity({
        id: 8002,
        from: '333',
        to: '111',
        playerMasterId: 2,
        amount: 20,
        at: minutesAgo(3 * 24 * 60),
      }),
    ];
    activities = history;
    playerNames = { '1': 'Uno', '2': 'Dos' };
    await sync.syncActivity();

    // A manual cláusulazo between other managers, and one far from any LALIGA movement.
    const otherPair = await clauses.create(alex.id, lucia.id);

    // A new LALIGA movement arrives on top of the history.
    activities = [
      clauseActivity({
        id: 8003,
        from: '222',
        to: '333',
        playerMasterId: 3,
        amount: 30,
        at: minutesAgo(1),
      }),
      ...history,
    ];
    playerNames['3'] = 'Tres';
    const result = await sync.syncActivity();

    // Alex -> Lucia was registered by hand, so it is completed rather than duplicated.
    expect(result.reconciled).toBe(1);
    expect(result.created).toBe(0);
    expect(result.alreadyExists).toBe(2);

    const visible = await visibleClauses();
    expect(visible.map((c) => c.laligaActivityId).sort()).toEqual([
      '8001',
      '8002',
      '8003',
    ]);
    expect(visible.find((c) => c.laligaActivityId === '8003')?.id).toBe(
      otherPair.id,
    );
    expect(martin).toBeDefined();
  });

  it('does not reuse a manual clause between different managers', async () => {
    const martin = await makeUser('Martin', '111');
    const alex = await makeUser('Alex', '222');
    await makeUser('Lucia', '333');
    const reversed = await clauses.create(alex.id, martin.id);

    activities = [
      clauseActivity({
        id: 9001,
        from: '111',
        to: '222',
        playerMasterId: 55,
        amount: 100,
        at: minutesAgo(5),
      }),
    ];
    const result = await sync.syncActivity();

    expect(result.created).toBe(1);
    expect(result.reconciled).toBe(0);
    const untouched = await prisma.clause.findUnique({
      where: { id: reversed.id },
    });
    expect(untouched?.laligaActivityId).toBeNull();
    expect(untouched?.status).toBe('ACTIVE');
  });

  it('reports in the sync status whether the last run changed anything', async () => {
    const martin = await makeUser('Martin', '111');
    const alex = await makeUser('Alex', '222');
    await clauses.create(martin.id, alex.id);
    activities = [
      clauseActivity({
        id: 9001,
        from: '111',
        to: '222',
        playerMasterId: 55,
        amount: 100,
        at: minutesAgo(5),
      }),
    ];
    playerNames = { '55': 'Pedri' };

    await sync.runScheduledSync();
    expect((await sync.getStatus()).lastChangeCount).toBe(1);

    await sync.runScheduledSync();
    expect((await sync.getStatus()).lastChangeCount).toBe(0);
  });

  it('stores the official player picture, per playerMasterId', async () => {
    await makeUser('Martin', '111');
    await makeUser('Alex', '222');
    activities = [
      clauseActivity({
        id: 9001,
        from: '111',
        to: '222',
        playerMasterId: 55,
        amount: 1,
        at: minutesAgo(10),
      }),
      clauseActivity({
        id: 9002,
        from: '222',
        to: '111',
        playerMasterId: 56,
        amount: 2,
        at: minutesAgo(5),
      }),
    ];
    playerNames = { '55': 'Pedri', '56': 'Gavi' };
    playerImages = { '55': img('55'), '56': img('56') };

    await sync.syncActivity();

    const byActivity = Object.fromEntries(
      (await visibleClauses()).map((c) => [c.laligaActivityId, c]),
    );
    expect(byActivity['9001'].playerImageUrl).toBe(img('55'));
    expect(byActivity['9002'].playerImageUrl).toBe(img('56'));
    // One player request per movement: name and picture come from the same call.
    expect(playerRequests).toBe(2);
  });

  it('adds the picture to a hand-registered movement it reconciles', async () => {
    const martin = await makeUser('Martin', '111');
    const alex = await makeUser('Alex', '222');
    await clauses.create(martin.id, alex.id);
    activities = [
      clauseActivity({
        id: 9001,
        from: '111',
        to: '222',
        playerMasterId: 55,
        amount: 1,
        at: minutesAgo(5),
      }),
    ];
    playerNames = { '55': 'Pedri' };
    playerImages = { '55': img('55') };

    await sync.syncActivity();

    const [clause] = await visibleClauses();
    expect(clause.playerImageUrl).toBe(img('55'));
  });

  it('backfills the picture on movements stored before it existed, without duplicating', async () => {
    await makeUser('Martin', '111');
    await makeUser('Alex', '222');
    activities = [
      clauseActivity({
        id: 9001,
        from: '111',
        to: '222',
        playerMasterId: 55,
        amount: 1,
        at: minutesAgo(5),
      }),
    ];
    playerNames = { '55': 'Pedri' };
    await sync.syncActivity();
    expect((await visibleClauses())[0].playerImageUrl).toBeNull();

    playerImages = { '55': img('55') };
    const second = await sync.syncActivity();
    expect(second.updated).toBe(1);
    expect(second.created).toBe(0);

    const visible = await visibleClauses();
    expect(visible).toHaveLength(1);
    expect(visible[0].playerImageUrl).toBe(img('55'));

    // Complete now: later syncs don't ask LALIGA again.
    const requestsBefore = playerRequests;
    await sync.syncActivity();
    expect(playerRequests).toBe(requestsBefore);
  });

  it('ignores a picture that is not an https URL', async () => {
    await makeUser('Martin', '111');
    await makeUser('Alex', '222');
    activities = [
      clauseActivity({
        id: 9001,
        from: '111',
        to: '222',
        playerMasterId: 55,
        amount: 1,
        at: minutesAgo(5),
      }),
    ];
    playerNames = { '55': 'Pedri' };
    playerImages = { '55': 'javascript:alert(1)' };

    await sync.syncActivity();

    expect((await visibleClauses())[0].playerImageUrl).toBeNull();
  });
});

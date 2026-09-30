import { Injectable } from '@nestjs/common';
import {
  Clause,
  ClauseClassification,
  ClauseStatus,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { computeExpiresAt } from '../clauses/clauses.constants';
import { FantasyAuthService } from './fantasy-auth.service';
@Injectable()
export class FantasySyncService {
  // How far apart (either way) a hand-registered clausulazo and its LALIGA movement may be to be
  // treated as the same movement.
  static readonly PROVISIONAL_MATCH_WINDOW_MS = 48 * 60 * 60 * 1000;

  private readonly leagueId = '017892931';
  private readonly competitionId = '1';

  // A partir de este momento empezamos a importar cláusulazos.
  // Todo lo anterior se ignora.
  private readonly syncStartAt = new Date(
    '2026-09-13T19:50:00+02:00',
  );

  // The sync currently running, if any (see `runScheduledSync`).
  private inFlightSync: ReturnType<
    FantasySyncService['syncActivity']
  > | null = null;

  constructor(
  private readonly prisma: PrismaService,
  private readonly fantasyAuthService: FantasyAuthService,
) {}
// Player details from LALIGA's player endpoint: name and official picture. The picture is
// `playerMaster.images.transparent["256x256"]`, a public PNG on LALIGA's asset CDN; it stays null when the
// payload doesn't carry it.
private async getPlayerDetails(
  token: string,
  playerMasterId: string,
): Promise<{ name: string | null; imageUrl: string | null } | null> {
  try {
    const response = await fetch(
      `https://fantasy-api.llt-services.com/api/v1/competition/${this.competitionId}/player/${playerMasterId}/league/${this.leagueId}?x-lang=es`,
      {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${token}`,
          'x-lang': 'es',
          'x-version': '10.0.6',
          'x-app': 'Fantasy-iOS',
          'User-Agent':
            'LaLigaFantasy/10.0.6 (com.lfp.laligafantasy; build:1; iOS 26.6.2) Alamofire/5.10.2',
        },
      },
    );

    if (!response.ok) {
      console.error(
        `No se pudo obtener el jugador ${playerMasterId}: ${response.status}`,
      );
      return null;
    }

    const data: any = await response.json();

    

    const possibleNames = [
      data?.playerMaster?.name,
      data?.player?.name,
      data?.name,
      data?.playerMaster?.player?.name,
      data?.playerMaster?.displayName,
      data?.displayName,
    ];

    const name = possibleNames.find(
      (value) =>
        typeof value === 'string' && value.trim().length > 0,
    );

    const image = data?.playerMaster?.images?.transparent?.['256x256'];
    const imageUrl =
      typeof image === 'string' && /^https:\/\//.test(image) ? image : null;

    return { name: name ? name.trim() : null, imageUrl };
  } catch (error) {
    console.error(
      `Error obteniendo el jugador ${playerMasterId}:`,
      error,
    );

    return null;
  }
}
  async syncActivity() {
    const token = await this.fantasyAuthService.getAccessToken();

    const response = await fetch(
      `https://fantasy-api.llt-services.com/api/v1/competition/${this.competitionId}/leagues/${this.leagueId}/activity/0?x-lang=es`,
      {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${token}`,
          'x-lang': 'es',
          'x-version': '10.0.6',
          'x-app': 'Fantasy-iOS',
          'User-Agent':
            'LaLigaFantasy/10.0.6 (com.lfp.laligafantasy; build:1; iOS 26.6.2) Alamofire/5.10.2',
        },
      },
    );

    if (!response.ok) {
      throw new Error(`LALIGA API respondió ${response.status}`);
    }

    const activities = await response.json();

    let detectedClauseTransfers = 0;
    let skippedBeforeStart = 0;
    let alreadyExists = 0;
    let created = 0;
    let skippedLimit = 0;
    let skippedUsers = 0;
    // Existing rows completed with data they were missing (player name, picture, amount).
    let updated = 0;
    // Provisional rows (created with "Ejecutar cláusulazo", no LALIGA data) merged with their LALIGA
    // movement, either by completing them or by folding them into the LALIGA row.
    let reconciled = 0;

    const detected: Array<{
      laligaActivityId: string;
      fromLaligaUserId: string;
      toLaligaUserId: string;
      playerMasterId: string;
      amount: number;
      createdAt: string;
      status: string;
      reason?: string;
    }> = [];

    // Activities not stored yet go first, so a provisional row is matched to the movement it belongs to
    // before an already stored movement of the same managers can fold it away.
    const storedIds = new Set(
      (
        await this.prisma.clause.findMany({
          where: {
            laligaActivityId: {
              in: activities.map((activity: any) => String(activity.id)),
            },
          },
          select: { laligaActivityId: true },
        })
      ).map((clause) => clause.laligaActivityId),
    );
    const ordered = [
      ...activities.filter((a: any) => !storedIds.has(String(a.id))),
      ...activities.filter((a: any) => storedIds.has(String(a.id))),
    ];

    for (const activity of ordered) {
      // Solo cláusulazos reales entre managers
      if (activity.activityTypeId !== 1 || !activity.user2Id) {
        continue;
      }

      const createdAt = new Date(activity.createdAt);

      // Ignorar absolutamente todo lo anterior al inicio del sistema.
      if (createdAt <= this.syncStartAt) {
        skippedBeforeStart++;
        continue;
      }

      detectedClauseTransfers++;

      const laligaActivityId = String(activity.id);
      const fromLaligaUserId = String(activity.user1Id);
      const toLaligaUserId = String(activity.user2Id);
      const playerMasterId = String(activity.playerMasterId);
      const amount = Number(activity.amount);
      // Best effort, and only fetched when a row actually needs it: stays null if LALIGA doesn't resolve
      // it, and the UI then shows a generic label.
      let player:
        | { name: string | null; imageUrl: string | null }
        | null
        | undefined;
      const resolvePlayer = async () => {
        if (player === undefined) {
          player = await this.getPlayerDetails(token, playerMasterId);
        }
        return player;
      };
      const resolvePlayerName = async () => (await resolvePlayer())?.name ?? null;

      // Buscar al usuario que realiza el cláusulazo.
      const fromUser = await this.prisma.user.findUnique({
        where: {
          laligaUserId: fromLaligaUserId,
        },
      });

      // Buscar al usuario que recibe el cláusulazo.
      const toUser = await this.prisma.user.findUnique({
        where: {
          laligaUserId: toLaligaUserId,
        },
      });

      // The LALIGA activity id is the movement's identity: one row per id (`laligaActivityId` is unique).
      const existingClause = await this.prisma.clause.findUnique({
        where: {
          laligaActivityId,
        },
      });

      if (existingClause) {
        alreadyExists++;

        const updateData: Prisma.ClauseUpdateInput = {};

        if (!existingClause.playerName) {
          const name = await resolvePlayerName();
          if (name) updateData.playerName = name;
        }

        if (!existingClause.playerImageUrl) {
          const imageUrl = (await resolvePlayer())?.imageUrl;
          if (imageUrl) updateData.playerImageUrl = imageUrl;
        }

        if (existingClause.amount == null && Number.isFinite(amount)) {
          updateData.amount = amount;
        }

        if (existingClause.playerMasterId == null) {
          updateData.playerMasterId = playerMasterId;
        }

        if (Object.keys(updateData).length > 0) {
          await this.prisma.clause.update({
            where: { id: existingClause.id },
            data: updateData,
          });
          updated++;
        }

        // A provisional row for this same movement may have been created before or after this one
        // (e.g. "Ejecutar cláusulazo" pressed once the sync had already imported it). Fold it in so only
        // this row remains.
        if (fromUser && toUser) {
          const provisional = await this.findProvisionalClause(
            fromUser.id,
            toUser.id,
            createdAt,
          );
          if (
            provisional &&
            (await this.foldProvisionalInto(provisional, existingClause))
          ) {
            reconciled++;
          }
        }

        detected.push({
          laligaActivityId,
          fromLaligaUserId,
          toLaligaUserId,
          playerMasterId,
          amount,
          createdAt: createdAt.toISOString(),
          status:
            existingClause.playerName || player?.name
              ? 'ALREADY_EXISTS'
              : 'ALREADY_EXISTS_NO_NAME',
        });

        continue;
      }

      // Si alguno no está vinculado, no podemos guardar el cláusulazo.
      if (!fromUser || !toUser) {
        skippedUsers++;

        detected.push({
          laligaActivityId,
          fromLaligaUserId,
          toLaligaUserId,
          playerMasterId,
          amount,
          createdAt: createdAt.toISOString(),
          status: 'SKIPPED',
          reason: !fromUser
            ? `No existe usuario con laligaUserId ${fromLaligaUserId}`
            : `No existe usuario con laligaUserId ${toLaligaUserId}`,
        });

        continue;
      }

      // Exactamente 7 días desde el momento del cláusulazo.
      const expiresAt = computeExpiresAt(createdAt);

      const officialData = {
        laligaActivityId,
        playerMasterId,
        playerName: await resolvePlayerName(),
        playerImageUrl: (await resolvePlayer())?.imageUrl ?? null,
        amount: Number.isFinite(amount) ? amount : null,
        createdAt,
        expiresAt,
      };

      // If the movement was already registered by hand ("Ejecutar cláusulazo"), complete that row with the
      // LALIGA data instead of creating a second one. Its classification and votes are kept.
      const provisional = await this.findProvisionalClause(
        fromUser.id,
        toUser.id,
        createdAt,
      );
      if (provisional) {
        const { count } = await this.prisma.clause.updateMany({
          where: { id: provisional.id, laligaActivityId: null },
          data: officialData,
        });
        if (count === 1) {
          reconciled++;
          detected.push({
            laligaActivityId,
            fromLaligaUserId,
            toLaligaUserId,
            playerMasterId,
            amount,
            createdAt: createdAt.toISOString(),
            status: 'RECONCILED',
          });
          continue;
        }
      }

      // Se guarda siempre, aunque el usuario ya tenga cláusulas activas, para no perder información de
      // LALIGA. Como PENDING no ocupa plaza no rompe el límite de 2; si luego se confirma como CLAUSE, la
      // app avisa del exceso.
      try {
        await this.prisma.clause.create({
          data: {
            ...officialData,
            fromUserId: fromUser.id,
            toUserId: toUser.id,
            status: 'ACTIVE',
            classification: 'PENDING',
          },
        });
      } catch (error) {
        // A sync running at the same time (cron and admin) already stored this activity.
        if (
          error instanceof Prisma.PrismaClientKnownRequestError &&
          error.code === 'P2002'
        ) {
          alreadyExists++;
          continue;
        }
        throw error;
      }

      created++;

      detected.push({
        laligaActivityId,
        fromLaligaUserId,
        toLaligaUserId,
        playerMasterId,
        amount,
        createdAt: createdAt.toISOString(),
        status: 'CREATED',
      });
    }

    return {
      syncStartAt: this.syncStartAt.toISOString(),
      totalActivities: activities.length,
      detectedClauseTransfers,
      skippedBeforeStart,
      alreadyExists,
      created,
      skippedLimit,
      skippedUsers,
      updated,
      reconciled,
      detected,
    };
  }

  /**
   * A provisional row is one registered by hand with "Ejecutar cláusulazo" (`POST /clauses`): same
   * managers, no LALIGA activity or player yet, not cancelled, and created within
   * `PROVISIONAL_MATCH_WINDOW_MS` of the LALIGA movement. When several qualify, the closest in time wins.
   */
  private async findProvisionalClause(
    fromUserId: string,
    toUserId: string,
    activityAt: Date,
  ) {
    const window = FantasySyncService.PROVISIONAL_MATCH_WINDOW_MS;
    const candidates = await this.prisma.clause.findMany({
      where: {
        fromUserId,
        toUserId,
        laligaActivityId: null,
        playerMasterId: null,
        status: { not: ClauseStatus.CANCELLED },
        createdAt: {
          gte: new Date(activityAt.getTime() - window),
          lte: new Date(activityAt.getTime() + window),
        },
      },
    });
    if (candidates.length === 0) return null;

    const distance = (c: { createdAt: Date }) =>
      Math.abs(c.createdAt.getTime() - activityAt.getTime());
    return candidates.reduce((best, c) =>
      distance(c) < distance(best) ? c : best,
    );
  }

  /**
   * Leaves only the LALIGA row when a provisional one for the same movement also exists. The provisional
   * row is cancelled (kept for audit, hidden from every listing, like `adminCancel`). Votes/classification
   * given on it carry over only if nobody has voted on the LALIGA row yet, so a manual "cláusulazo" isn't
   * turned back into PENDING. Returns whether it folded anything.
   */
  private async foldProvisionalInto(
    provisional: Clause,
    official: Clause,
  ): Promise<boolean> {
    const officialUntouched =
      official.fromConfirmation == null &&
      official.toConfirmation == null &&
      official.classification === ClauseClassification.PENDING;

    return this.prisma.$transaction(async (tx) => {
      const { count } = await tx.clause.updateMany({
        where: {
          id: provisional.id,
          laligaActivityId: null,
          status: { not: ClauseStatus.CANCELLED },
        },
        data: { status: ClauseStatus.CANCELLED, cancelledAt: new Date() },
      });
      if (count === 0) return false;

      if (officialUntouched && provisional.classification != null) {
        await tx.clause.update({
          where: { id: official.id },
          data: {
            classification: provisional.classification,
            fromConfirmation: provisional.fromConfirmation,
            toConfirmation: provisional.toConfirmation,
          },
        });
      }
      return true;
    });
  }

  /**
   * Runs `syncActivity()` and records the outcome so the dashboard can show "Sincronizado hace X min".
   * `lastSuccessAt` only moves on runs that complete; failures are recorded separately.
   *
   * Only one sync runs at a time in this process: a call arriving while one is in flight (the cron
   * overlapping a slow run, or the admin's manual sync) waits for that run and gets its result instead of
   * starting a second import. The slot is freed when the run settles, whether it succeeded or failed.
   */
  runScheduledSync() {
    this.inFlightSync ??= this.executeScheduledSync().finally(() => {
      this.inFlightSync = null;
    });
    return this.inFlightSync;
  }

  private async executeScheduledSync() {
    await this.recordAttempt();

    try {
      const result = await this.syncActivity();
      await this.recordSuccess(result);
      return result;
    } catch (error) {
      await this.recordFailure(
        error instanceof Error ? error.message : 'Error desconocido',
      );
      throw error;
    }
  }

  async getStatus() {
    const status = await this.prisma.fantasySyncStatus.findUnique({
      where: { id: 'fantasy' },
    });

    return {
      lastSuccessfulSyncAt: status?.lastSuccessAt ?? null,
      lastAttemptAt: status?.lastAttemptAt ?? null,
      lastStatus: status?.lastStatus ?? null,
      lastChangeCount: FantasySyncService.countChanges(status?.lastSummary),
    };
  }

  // Rows the last successful sync created or modified, read from its stored summary. Lets clients reload
  // their clauses only after a sync that actually changed something.
  private static countChanges(summary: Prisma.JsonValue | undefined): number {
    if (!summary || typeof summary !== 'object' || Array.isArray(summary)) {
      return 0;
    }
    return ['created', 'updated', 'reconciled'].reduce((total, key) => {
      const value = (summary as Prisma.JsonObject)[key];
      return total + (typeof value === 'number' ? value : 0);
    }, 0);
  }

  private async recordAttempt() {
    await this.prisma.fantasySyncStatus.upsert({
      where: { id: 'fantasy' },
      create: { id: 'fantasy', lastAttemptAt: new Date() },
      update: { lastAttemptAt: new Date() },
    });
  }

  private async recordSuccess(summary: unknown) {
    await this.prisma.fantasySyncStatus.upsert({
      where: { id: 'fantasy' },
      create: {
        id: 'fantasy',
        lastAttemptAt: new Date(),
        lastSuccessAt: new Date(),
        lastStatus: 'SUCCESS',
        lastError: null,
        lastSummary: summary as Prisma.InputJsonValue,
      },
      update: {
        lastSuccessAt: new Date(),
        lastStatus: 'SUCCESS',
        lastError: null,
        lastSummary: summary as Prisma.InputJsonValue,
      },
    });
  }

  private async recordFailure(message: string) {
    await this.prisma.fantasySyncStatus.upsert({
      where: { id: 'fantasy' },
      create: {
        id: 'fantasy',
        lastAttemptAt: new Date(),
        lastFailureAt: new Date(),
        lastStatus: 'FAILURE',
        lastError: message,
      },
      update: {
        lastFailureAt: new Date(),
        lastStatus: 'FAILURE',
        lastError: message,
      },
    });
  }

  async getLeagueUsers() {
    const token = await this.fantasyAuthService.getAccessToken();

    const response = await fetch(
      `https://fantasy-api.llt-services.com/api/v1/competition/${this.competitionId}/leagues/${this.leagueId}/standing?x-lang=es`,
      {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${token}`,
          'x-lang': 'es',
          'x-version': '10.0.6',
          'x-app': 'Fantasy-iOS',
          'User-Agent':
            'LaLigaFantasy/10.0.6 (com.lfp.laligafantasy; build:1; iOS 26.6.2) Alamofire/5.10.2',
        },
      },
    );

    if (!response.ok) {
      throw new Error(`LALIGA API respondió ${response.status}`);
    }

    return response.json();
  }

  // Per-jornada standing: for a played week N, `/leagues/{leagueId}/standing/{N}` returns each team's
  // points for that week (not the season total) and a `position` that already resolves ties. Summing
  // every played week per manager matches the season `team.teamPoints`. A week not played yet still
  // returns 200, with every team at 0 points.
  private async fetchWeekStanding(
    week: number,
    headers: Record<string, string>,
  ): Promise<any[] | null> {
    const response = await fetch(
      `https://fantasy-api.llt-services.com/api/v1/competition/${this.competitionId}/leagues/${this.leagueId}/standing/${week}`,
      { headers },
    );
    if (!response.ok) return null;
    const rows = await response.json();
    return Array.isArray(rows) ? rows : null;
  }

  // Fixtures for a jornada. `matchState: 7` means finished and `1` not played yet. A jornada counts as
  // finished only when every match is 7, so a single pending match (e.g. postponed) keeps the whole
  // jornada out of the calculation.
  private async fetchWeekCalendar(
    week: number,
    headers: Record<string, string>,
  ): Promise<any[] | null> {
    const response = await fetch(
      `https://fantasy-api.llt-services.com/api/v1/competition/${this.competitionId}/calendar?weekNumber=${week}&x-lang=es`,
      { headers },
    );
    if (!response.ok) return null;
    const rows = await response.json();
    return Array.isArray(rows) ? rows : null;
  }

  private static isWeekFinished(matches: any[]): boolean {
    return matches.length > 0 && matches.every((m) => m?.matchState === 7);
  }

  // Whether a jornada has started, from the kickoff times (`matchDate`) in the same
  // `/calendar?weekNumber` payload. Only used to choose which unfinished jornadas to warn about: one
  // whose kickoffs are all in the future is upcoming, not stuck pending. It doesn't affect
  // `isWeekFinished` or the money calculation.
  private static hasWeekStarted(matches: any[]): boolean {
    const now = Date.now();
    return matches.some((m) => {
      const kickoff = Date.parse(m?.matchDate ?? m?.date ?? '');
      return Number.isFinite(kickoff) && kickoff <= now;
    });
  }

  private authHeaders(token: string): Record<string, string> {
    return {
      Authorization: `Bearer ${token}`,
      'x-lang': 'es',
      'x-version': '10.0.6',
      'x-app': 'Fantasy-iOS',
      'User-Agent':
        'LaLigaFantasy/10.0.6 (com.lfp.laligafantasy; build:1; iOS 26.6.2) Alamofire/5.10.2',
    };
  }

  // League money rule: last place of a finished jornada owes 1,00€, penultimate 0,75€,
  // antepenultimate 0,50€. Uses LALIGA's own `position`, so a tie pays every tied manager (`.filter`,
  // not `.find`).
  private static computeWeekPayouts(
    rows: any[],
  ): Array<{ managerId: string; cents: number }> {
    const total = rows.length;
    const rules: Array<{ position: number; cents: number }> = [
      { position: total, cents: 100 },
      { position: total - 1, cents: 75 },
      { position: total - 2, cents: 50 },
    ];

    const payouts: Array<{ managerId: string; cents: number }> = [];
    for (const { position, cents } of rules) {
      if (position < 1) continue;
      for (const row of rows.filter((r) => r?.position === position)) {
        const managerId = String(
          row?.team?.manager?.id ?? row?.team?.managerId ?? '',
        );
        if (managerId) payouts.push({ managerId, cents });
      }
    }
    return payouts;
  }

  // Single scan of the jornada-by-jornada data, shared by `getLeagueDebts()` and
  // `getLeagueDebtHistory()` so both are built from the same facts. Each jornada is evaluated on its
  // own calendar (`fetchWeekCalendar`/`isWeekFinished`) and they are not assumed to be consecutive: a
  // pending one (e.g. a postponed match) is skipped while later finished ones still count. Nothing is
  // persisted, so results are recomputed from LALIGA on every call and repeated calls never double an
  // amount.
  private async scanFinishedWeeks(headers: Record<string, string>): Promise<{
    weeksEvaluated: number;
    pendingWeeks: number[];
    finishedWeeks: Array<{ week: number; rows: any[] }>;
    managers: Map<string, { managerId: string; managerName: string }>;
  }> {
    const managers = new Map<
      string,
      { managerId: string; managerName: string }
    >();
    const pendingWeeks: number[] = [];
    const finishedWeeks: Array<{ week: number; rows: any[] }> = [];

    let weeksEvaluated = 0;
    const MAX_WEEKS = 60; // safety cap; a season is well under this

    for (let week = 1; week <= MAX_WEEKS; week++) {
      // Calendar and standing are independent, so fetch both at once for each week.
      const [matches, rows] = await Promise.all([
        this.fetchWeekCalendar(week, headers),
        this.fetchWeekStanding(week, headers),
      ]);

      // No fixtures: past the end of the calendar.
      if (!matches || matches.length === 0) break;

      // Jornadas are played in order: once one hasn't kicked off, none after it has either, so stop here.
      // This keeps the scan fast, since only started jornadas are fetched.
      if (!FantasySyncService.hasWeekStarted(matches)) break;

      weeksEvaluated = week;

      // Register every manager seen, finished jornada or not, so one who never finishes last still shows
      // up with 0,00€.
      if (rows) {
        for (const row of rows) {
          const managerId = String(
            row?.team?.manager?.id ?? row?.team?.managerId ?? '',
          );
          if (!managerId) continue;
          const managerName =
            row?.team?.manager?.managerName ?? row?.team?.teamName ?? 'Manager';
          managers.set(managerId, { managerId, managerName });
        }
      }

      if (!FantasySyncService.isWeekFinished(matches)) {
        // Only report jornadas that have started (the current one, or an earlier one stuck on a postponed
        // match); a future jornada isn't pending.
        if (FantasySyncService.hasWeekStarted(matches)) {
          pendingWeeks.push(week);
        }
        continue; // no money for this jornada yet, but keep checking later ones
      }

      if (!rows || rows.length === 0) continue; // finished but no scoring data — nothing to pay out

      finishedWeeks.push({ week, rows });
    }

    return { weeksEvaluated, pendingWeeks, finishedWeeks, managers };
  }

  async getLeagueDebts() {
    const token = await this.fantasyAuthService.getAccessToken();
    const headers = this.authHeaders(token);
    const { weeksEvaluated, pendingWeeks, finishedWeeks, managers } =
      await this.scanFinishedWeeks(headers);

    const debts = new Map<
      string,
      { managerId: string; managerName: string; debtCents: number }
    >();
    for (const m of managers.values()) {
      debts.set(m.managerId, { ...m, debtCents: 0 });
    }

    for (const { rows } of finishedWeeks) {
      for (const { managerId, cents } of FantasySyncService.computeWeekPayouts(
        rows,
      )) {
        const entry = debts.get(managerId);
        if (entry) entry.debtCents += cents;
      }
    }

    const managersOut = Array.from(debts.values()).sort((a, b) => {
      if (b.debtCents !== a.debtCents) return b.debtCents - a.debtCents;
      return a.managerName.localeCompare(b.managerName);
    });

    return { weeksEvaluated, pendingWeeks, managers: managersOut };
  }

  // Feeds the "Tabla general" chart: accumulated debt per manager after each finished jornada, using
  // the same scan and payout rule as `getLeagueDebts()` so the last point matches the table. Pending
  // and future jornadas don't appear at all.
  async getLeagueDebtHistory() {
    const token = await this.fantasyAuthService.getAccessToken();
    const headers = this.authHeaders(token);
    const { pendingWeeks, finishedWeeks, managers } =
      await this.scanFinishedWeeks(headers);

    const cumulative = new Map<string, number>();
    for (const m of managers.values()) cumulative.set(m.managerId, 0);

    const points = finishedWeeks.map(({ week, rows }) => {
      for (const { managerId, cents } of FantasySyncService.computeWeekPayouts(
        rows,
      )) {
        cumulative.set(managerId, (cumulative.get(managerId) ?? 0) + cents);
      }
      return {
        week,
        managers: Array.from(managers.values()).map((m) => ({
          managerId: m.managerId,
          managerName: m.managerName,
          debtCents: cumulative.get(m.managerId) ?? 0,
        })),
      };
    });

    return { pendingWeeks, points };
  }

  async linkUserToLaliga(userId: string, laligaUserId: string) {
    return this.prisma.user.update({
      where: {
        id: userId,
      },
      data: {
        laligaUserId,
      },
      select: {
        id: true,
        name: true,
        email: true,
        laligaUserId: true,
      },
    });
  }
}
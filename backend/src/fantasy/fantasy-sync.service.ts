import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { FantasyAuthService } from './fantasy-auth.service';
@Injectable()
export class FantasySyncService {
  private readonly leagueId = '017892931';
  private readonly competitionId = '1';

  // A partir de este momento empezamos a importar cláusulazos.
  // Todo lo anterior se ignora.
  private readonly syncStartAt = new Date(
    '2026-09-13T19:50:00+02:00',
  );

  constructor(
  private readonly prisma: PrismaService,
  private readonly fantasyAuthService: FantasyAuthService,
) {}
private async getPlayerName(
  token: string,
  playerMasterId: string,
): Promise<string | null> {
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

    return name ? name.trim() : null;
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

const clauseActivity = activities.find(
  (activity: any) =>
    activity.activityTypeId === 1 && activity.user2Id,
);


    

    let detectedClauseTransfers = 0;
    let skippedBeforeStart = 0;
    let alreadyExists = 0;
    let created = 0;
    let skippedLimit = 0;
    let skippedUsers = 0;

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

    for (const activity of activities) {
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
      // Best effort: try the field names LALIGA's payload may use. Stays null if none exist, and the UI
      // then shows a generic label.
     const playerName = await this.getPlayerName(
  token,
  playerMasterId,
);

      // Evitar duplicados.
      const existingClause = await this.prisma.clause.findFirst({
        where: {
          laligaActivityId,
        },
      });

     if (existingClause) {
  alreadyExists++;

  const updateData: any = {};

  if (!existingClause.playerName && playerName) {
    updateData.playerName = playerName;
  }

  if (
    existingClause.amount == null &&
    Number.isFinite(amount)
  ) {
    updateData.amount = amount;
  }

  if (Object.keys(updateData).length > 0) {
    await this.prisma.clause.update({
      where: { id: existingClause.id },
      data: updateData,
    });
  }

  detected.push({
    laligaActivityId,
    fromLaligaUserId,
    toLaligaUserId,
    playerMasterId,
    amount,
    createdAt: createdAt.toISOString(),
    status: existingClause.playerName || playerName
      ? 'ALREADY_EXISTS'
      : 'ALREADY_EXISTS_NO_NAME',
  });

  continue;
}

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
      const expiresAt = new Date(
        createdAt.getTime() + 7 * 24 * 60 * 60 * 1000,
      );

      // Se guarda siempre, aunque el usuario ya tenga cláusulas activas, para no perder información de
      // LALIGA. Como PENDING no ocupa plaza no rompe el límite de 2; si luego se confirma como CLAUSE, la
      // app avisa del exceso.
      await this.prisma.clause.create({
        data: {
          laligaActivityId,
          playerMasterId,
          playerName,
          amount: Number.isFinite(amount) ? amount : null,
          fromUserId: fromUser.id,
          toUserId: toUser.id,
          createdAt,
          expiresAt,
          status: 'ACTIVE',
          classification: 'PENDING',
        },
      });

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
      detected,
    };
  }

  /**
   * Runs `syncActivity()` and records the outcome so the dashboard can show "Sincronizado hace X min".
   * `lastSuccessAt` only moves on runs that complete; failures are recorded separately.
   */
  async runScheduledSync() {
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
    };
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
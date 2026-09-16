import { Injectable } from '@nestjs/common';
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

    console.log(
      `RESPUESTA JUGADOR ${playerMasterId}:`,
      JSON.stringify(data),
    );

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
      // Best-effort: try the field names LALIGA's payload plausibly uses.
      // If none of these exist, this stays null and nothing else changes —
      // the clause is still saved exactly as before, just without a name
      // to show in the UI (which then falls back to a generic label).
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

      // Guardar el movimiento en PostgreSQL SIEMPRE, sin importar cuántas
      // cláusulas activas tenga ya cada usuario: no queremos perder
      // información de LALIGA. Como PENDING no ocupa plaza, un tercer (o
      // cuarto...) movimiento no rompe el límite de 2 — simplemente queda
      // pendiente de confirmar como cualquier otro, y si finalmente se
      // confirma como CLAUSE, la app mostrará el aviso de exceso.
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
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class FantasySyncService {
  private readonly leagueId = '017892931';
  private readonly competitionId = '1';

  // A partir de este momento empezamos a importar cláusulazos.
  // Todo lo anterior se ignora.
  private readonly syncStartAt = new Date(
    '2026-09-13T19:50:00+02:00',
  );

  constructor(private readonly prisma: PrismaService) {}

  async syncActivity() {
    const token = process.env.LALIGA_TOKEN;

    if (!token) {
      throw new Error('Falta LALIGA_TOKEN en .env');
    }

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

      // Evitar duplicados.
      const existingClause = await this.prisma.clause.findFirst({
        where: {
          laligaActivityId,
        },
      });

      if (existingClause) {
        alreadyExists++;

        detected.push({
          laligaActivityId,
          fromLaligaUserId,
          toLaligaUserId,
          playerMasterId,
          amount,
          createdAt: createdAt.toISOString(),
          status: 'ALREADY_EXISTS',
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
    const token = process.env.LALIGA_TOKEN;

    if (!token) {
      throw new Error('Falta LALIGA_TOKEN en .env');
    }

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
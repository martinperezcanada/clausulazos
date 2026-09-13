import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class FantasySyncService {
  private readonly leagueId = '017892931';
  private readonly competitionId = '1';

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

const detected: Array<{
  laligaActivityId: string;
  fromLaligaUserId: string;
  toLaligaUserId: string;
  playerMasterId: string;
  amount: number;
  createdAt: string;
  alreadyExists: boolean;
}> = [];    let alreadyExists = 0;

    for (const activity of activities) {
      // Solo cláusulazos reales entre managers
      if (activity.activityTypeId !== 1 || !activity.user2Id) {
        continue;
      }

      const laligaActivityId = String(activity.id);

      // Comprobar si ya existe en nuestra base de datos
      const existingClause = await this.prisma.clause.findFirst({
        where: {
          laligaActivityId,
        },
      });

      if (existingClause) {
        alreadyExists++;
      }

      detected.push({
        laligaActivityId,
        fromLaligaUserId: String(activity.user1Id),
        toLaligaUserId: String(activity.user2Id),
        playerMasterId: String(activity.playerMasterId),
        amount: activity.amount,
        createdAt: activity.createdAt,
        alreadyExists: !!existingClause,
      });
    }

    return {
      totalActivities: activities.length,
      detectedClauseTransfers: detected.length,
      alreadyExists,
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
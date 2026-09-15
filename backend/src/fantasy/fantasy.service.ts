import { Injectable } from '@nestjs/common';
import { FantasyAuthService } from './fantasy-auth.service';

@Injectable()
export class FantasyService {
  private readonly leagueId = '017892931';
  private readonly competitionId = '1';

  constructor(
    private readonly fantasyAuthService: FantasyAuthService,
  ) {}

  async getActivity() {
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
      throw new Error(
        `LALIGA API respondió ${response.status}`,
      );
    }

    return response.json();
  }
}
import {
  Controller,
  Get,
  Headers,
  InternalServerErrorException,
  Post,
  Param,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { FantasyService } from './fantasy.service';
import { FantasySyncService } from './fantasy-sync.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller('fantasy')
export class FantasyController {
  constructor(
    private readonly fantasyService: FantasyService,
    private readonly fantasySyncService: FantasySyncService,
  ) {}

  // Called by the GitHub Actions cron (.github/workflows/fantasy-sync.yml) with a plain `curl` and no
  // auth header, so it must stay reachable without a JWT. If FANTASY_SYNC_SECRET is set, an
  // `x-sync-secret` header check is enforced; when it is unset (the default) there is no check.
  @Get('sync')
  async sync(@Headers('x-sync-secret') syncSecret?: string) {
    const expectedSecret = process.env.FANTASY_SYNC_SECRET;
    if (expectedSecret && syncSecret !== expectedSecret) {
      throw new UnauthorizedException();
    }

    try {
      return await this.fantasySyncService.runScheduledSync();
    } catch (error) {
      throw new InternalServerErrorException(
        error instanceof Error ? error.message : 'Error desconocido',
      );
    }
  }

  // Feeds the dashboard's "Sincronizado hace X min" from the persisted timestamp.
  @UseGuards(JwtAuthGuard)
  @Get('sync/status')
  async syncStatus() {
    try {
      return await this.fantasySyncService.getStatus();
    } catch (error) {
      throw new InternalServerErrorException(
        error instanceof Error ? error.message : 'Error desconocido',
      );
    }
  }

  @UseGuards(JwtAuthGuard)
  @Get('activity')
  async activity() {
    try {
      return await this.fantasyService.getActivity();
    } catch (error) {
      throw new InternalServerErrorException(
        error instanceof Error ? error.message : 'Error desconocido',
      );
    }
  }

  // Also exposed as /fantasy/standings; both routes return the same LALIGA standing data.
  @UseGuards(JwtAuthGuard)
  @Get('users')
  async users() {
    try {
      return await this.fantasySyncService.getLeagueUsers();
    } catch (error) {
      throw new InternalServerErrorException(
        error instanceof Error ? error.message : 'Error desconocido',
      );
    }
  }

  @UseGuards(JwtAuthGuard)
  @Get('standings')
  async standings() {
    try {
      return await this.fantasySyncService.getLeagueUsers();
    } catch (error) {
      throw new InternalServerErrorException(
        error instanceof Error ? error.message : 'Error desconocido',
      );
    }
  }

  // Feeds the "Tabla general" tab: accumulated debt per manager (money rule and tie handling in
  // `FantasySyncService.getLeagueDebts()`).
  @UseGuards(JwtAuthGuard)
  @Get('debts')
  async debts() {
    try {
      return await this.fantasySyncService.getLeagueDebts();
    } catch (error) {
      throw new InternalServerErrorException(
        error instanceof Error ? error.message : 'Error desconocido',
      );
    }
  }

  // Feeds the chart under "Tabla general" (see `FantasySyncService.getLeagueDebtHistory()`).
  @UseGuards(JwtAuthGuard)
  @Get('debts/history')
  async debtsHistory() {
    try {
      return await this.fantasySyncService.getLeagueDebtHistory();
    } catch (error) {
      throw new InternalServerErrorException(
        error instanceof Error ? error.message : 'Error desconocido',
      );
    }
  }

  @UseGuards(JwtAuthGuard)
  @Post('link-user/:userId/:laligaUserId')
  async linkUser(
    @Param('userId') userId: string,
    @Param('laligaUserId') laligaUserId: string,
  ) {
    try {
      return await this.fantasySyncService.linkUserToLaliga(
        userId,
        laligaUserId,
      );
    } catch (error) {
      throw new InternalServerErrorException(
        error instanceof Error ? error.message : 'Error desconocido',
      );
    }
  }
}

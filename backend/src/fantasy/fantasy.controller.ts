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

  // NOTE: this endpoint is called by the GitHub Actions cron
  // (.github/workflows/fantasy-sync.yml) via a plain `curl`, with no auth
  // header — it MUST stay reachable without a JWT or the automatic sync
  // breaks. If FANTASY_SYNC_SECRET is set in the environment, an optional
  // `x-sync-secret` header check is enforced instead; if it's unset (the
  // default, and the current production behaviour), no check is done at
  // all, so nothing changes unless you explicitly opt in.
  @Get('sync')
  async sync(@Headers('x-sync-secret') syncSecret?: string) {
    const expectedSecret = process.env.FANTASY_SYNC_SECRET;
    if (expectedSecret && syncSecret !== expectedSecret) {
      throw new UnauthorizedException();
    }

    try {
      return await this.fantasySyncService.syncActivity();
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

  // Also exposed as /fantasy/standings (clearer name for the league
  // standings screen) — both point at the same LALIGA "standing" data.
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

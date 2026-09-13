import {
  Controller,
  Get,
  InternalServerErrorException,
  Post,
  Param,
} from '@nestjs/common';
import { FantasyService } from './fantasy.service';
import { FantasySyncService } from './fantasy-sync.service';

@Controller('fantasy')
export class FantasyController {
  constructor(
    private readonly fantasyService: FantasyService,
    private readonly fantasySyncService: FantasySyncService,
  ) {}

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

  @Get('sync')
  async sync() {
    try {
      return await this.fantasySyncService.syncActivity();
    } catch (error) {
      throw new InternalServerErrorException(
        error instanceof Error ? error.message : 'Error desconocido',
      );
    }
  }

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
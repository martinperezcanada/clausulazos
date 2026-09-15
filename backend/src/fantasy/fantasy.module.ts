import { Module } from '@nestjs/common';
import { FantasyController } from './fantasy.controller';
import { FantasyService } from './fantasy.service';
import { FantasySyncService } from './fantasy-sync.service';
import { FantasyAuthService } from './fantasy-auth.service';

@Module({
  controllers: [FantasyController],
  providers: [
    FantasyService,
    FantasySyncService,
    FantasyAuthService,
  ],
  exports: [
    FantasyService,
    FantasySyncService,
    FantasyAuthService,
  ],
})
export class FantasyModule {}
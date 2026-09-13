import { Module } from '@nestjs/common';
import { FantasyController } from './fantasy.controller';
import { FantasyService } from './fantasy.service';
import { FantasySyncService } from './fantasy-sync.service';

@Module({
  controllers: [FantasyController],
  providers: [FantasyService, FantasySyncService],
  exports: [FantasyService, FantasySyncService],
})
export class FantasyModule {}
import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { ClausesService } from './clauses.service';
import { ClausesController } from './clauses.controller';

@Module({
  imports: [AuthModule, NotificationsModule],
  controllers: [ClausesController],
  providers: [ClausesService],
  exports: [ClausesService],
})
export class ClausesModule {}

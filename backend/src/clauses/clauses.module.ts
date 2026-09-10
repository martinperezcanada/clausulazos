import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { ClausesService } from './clauses.service';
import { ClausesController } from './clauses.controller';

@Module({
  imports: [AuthModule],
  controllers: [ClausesController],
  providers: [ClausesService],
  exports: [ClausesService],
})
export class ClausesModule {}

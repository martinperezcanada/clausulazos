import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { ClausesModule } from '../clauses/clauses.module';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';

@Module({
  imports: [AuthModule, ClausesModule],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}

import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PasskeysService } from './passkeys.service';
import { PasskeysController } from './passkeys.controller';

@Module({
  imports: [AuthModule],
  controllers: [PasskeysController],
  providers: [PasskeysService],
})
export class PasskeysModule {}

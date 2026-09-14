import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ClausesModule } from './clauses/clauses.module';
import { FantasyModule } from './fantasy/fantasy.module';
import { PasskeysModule } from './passkeys/passkeys.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    // Sensible default rate limit applied to every route unless overridden
    // with a per-route @Throttle()/@SkipThrottle() — mainly here to blunt
    // brute-force attempts against auth/login/passkey endpoints.
    ThrottlerModule.forRoot([
      {
        ttl: 60_000,
        limit: 120,
      },
    ]),
    PrismaModule,
    AuthModule,
    UsersModule,
    ClausesModule,
    FantasyModule,
    PasskeysModule,
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}
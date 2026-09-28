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
    // Default rate limit for every route; individual routes override it with @Throttle()/@SkipThrottle().
    // Mainly here to slow down brute-force attempts on the auth endpoints.
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
import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import type {
  RegistrationResponseJSON,
  AuthenticationResponseJSON,
} from '@simplewebauthn/server';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser, CurrentUserPayload } from '../auth/decorators/current-user.decorator';
import { AuthService } from '../auth/auth.service';
import { PasskeysService } from './passkeys.service';
import { VerifyRegistrationDto } from './dto/verify-registration.dto';
import { LoginOptionsDto, VerifyAuthenticationDto } from './dto/login-options.dto';

// A handful of requests per minute is more than enough for a real user
// registering/logging in, while still blunting brute-force attempts.
const AUTH_THROTTLE = { default: { limit: 10, ttl: 60_000 } };

@Controller('auth/passkeys')
export class PasskeysController {
  constructor(
    private readonly passkeysService: PasskeysService,
    private readonly authService: AuthService,
  ) {}

  // ---- Registering a passkey (must already be logged in) ----

  @UseGuards(JwtAuthGuard)
  @Throttle(AUTH_THROTTLE)
  @Post('registration/options')
  registrationOptions(@CurrentUser() user: CurrentUserPayload) {
    return this.passkeysService.generateRegistrationOptionsFor(user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Throttle(AUTH_THROTTLE)
  @Post('registration/verify')
  registrationVerify(
    @CurrentUser() user: CurrentUserPayload,
    @Body() dto: VerifyRegistrationDto,
  ) {
    return this.passkeysService.verifyRegistration(
      user.sub,
      dto.response as unknown as RegistrationResponseJSON,
      dto.name,
    );
  }

  // ---- Logging in with a passkey (no session yet) ----

  @Throttle(AUTH_THROTTLE)
  @Post('authentication/options')
  authenticationOptions(@Body() dto: LoginOptionsDto) {
    return this.passkeysService.generateAuthenticationOptionsFor(dto.email);
  }

  @Throttle(AUTH_THROTTLE)
  @Post('authentication/verify')
  async authenticationVerify(@Body() dto: VerifyAuthenticationDto) {
    const user = await this.passkeysService.verifyAuthenticationAndGetUser(
      dto.response as unknown as AuthenticationResponseJSON,
    );
    return this.authService.issueSessionFor(user);
  }

  // ---- Managing passkeys from the profile screen ----

  @UseGuards(JwtAuthGuard)
  @Get()
  list(@CurrentUser() user: CurrentUserPayload) {
    return this.passkeysService.listForUser(user.sub);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  remove(@CurrentUser() user: CurrentUserPayload, @Param('id') id: string) {
    return this.passkeysService.remove(user.sub, id);
  }
}

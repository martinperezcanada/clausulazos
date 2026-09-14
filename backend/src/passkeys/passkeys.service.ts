import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import {
  generateRegistrationOptions,
  verifyRegistrationResponse,
  generateAuthenticationOptions,
  verifyAuthenticationResponse,
} from '@simplewebauthn/server';
import type {
  RegistrationResponseJSON,
  AuthenticationResponseJSON,
} from '@simplewebauthn/server';
import { PrismaService } from '../prisma/prisma.service';
import {
  WEBAUTHN_CHALLENGE_TTL_MS,
  getExpectedOrigins,
  getRpId,
  getRpName,
} from './passkeys.constants';

@Injectable()
export class PasskeysService {
  constructor(private readonly prisma: PrismaService) {}

  // ---- Registration (adding a passkey to an already-logged-in account) ----

  async generateRegistrationOptionsFor(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { passkeys: true },
    });
    if (!user) {
      throw new NotFoundException('Usuario no encontrado');
    }

    const options = await generateRegistrationOptions({
      rpName: getRpName(),
      rpID: getRpId(),
      userName: user.email,
      userDisplayName: user.name,
      attestationType: 'none', // we don't need attestation chains — just a usable key
      excludeCredentials: user.passkeys.map((p) => ({
        id: p.credentialId,
        transports: (p.transports as any) ?? undefined,
      })),
      authenticatorSelection: {
        // 'required' is what makes the credential discoverable, which is
        // what lets Face ID show a picker with no email typed first.
        residentKey: 'required',
        userVerification: 'preferred',
      },
    });

    await this.storeChallenge(userId, options.challenge, 'REGISTRATION');
    return options;
  }

  async verifyRegistration(userId: string, response: RegistrationResponseJSON, name?: string) {
    let verification;
    try {
      verification = await verifyRegistrationResponse({
        response,
        expectedChallenge: (challenge) => this.consumeChallenge(challenge, 'REGISTRATION', userId),
        expectedOrigin: getExpectedOrigins(),
        expectedRPID: getRpId(),
      });
    } catch (error) {
      throw new BadRequestException(
        error instanceof Error ? error.message : 'No se ha podido verificar la passkey',
      );
    }

    if (!verification.verified || !verification.registrationInfo) {
      throw new BadRequestException('No se ha podido verificar la passkey');
    }

    const { credential, credentialDeviceType, credentialBackedUp } = verification.registrationInfo;

    const existing = await this.prisma.passkeyCredential.findUnique({
      where: { credentialId: credential.id },
    });
    if (existing) {
      throw new ConflictException('Esta passkey ya está registrada');
    }

    const saved = await this.prisma.passkeyCredential.create({
      data: {
        userId,
        credentialId: credential.id,
        publicKey: Buffer.from(credential.publicKey),
        counter: credential.counter,
        transports: credential.transports ?? [],
        deviceType: credentialDeviceType,
        backedUp: credentialBackedUp,
        name: name?.trim() || null,
      },
    });

    return this.toPublicCredential(saved);
  }

  // ---- Authentication (logging in with a passkey, before any JWT exists) ----

  async generateAuthenticationOptionsFor(email?: string) {
    let allowCredentials: { id: string; transports?: string[] }[] | undefined;

    if (email) {
      const user = await this.prisma.user.findUnique({
        where: { email: email.toLowerCase() },
        include: { passkeys: true },
      });
      // Deliberately don't reveal whether the email exists: with no
      // passkeys registered we just fall back to a discoverable/usernameless
      // prompt, same as if no email had been given at all.
      if (user && user.passkeys.length > 0) {
        allowCredentials = user.passkeys.map((p) => ({
          id: p.credentialId,
          transports: (p.transports as any) ?? undefined,
        }));
      }
    }

    const options = await generateAuthenticationOptions({
      rpID: getRpId(),
      userVerification: 'preferred',
      allowCredentials,
    });

    await this.storeChallenge(null, options.challenge, 'AUTHENTICATION');
    return options;
  }

  async verifyAuthenticationAndGetUser(response: AuthenticationResponseJSON) {
    const credentialRecord = await this.prisma.passkeyCredential.findUnique({
      where: { credentialId: response.id },
      include: { user: true },
    });
    if (!credentialRecord) {
      throw new UnauthorizedException('Passkey no reconocida');
    }

    let verification;
    try {
      verification = await verifyAuthenticationResponse({
        response,
        expectedChallenge: (challenge) => this.consumeChallenge(challenge, 'AUTHENTICATION', null),
        expectedOrigin: getExpectedOrigins(),
        expectedRPID: getRpId(),
        credential: {
          id: credentialRecord.credentialId,
          publicKey: new Uint8Array(credentialRecord.publicKey),
          counter: credentialRecord.counter,
          transports: (credentialRecord.transports as any) ?? undefined,
        },
      });
    } catch (error) {
      throw new UnauthorizedException(
        error instanceof Error ? error.message : 'No se ha podido verificar la passkey',
      );
    }

    if (!verification.verified) {
      throw new UnauthorizedException('No se ha podido verificar la passkey');
    }

    // Replay-attack guard: the authenticator's own counter must not go
    // backwards or stay stuck on a previously-seen value.
    if (
      verification.authenticationInfo.newCounter !== 0 &&
      verification.authenticationInfo.newCounter <= credentialRecord.counter
    ) {
      throw new UnauthorizedException('Posible reutilización de passkey detectada');
    }

    await this.prisma.passkeyCredential.update({
      where: { id: credentialRecord.id },
      data: {
        counter: verification.authenticationInfo.newCounter,
        lastUsedAt: new Date(),
      },
    });

    return credentialRecord.user;
  }

  // ---- Management (profile screen) ----

  async listForUser(userId: string) {
    const credentials = await this.prisma.passkeyCredential.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
    return credentials.map((c) => this.toPublicCredential(c));
  }

  async remove(userId: string, credentialRecordId: string) {
    const credential = await this.prisma.passkeyCredential.findUnique({
      where: { id: credentialRecordId },
    });
    if (!credential) {
      throw new NotFoundException('Passkey no encontrada');
    }
    if (credential.userId !== userId) {
      throw new ForbiddenException('Esta passkey no pertenece a tu cuenta');
    }
    await this.prisma.passkeyCredential.delete({ where: { id: credentialRecordId } });
    return { success: true };
  }

  // ---- Internal helpers ----

  private async storeChallenge(
    userId: string | null,
    challenge: string,
    type: 'REGISTRATION' | 'AUTHENTICATION',
  ) {
    await this.prisma.webAuthnChallenge.create({
      data: {
        userId,
        challenge,
        type,
        expiresAt: new Date(Date.now() + WEBAUTHN_CHALLENGE_TTL_MS),
      },
    });
  }

  /**
   * Atomically marks a challenge as used, returning true only the first
   * time it's called for that exact challenge (and false for anything
   * expired, unknown, already-used, or for the wrong user/type). This is
   * what makes challenges single-use and prevents replay attacks against
   * the challenge itself — @simplewebauthn calls this as part of
   * verifying the signed response, so a stolen/replayed response can never
   * be verified twice.
   */
  private async consumeChallenge(
    challenge: string,
    type: 'REGISTRATION' | 'AUTHENTICATION',
    userId: string | null,
  ): Promise<boolean> {
    const result = await this.prisma.webAuthnChallenge.updateMany({
      where: {
        challenge,
        type,
        usedAt: null,
        expiresAt: { gt: new Date() },
        ...(userId ? { userId } : {}),
      },
      data: { usedAt: new Date() },
    });
    return result.count === 1;
  }

  private toPublicCredential(credential: {
    id: string;
    name: string | null;
    deviceType: string | null;
    backedUp: boolean;
    transports: string[];
    createdAt: Date;
    lastUsedAt: Date | null;
  }) {
    // Never return publicKey/counter/credentialId — nothing here helps an
    // attacker, but there's no reason to expose internal verification
    // material to the client either.
    return {
      id: credential.id,
      name: credential.name,
      deviceType: credential.deviceType,
      backedUp: credential.backedUp,
      transports: credential.transports,
      createdAt: credential.createdAt,
      lastUsedAt: credential.lastUsedAt,
    };
  }
}

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

interface LaLigaTokenResponse {
  access_token: string;
  token_type: string;
  expires_in: number;
  refresh_token?: string;
  refresh_token_expires_in?: number;
  scope?: string;
}

@Injectable()
export class FantasyAuthService {
  private readonly tokenUrl =
    'https://login.laliga.es/laligadspprob2c.onmicrosoft.com/oauth2/v2.0/token?p=B2C_1A_5ULAIP_PARAMETRIZED_SIGNIN';

  private readonly clientId =
    'af88bcff-1157-40a0-b579-030728aacf0b';

  private readonly scope =
    'af88bcff-1157-40a0-b579-030728aacf0b openid offline_access';

  constructor(private readonly prisma: PrismaService) {}

  async getAccessToken(): Promise<string> {
    const auth = await this.prisma.fantasyAuthToken.findUnique({
      where: {
        id: 'laliga',
      },
    });

    // Si todavía no existe ningún token en la base de datos,
    // usamos el refresh token inicial configurado en Render/.env.
    if (!auth) {
      const initialRefreshToken = process.env.LALIGA_REFRESH_TOKEN;

      if (!initialRefreshToken) {
        throw new Error(
          'Falta LALIGA_REFRESH_TOKEN en las variables de entorno',
        );
      }

      await this.prisma.fantasyAuthToken.create({
        data: {
          id: 'laliga',
          refreshToken: initialRefreshToken,
        },
      });

      return this.refreshAccessToken(initialRefreshToken);
    }

    // Si tenemos un access token válido durante al menos los
    // próximos 5 minutos, lo reutilizamos.
    if (
      auth.accessToken &&
      auth.accessTokenExpiresAt &&
      auth.accessTokenExpiresAt.getTime() > Date.now() + 5 * 60 * 1000
    ) {
      return auth.accessToken;
    }

    return this.refreshAccessToken(auth.refreshToken);
  }

  private async refreshAccessToken(
    refreshToken: string,
  ): Promise<string> {
    const body = new URLSearchParams();

    body.set('grant_type', 'refresh_token');
    body.set('client_id', this.clientId);
    body.set('refresh_token', refreshToken);
    body.set('scope', this.scope);

    const response = await fetch(this.tokenUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body.toString(),
    });

    if (!response.ok) {
      const errorText = await response.text();

      throw new Error(
        `No se pudo renovar el token de LaLiga (${response.status}): ${errorText}`,
      );
    }

    const tokenResponse =
      (await response.json()) as LaLigaTokenResponse;

    if (!tokenResponse.access_token) {
      throw new Error(
        'LaLiga no devolvió un access_token al renovar el token',
      );
    }

    const accessTokenExpiresAt = new Date(
      Date.now() + tokenResponse.expires_in * 1000,
    );

    const refreshTokenExpiresAt =
      tokenResponse.refresh_token_expires_in
        ? new Date(
            Date.now() +
              tokenResponse.refresh_token_expires_in * 1000,
          )
        : undefined;

    await this.prisma.fantasyAuthToken.upsert({
      where: {
        id: 'laliga',
      },
      create: {
        id: 'laliga',
        refreshToken:
          tokenResponse.refresh_token ?? refreshToken,
        accessToken: tokenResponse.access_token,
        accessTokenExpiresAt,
        refreshTokenExpiresAt,
      },
      update: {
        refreshToken:
          tokenResponse.refresh_token ?? refreshToken,
        accessToken: tokenResponse.access_token,
        accessTokenExpiresAt,
        ...(refreshTokenExpiresAt
          ? { refreshTokenExpiresAt }
          : {}),
      },
    });

    return tokenResponse.access_token;
  }
}
import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { FirebaseAdminService } from './firebase-admin.service';

export interface PushNotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

export type SendToUserResult =
  | { devicesNotified: number; reason?: undefined }
  | { devicesNotified: 0; reason: 'NO_DEVICE' | 'NOT_CONFIGURED' | 'SEND_FAILED' };

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly firebaseAdmin: FirebaseAdminService,
  ) {}

  /**
   * Registers a device's FCM token for `userId`. The token is unique, so calling again just updates the
   * row, including reassigning it when the same device logs in as another user.
   */
  async registerDevice(userId: string, token: string, platform?: string) {
    await this.prisma.notificationDevice.upsert({
      where: { token },
      create: { userId, token, platform },
      update: { userId, platform },
    });
  }

  async getDevicesForUser(userId: string) {
    return this.prisma.notificationDevice.findMany({ where: { userId } });
  }

  /**
   * Sends `payload` to every device registered for `userId`. Never throws: missing Firebase config, no
   * devices or failed sends are returned as a result. Tokens Firebase reports as unregistered are deleted.
   */
  async sendToUser(userId: string, payload: PushNotificationPayload): Promise<SendToUserResult> {
    const devices = await this.getDevicesForUser(userId);
    if (devices.length === 0) {
      return { devicesNotified: 0, reason: 'NO_DEVICE' };
    }

    if (!this.firebaseAdmin.isConfigured) {
      this.logger.warn('sendToUser: Firebase Admin no configurado — push omitido.');
      return { devicesNotified: 0, reason: 'NOT_CONFIGURED' };
    }

    const tokens = devices.map((d) => d.token);

    try {
      const messaging = this.firebaseAdmin.getMessaging();
      const response = await messaging.sendEachForMulticast({
        tokens,
        notification: { title: payload.title, body: payload.body },
        data: payload.data,
      });

      const invalidTokens: string[] = [];
      response.responses.forEach((result, index) => {
        if (result.success) return;
        const code = result.error?.code;
        this.logger.warn(`Push a dispositivo ${this.maskToken(tokens[index])} falló: ${code}`);
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/invalid-argument'
        ) {
          invalidTokens.push(tokens[index]);
        }
      });

      if (invalidTokens.length > 0) {
        await this.prisma.notificationDevice.deleteMany({ where: { token: { in: invalidTokens } } });
      }

      return { devicesNotified: response.successCount };
    } catch (error) {
      this.logger.error(`sendToUser: fallo inesperado enviando push — ${(error as Error).message}`);
      return { devicesNotified: 0, reason: 'SEND_FAILED' };
    }
  }

  // Log only a token prefix.
  private maskToken(token: string): string {
    return token.length <= 8 ? '***' : `${token.slice(0, 4)}…${token.slice(-4)}`;
  }
}

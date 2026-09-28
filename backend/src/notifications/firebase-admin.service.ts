import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { App, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging, Messaging } from 'firebase-admin/messaging';

/**
 * Initializes the Firebase Admin SDK from server credentials in env vars (see `.env.example`).
 * Never throws on construction, so the app and the tests run without credentials; callers check
 * `isConfigured` and fail a single push instead of the whole request.
 */
@Injectable()
export class FirebaseAdminService {
  private readonly logger = new Logger(FirebaseAdminService.name);
  private app: App | null = null;
  private warnedOnce = false;

  constructor(private readonly config: ConfigService) {
    this.tryInitialize();
  }

  get isConfigured(): boolean {
    return this.app !== null;
  }

  getMessaging(): Messaging {
    if (!this.app) {
      throw new Error('Firebase Admin no está configurado (faltan credenciales de servidor).');
    }
    return getMessaging(this.app);
  }

  private tryInitialize() {
    const projectId = this.config.get<string>('FIREBASE_PROJECT_ID');
    const clientEmail = this.config.get<string>('FIREBASE_CLIENT_EMAIL');
    const rawPrivateKey = this.config.get<string>('FIREBASE_PRIVATE_KEY');

    if (!projectId || !clientEmail || !rawPrivateKey) {
      this.warnNotConfiguredOnce();
      return;
    }

    try {
      // Env vars are single-line, so the private key comes with escaped \n sequences; restore real newlines.
      const privateKey = rawPrivateKey.replace(/\\n/g, '\n');

      const existing = getApps();
      this.app = existing.length
        ? existing[0]
        : initializeApp({ credential: cert({ projectId, clientEmail, privateKey }) });
      this.logger.log('Firebase Admin inicializado correctamente.');
    } catch (error) {
      this.logger.error(`Firebase Admin: fallo al inicializar — ${(error as Error).message}`);
      this.app = null;
    }
  }

  private warnNotConfiguredOnce() {
    if (this.warnedOnce) return;
    this.warnedOnce = true;
    this.logger.warn(
      'Firebase Admin no configurado: faltan FIREBASE_PROJECT_ID / FIREBASE_CLIENT_EMAIL / ' +
        'FIREBASE_PRIVATE_KEY. Las notificaciones push quedan deshabilitadas hasta que se configuren ' +
        '(ver .env.example).',
    );
  }
}

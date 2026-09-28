import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { CurrentUserPayload } from '../decorators/current-user.decorator';

// Runs after `JwtAuthGuard`, so `request.user` is the freshly loaded user (JwtStrategy re-reads it
// on every request). The admin switch in the Flutter app is UI only; this guard is the real check.
const ADMIN_EMAIL = (process.env.ADMIN_EMAIL || 'martin0345@gmail.com')
  .trim()
  .toLowerCase();

@Injectable()
export class AdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const user = request.user as CurrentUserPayload | undefined;

    if (!user || user.email.trim().toLowerCase() !== ADMIN_EMAIL) {
      throw new ForbiddenException('Esta acción requiere permisos de administrador');
    }

    return true;
  }
}

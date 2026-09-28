import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser, CurrentUserPayload } from '../auth/decorators/current-user.decorator';
import { NotificationsService } from './notifications.service';
import { RegisterDeviceDto } from './dto/register-device.dto';

@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  // The owner always comes from the JWT, never from the client.
  @Post('devices')
  async registerDevice(@CurrentUser() user: CurrentUserPayload, @Body() dto: RegisterDeviceDto) {
    await this.notificationsService.registerDevice(user.sub, dto.token, dto.platform);
    return { success: true };
  }
}

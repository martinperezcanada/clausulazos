import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AdminGuard } from '../auth/guards/admin.guard';
import { CurrentUser, CurrentUserPayload } from '../auth/decorators/current-user.decorator';
import { NotificationsService } from '../notifications/notifications.service';
import { ClausesService } from './clauses.service';
import { CreateClauseDto } from './dto/create-clause.dto';
import { ConfirmClauseClassificationDto } from './dto/confirm-clause-classification.dto';

@UseGuards(JwtAuthGuard)
@Controller('clauses')
export class ClausesController {
  constructor(
    private readonly clausesService: ClausesService,
    private readonly notificationsService: NotificationsService,
  ) {}

  @Post()
  create(@CurrentUser() user: CurrentUserPayload, @Body() dto: CreateClauseDto) {
    // fromUserId comes only from the authenticated user.
    return this.clausesService.create(user.sub, dto.toUserId);
  }

  @Get()
  findAll() {
    return this.clausesService.findAll();
  }

  @Get('me')
  findMine(@CurrentUser() user: CurrentUserPayload) {
    return this.clausesService.findForUser(user.sub);
  }

  @Patch(':id/classification')
  confirmClassification(
    @CurrentUser() user: CurrentUserPayload,
    @Param('id') id: string,
    @Body() dto: ConfirmClauseClassificationDto,
  ) {
    // The service re-checks that `user.sub` is a participant.
    return this.clausesService.confirmClassification(id, user.sub, dto.classification);
  }

  @Delete(':id')
  remove(@CurrentUser() user: CurrentUserPayload, @Param('id') id: string) {
    return this.clausesService.cancel(id, user.sub);
  }

  // Admin-only: removes any movement, whoever created it. The admin switch in Flutter is UI only;
  // `AdminGuard` checks the real user.
  @UseGuards(AdminGuard)
  @Delete(':id/admin')
  adminRemove(@Param('id') id: string) {
    return this.clausesService.adminCancel(id);
  }

  // Reminds the participant who still hasn't voted on a PENDING movement and, if they have a registered
  // device, sends them an FCM push. The recipient is derived from the clause, never from the client.
  @Post(':id/remind')
  async remindParticipant(@CurrentUser() user: CurrentUserPayload, @Param('id') id: string) {
    const { notification, recipientId, recipientName, requesterName } =
      await this.clausesService.remindParticipant(id, user.sub);

    const pushResult = await this.notificationsService.sendToUser(recipientId, {
      title: 'CLAUSULAZOS',
      body: `${requesterName} necesita tu confirmación`,
      data: {
        type: 'pending_confirmation',
        clauseId: id,
        route: '/activity',
      },
    });

    return {
      success: pushResult.devicesNotified > 0,
      reason: pushResult.reason,
      message: notification.message,
      notifiedUser: { id: recipientId, name: recipientName },
      devicesNotified: pushResult.devicesNotified,
    };
  }
}

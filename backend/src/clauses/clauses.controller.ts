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
import { CurrentUser, CurrentUserPayload } from '../auth/decorators/current-user.decorator';
import { ClausesService } from './clauses.service';
import { CreateClauseDto } from './dto/create-clause.dto';
import { ConfirmClauseClassificationDto } from './dto/confirm-clause-classification.dto';

@UseGuards(JwtAuthGuard)
@Controller('clauses')
export class ClausesController {
  constructor(private readonly clausesService: ClausesService) {}

  @Post()
  create(@CurrentUser() user: CurrentUserPayload, @Body() dto: CreateClauseDto) {
    // fromUserId comes exclusively from the authenticated JWT user.
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
    // The service re-checks that `user.sub` is actually a participant —
    // never trust the client for this.
    return this.clausesService.confirmClassification(id, user.sub, dto.classification);
  }

  @Delete(':id')
  remove(@CurrentUser() user: CurrentUserPayload, @Param('id') id: string) {
    return this.clausesService.cancel(id, user.sub);
  }
}

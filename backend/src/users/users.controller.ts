import { Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AdminGuard } from '../auth/guards/admin.guard';
import { CurrentUser, CurrentUserPayload } from '../auth/decorators/current-user.decorator';
import { UsersService } from './users.service';

@UseGuards(JwtAuthGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  findAll(@CurrentUser() user: CurrentUserPayload) {
    return this.usersService.findAll(user.sub);
  }

  // Fixed routes go before ':id' so "me" and "pending" aren't resolved as ids.
  @Get('me')
  findMe(@CurrentUser() user: CurrentUserPayload) {
    return this.usersService.findOne(user.sub);
  }

  @Get('me/stats')
  getMyStats(@CurrentUser() user: CurrentUserPayload) {
    return this.usersService.getStats(user.sub);
  }

  // Admin-only: accounts awaiting approval, shown in Managers when admin mode is on.
  @UseGuards(AdminGuard)
  @Get('pending')
  findPending() {
    return this.usersService.findPending();
  }

  @UseGuards(AdminGuard)
  @Patch(':id/approve')
  approve(@Param('id') id: string) {
    return this.usersService.approve(id);
  }

  @UseGuards(AdminGuard)
  @Patch(':id/reject')
  reject(@Param('id') id: string) {
    return this.usersService.reject(id);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.usersService.findOne(id);
  }
}

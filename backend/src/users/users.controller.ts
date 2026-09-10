import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
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

  // IMPORTANT: these fixed routes must be declared before ':id'
  // so Nest doesn't try to resolve "me" as a user id.
  @Get('me')
  findMe(@CurrentUser() user: CurrentUserPayload) {
    return this.usersService.findOne(user.sub);
  }

  @Get('me/stats')
  getMyStats(@CurrentUser() user: CurrentUserPayload) {
    return this.usersService.getStats(user.sub);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.usersService.findOne(id);
  }
}

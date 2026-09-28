import { IsString, IsUUID } from 'class-validator';

// No `fromUserId` on purpose: the backend takes it from the authenticated user.
export class CreateClauseDto {
  @IsString()
  @IsUUID()
  toUserId: string;
}

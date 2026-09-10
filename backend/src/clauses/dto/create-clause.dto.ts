import { IsString, IsUUID } from 'class-validator';

// Note: there is intentionally NO `fromUserId` field here (rule #40).
// The backend always derives `fromUserId` from the authenticated JWT user.
export class CreateClauseDto {
  @IsString()
  @IsUUID()
  toUserId: string;
}

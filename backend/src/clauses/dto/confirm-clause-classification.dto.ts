import { IsIn } from 'class-validator';

// A participant can only vote CLAUSE or AGREED — PENDING is a system
// state, never something a user sets directly.
export class ConfirmClauseClassificationDto {
  @IsIn(['CLAUSE', 'AGREED'])
  classification: 'CLAUSE' | 'AGREED';
}

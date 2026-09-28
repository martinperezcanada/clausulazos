import { IsIn } from 'class-validator';

// Participants can only vote CLAUSE or AGREED; PENDING is a system state.
export class ConfirmClauseClassificationDto {
  @IsIn(['CLAUSE', 'AGREED'])
  classification: 'CLAUSE' | 'AGREED';
}

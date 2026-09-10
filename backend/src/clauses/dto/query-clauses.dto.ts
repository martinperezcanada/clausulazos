import { IsIn, IsOptional, IsString, IsUUID } from 'class-validator';

export class QueryClausesDto {
  @IsOptional()
  @IsString()
  @IsUUID()
  userId?: string;

  @IsOptional()
  @IsIn(['ACTIVE', 'EXPIRED', 'CANCELLED', 'ALL'])
  status?: 'ACTIVE' | 'EXPIRED' | 'CANCELLED' | 'ALL';
}

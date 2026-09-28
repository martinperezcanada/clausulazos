import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class RegisterDeviceDto {
  @IsString()
  @IsNotEmpty()
  token: string;

  @IsOptional()
  @IsString()
  platform?: string;
}

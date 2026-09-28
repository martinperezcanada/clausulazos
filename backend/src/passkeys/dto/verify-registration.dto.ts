import { IsNotEmptyObject, IsObject, IsOptional, IsString, MaxLength } from 'class-validator';

// `response` is the RegistrationResponseJSON from navigator.credentials.create(). Its shape varies
// between browsers, so it is not declared as a nested class: with @ValidateNested the global
// `whitelist` would strip fields it doesn't know and break real responses.
// verifyRegistrationResponse() does the structural validation.
export class VerifyRegistrationDto {
  @IsObject()
  @IsNotEmptyObject()
  response: Record<string, unknown>;

  // User-friendly label, e.g. "iPhone de Martín".
  @IsOptional()
  @IsString()
  @MaxLength(60)
  name?: string;
}

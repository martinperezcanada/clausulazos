import { IsNotEmptyObject, IsObject, IsOptional, IsString, MaxLength } from 'class-validator';

// `response` is the RegistrationResponseJSON produced by the browser's
// navigator.credentials.create() (via our WebAuthn client helper). Its
// exact nested shape varies slightly across browsers/authenticators, so we
// deliberately do NOT declare it as a nested class with @ValidateNested —
// that would make the global ValidationPipe's `whitelist` strip fields it
// doesn't know about and break real responses. @simplewebauthn/server's
// verifyRegistrationResponse() does the real structural validation.
export class VerifyRegistrationDto {
  @IsObject()
  @IsNotEmptyObject()
  response: Record<string, unknown>;

  // User-friendly label for this passkey, e.g. "iPhone de Martín".
  @IsOptional()
  @IsString()
  @MaxLength(60)
  name?: string;
}

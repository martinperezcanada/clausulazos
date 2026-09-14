import { IsEmail, IsNotEmptyObject, IsObject, IsOptional } from 'class-validator';

// Optional: if the person types their email first, we can hint the
// browser with `allowCredentials` (nicer UX, works even for authenticators
// that don't support discoverable/resident credentials). Without it, we
// fall back to a fully "usernameless" flow — exactly what lets Face ID
// show a picker of saved passkeys with no prior input.
export class LoginOptionsDto {
  @IsOptional()
  @IsEmail()
  email?: string;
}

export class VerifyAuthenticationDto {
  @IsObject()
  @IsNotEmptyObject()
  response: Record<string, unknown>;
}

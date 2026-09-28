import { IsEmail, IsNotEmptyObject, IsObject, IsOptional } from 'class-validator';

// Optional: when the email is given we can pass `allowCredentials`, which also works for
// authenticators without discoverable credentials. Without it the login is usernameless, which lets
// Face ID show a picker of saved passkeys.
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

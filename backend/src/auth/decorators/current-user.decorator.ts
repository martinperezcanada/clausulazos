import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export interface CurrentUserPayload {
  sub: string;
  email: string;
  name: string;
}

// Usage: fromUserId is ALWAYS taken from the authenticated JWT user,
// never from the request body. This is what enforces rule #40 of the spec.
export const CurrentUser = createParamDecorator(
  (data: unknown, ctx: ExecutionContext): CurrentUserPayload => {
    const request = ctx.switchToHttp().getRequest();
    return request.user;
  },
);

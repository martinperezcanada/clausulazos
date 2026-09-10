import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

// Applied to every protected route. Delegates to the 'jwt' passport
// strategy, which validates the Bearer token and loads the user.
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}

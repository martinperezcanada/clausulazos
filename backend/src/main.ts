import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  // CORS: only the configured frontend origins can call the API with credentials. Defaults cover
  // production (Vercel) and the usual local ports; override with CORS_ORIGINS (comma separated).
  const defaultOrigins = [
    'https://clausulazos.vercel.app',
    'http://localhost:3000',
    'http://localhost:5000',
    'http://localhost:8080',
    'http://localhost:5173',
  ];
  const configuredOrigins = process.env.CORS_ORIGINS
    ? process.env.CORS_ORIGINS.split(',').map((o) => o.trim()).filter(Boolean)
    : [];
  const allowedOrigins = [...new Set([...defaultOrigins, ...configuredOrigins])];

  const app = await NestFactory.create(AppModule, {
    cors: {
      origin: allowedOrigins,
      credentials: true,
    },
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true, // strip properties that aren't in the DTO (e.g. an injected fromUserId)
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  const port = process.env.PORT ? parseInt(process.env.PORT, 10) : 3000;
  await app.listen(port, '0.0.0.0');
  // eslint-disable-next-line no-console
  console.log(`Clausulazos API listening on port ${port}`);
}

bootstrap();

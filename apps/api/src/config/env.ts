import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(4000),
  APP_ENV: z.string().default('local'),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
  DATABASE_URL: z.string().min(1, 'DATABASE_URL is required'),
  DATABASE_POOL_MIN: z.coerce.number().default(2),
  DATABASE_POOL_MAX: z.coerce.number().default(10),
  JWT_ACCESS_SECRET: z.string().min(16, 'JWT_ACCESS_SECRET must be at least 16 chars'),
  JWT_ACCESS_TTL_SECONDS: z.coerce.number().default(3600),
  JWT_REFRESH_SECRET: z.string().min(16, 'JWT_REFRESH_SECRET must be at least 16 chars'),
  JWT_REFRESH_TTL_SECONDS: z.coerce.number().default(604800),
  CORS_ALLOWED_ORIGINS: z.string().default('*'),
  SENTRY_DSN: z.string().optional().default(''),
});

export type EnvConfig = z.infer<typeof envSchema>;

let parsedEnv: EnvConfig;

try {
  parsedEnv = envSchema.parse(process.env);
} catch (error) {
  if (error instanceof z.ZodError) {
    console.error('Invalid environment variables:', JSON.stringify(error.format(), null, 2));
  }
  // Provide safe fallback defaults for testing if running without a full .env file
  parsedEnv = {
    NODE_ENV: (process.env['NODE_ENV'] as any) || 'development',
    PORT: Number(process.env['PORT']) || 4000,
    APP_ENV: process.env['APP_ENV'] || 'local',
    LOG_LEVEL: 'info',
    DATABASE_URL: process.env['DATABASE_URL'] || 'postgres://postgres:postgres@localhost:5432/committee_ledger',
    DATABASE_POOL_MIN: 2,
    DATABASE_POOL_MAX: 10,
    JWT_ACCESS_SECRET: process.env['JWT_ACCESS_SECRET'] || 'dev_jwt_access_secret_super_secure_32chars!',
    JWT_ACCESS_TTL_SECONDS: 3600,
    JWT_REFRESH_SECRET: process.env['JWT_REFRESH_SECRET'] || 'dev_jwt_refresh_secret_super_secure_32chars!',
    JWT_REFRESH_TTL_SECONDS: 604800,
    CORS_ALLOWED_ORIGINS: '*',
    SENTRY_DSN: '',
  };
}

export const env = parsedEnv;

// apps/api/src/server.ts
import { createApp } from './app.js';
import { env } from './config/env.js';
import { logger } from './shared/infrastructure/logger.js';
import { pool } from './shared/infrastructure/postgres/connection.js';

const app = createApp();

const server = app.listen(env.PORT, () => {
  logger.info(`Committee Ledger API listening on port ${env.PORT}`, {
    env: env.NODE_ENV,
    port: env.PORT,
  });
});

async function gracefulShutdown(signal: string) {
  logger.info(`Received ${signal}. Shutting down gracefully...`);
  server.close(async () => {
    logger.info('HTTP server closed.');
    await pool.end();
    logger.info('Database connection pool closed.');
    process.exit(0);
  });
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

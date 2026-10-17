// apps/api/src/app.ts
import express, { Express, Request, Response } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { env } from './config/env.js';
import { requestIdMiddleware } from './shared/presentation/middlewares/request-id.middleware.js';
import { errorHandler } from './shared/presentation/middlewares/error.middleware.js';
import { checkDatabaseHealth } from './shared/infrastructure/postgres/connection.js';

import { identityRouter } from './modules/identity/presentation/routes.js';
import { workspacesRouter } from './modules/workspaces/presentation/routes.js';
import { committeesRouter } from './modules/committees/presentation/routes.js';
import { membersRouter } from './modules/members/presentation/routes.js';
import { ledgerRouter } from './modules/ledger/presentation/routes.js';
import { reportsRouter } from './modules/reports/presentation/routes.js';
import { auditRouter } from './modules/audit/presentation/routes.js';

export function createApp(): Express {
  const app = express();

  // Basic Security & Parsing
  app.use(helmet());
  app.use(
    cors({
      origin: env.CORS_ALLOWED_ORIGINS === '*' ? '*' : env.CORS_ALLOWED_ORIGINS.split(','),
      credentials: true,
    })
  );
  app.use(express.json({ limit: '1mb' }));
  app.use(requestIdMiddleware);

  // Health checks
  const healthHandler = (_req: Request, res: Response) => {
    res.status(200).json({ status: 'ok', uptime: process.uptime() });
  };
  app.get('/health', healthHandler);
  app.get('/health/live', healthHandler);

  app.get('/health/ready', async (_req: Request, res: Response) => {
    const isDbReady = await checkDatabaseHealth();
    if (isDbReady) {
      res.status(200).json({ status: 'ready', database: 'connected' });
    } else {
      res.status(503).json({ status: 'unavailable', database: 'disconnected' });
    }
  });

  // API v1 Routes
  const apiV1 = express.Router();
  apiV1.get('/health', healthHandler);
  apiV1.use(identityRouter);
  apiV1.use(workspacesRouter);
  apiV1.use(committeesRouter);
  apiV1.use(membersRouter);
  apiV1.use(ledgerRouter);
  apiV1.use(reportsRouter);
  apiV1.use(auditRouter);

  // 404 for unmatched /api/v1/* routes
  apiV1.use((_req: Request, res: Response) => {
    res.status(404).json({
      error: {
        code: 'NOT_FOUND',
        message: 'The requested API route was not found',
      },
    });
  });

  app.use('/api/v1', apiV1);

  // 404 handler for unknown root routes
  app.use((_req: Request, res: Response) => {
    res.status(404).json({
      error: {
        code: 'NOT_FOUND',
        message: 'The requested route was not found',
      },
    });
  });

  // Centralized Error Handler
  app.use(errorHandler);

  return app;
}

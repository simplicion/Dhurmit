// shared/presentation/response.ts
import { Request, Response } from 'express';

export function sendSuccess<T>(
  res: Response,
  data: T,
  meta?: Record<string, unknown>,
  statusCode: number = 200
): void {
  const req = res.req as Request;
  res.status(statusCode).json({
    data,
    meta: {
      requestId: req?.requestId,
      ...meta,
    },
  });
}

export function sendCreated<T>(res: Response, data: T, meta?: Record<string, unknown>): void {
  sendSuccess(res, data, meta, 201);
}

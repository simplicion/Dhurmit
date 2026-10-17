// shared/presentation/middlewares/auth.middleware.ts
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../../../config/env.js';
import { UnauthenticatedError, ForbiddenError } from '../../domain/errors.js';
import { query } from '../../infrastructure/postgres/connection.js';

export interface TokenPayload {
  userId: string;
  workspaceId?: string;
  role?: string;
  email?: string;
}

export function generateAccessToken(payload: TokenPayload): string {
  return jwt.sign(payload, env.JWT_ACCESS_SECRET, {
    expiresIn: env.JWT_ACCESS_TTL_SECONDS,
  });
}

export function generateRefreshToken(payload: TokenPayload): string {
  return jwt.sign(payload, env.JWT_REFRESH_SECRET, {
    expiresIn: env.JWT_REFRESH_TTL_SECONDS,
  });
}

export function requireAuth(req: Request, _res: Response, next: NextFunction): void {
  const authHeader = req.headers['authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new UnauthenticatedError('Missing or malformed Authorization header');
  }

  const token = authHeader.substring(7);
  try {
    const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET) as TokenPayload;
    req.user = {
      userId: decoded.userId,
      workspaceId: decoded.workspaceId,
      role: decoded.role,
    };
    next();
  } catch (err) {
    throw new UnauthenticatedError('Invalid or expired authentication token');
  }
}

export function requireWorkspaceRole(allowedRoles: string[]) {
  return async (req: Request, _res: Response, next: NextFunction): Promise<void> => {
    if (!req.user || !req.user.userId) {
      throw new UnauthenticatedError();
    }

    const workspaceId =
      req.user.workspaceId ||
      (req.headers['x-workspace-id'] as string) ||
      (req.params['workspaceId'] as string);

    if (!workspaceId) {
      throw new ForbiddenError('No active workspace specified');
    }

    // Verify membership in database
    const res = await query(
      `SELECT role, status FROM workspace_memberships WHERE workspace_id = $1 AND user_id = $2`,
      [workspaceId, req.user.userId]
    );

    if (res.rowCount === 0 || res.rows[0].status !== 'ACTIVE') {
      throw new ForbiddenError('Access to requested workspace is denied');
    }

    const role = res.rows[0].role;
    req.user.workspaceId = workspaceId;
    req.user.role = role;

    if (!allowedRoles.includes(role)) {
      throw new ForbiddenError(`Role '${role}' does not have sufficient permissions`);
    }

    next();
  };
}

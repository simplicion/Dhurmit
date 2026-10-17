// modules/identity/presentation/routes.ts
import { Router, Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { env } from '../../../config/env.js';
import { query, withTransaction } from '../../../shared/infrastructure/postgres/connection.js';
import { sendCreated, sendSuccess } from '../../../shared/presentation/response.js';
import { asyncHandler } from '../../../shared/presentation/async-handler.js';
import {
  ConflictError,
  UnauthenticatedError,
} from '../../../shared/domain/errors.js';
import {
  generateAccessToken,
  generateRefreshToken,
  requireAuth,
  TokenPayload,
} from '../../../shared/presentation/middlewares/auth.middleware.js';

export const identityRouter = Router();

const registerSchema = z.object({
  displayName: z.string().min(2, 'Display name must be at least 2 characters'),
  email: z.string().email('Invalid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  phone: z.string().optional(),
});

identityRouter.post(
  '/auth/register',
  asyncHandler(async (req: Request, res: Response) => {
    const body = registerSchema.parse(req.body);

    const existing = await query('SELECT id FROM users WHERE email = $1', [body.email.toLowerCase()]);
    if (existing.rowCount && existing.rowCount > 0) {
      throw new ConflictError('A user with this email address already exists');
    }

    const passwordHash = await bcrypt.hash(body.password, 10);

    const result = await withTransaction(async (client) => {
      const userRes = await client.query(
        `INSERT INTO users (display_name, email, phone_e164, password_hash, status)
         VALUES ($1, $2, $3, $4, 'ACTIVE')
         RETURNING id, display_name, email, phone_e164, status, created_at`,
        [body.displayName, body.email.toLowerCase(), body.phone || null, passwordHash]
      );
      const user = userRes.rows[0];

      const wsRes = await client.query(
        `INSERT INTO workspaces (owner_user_id, name)
         VALUES ($1, $2)
         RETURNING id, name, created_at`,
        [user.id, `${body.displayName}'s Workspace`]
      );
      const workspace = wsRes.rows[0];

      await client.query(
        `INSERT INTO workspace_memberships (workspace_id, user_id, role, status)
         VALUES ($1, $2, 'OWNER', 'ACTIVE')`,
        [workspace.id, user.id]
      );

      await client.query(
        `INSERT INTO audit_events (workspace_id, actor_id, action, entity_type, entity_id, metadata)
         VALUES ($1, $2, 'USER_REGISTERED', 'USER', $2, $3)`,
        [workspace.id, user.id, JSON.stringify({ email: user.email })]
      );

      return { user, workspace };
    });

    const tokenPayload: TokenPayload = {
      userId: result.user.id,
      workspaceId: result.workspace.id,
      role: 'OWNER',
      email: result.user.email,
    };

    const accessToken = generateAccessToken(tokenPayload);
    const refreshToken = generateRefreshToken(tokenPayload);

    sendCreated(res, {
      user: {
        id: result.user.id,
        displayName: result.user.display_name,
        email: result.user.email,
      },
      workspace: {
        id: result.workspace.id,
        name: result.workspace.name,
        role: 'OWNER',
      },
      tokens: {
        accessToken,
        refreshToken,
        expiresIn: env.JWT_ACCESS_TTL_SECONDS,
      },
    });
  })
);

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

identityRouter.post(
  '/auth/login',
  asyncHandler(async (req: Request, res: Response) => {
    const body = loginSchema.parse(req.body);

    const userRes = await query(
      `SELECT id, display_name, email, password_hash, status FROM users WHERE email = $1`,
      [body.email.toLowerCase()]
    );

    if (userRes.rowCount === 0 || !userRes.rows[0].password_hash) {
      throw new UnauthenticatedError('Invalid email or password');
    }

    const user = userRes.rows[0];
    const isMatch = await bcrypt.compare(body.password, user.password_hash);
    if (!isMatch) {
      throw new UnauthenticatedError('Invalid email or password');
    }

    const wsRes = await query(
      `SELECT w.id, w.name, wm.role
       FROM workspaces w
       JOIN workspace_memberships wm ON wm.workspace_id = w.id
       WHERE wm.user_id = $1 AND wm.status = 'ACTIVE'
       ORDER BY (wm.role = 'OWNER') DESC, w.created_at ASC
       LIMIT 1`,
      [user.id]
    );

    const activeWorkspace = wsRes.rows[0] || null;

    const tokenPayload: TokenPayload = {
      userId: user.id,
      workspaceId: activeWorkspace?.id,
      role: activeWorkspace?.role || 'VIEWER',
      email: user.email,
    };

    const accessToken = generateAccessToken(tokenPayload);
    const refreshToken = generateRefreshToken(tokenPayload);

    sendSuccess(res, {
      user: {
        id: user.id,
        displayName: user.display_name,
        email: user.email,
      },
      workspace: activeWorkspace
        ? {
            id: activeWorkspace.id,
            name: activeWorkspace.name,
            role: activeWorkspace.role,
          }
        : null,
      tokens: {
        accessToken,
        refreshToken,
        expiresIn: env.JWT_ACCESS_TTL_SECONDS,
      },
    });
  })
);

const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

identityRouter.post(
  '/auth/refresh',
  asyncHandler(async (req: Request, res: Response) => {
    const body = refreshSchema.parse(req.body);

    try {
      const decoded = jwt.verify(body.refreshToken, env.JWT_REFRESH_SECRET) as TokenPayload;
      const userRes = await query(`SELECT id, email, status FROM users WHERE id = $1`, [decoded.userId]);
      if (userRes.rowCount === 0 || userRes.rows[0].status !== 'ACTIVE') {
        throw new UnauthenticatedError('User account is invalid or deactivated');
      }

      const newAccessToken = generateAccessToken({
        userId: decoded.userId,
        workspaceId: decoded.workspaceId,
        role: decoded.role,
        email: decoded.email,
      });

      sendSuccess(res, {
        accessToken: newAccessToken,
        expiresIn: env.JWT_ACCESS_TTL_SECONDS,
      });
    } catch (err) {
      throw new UnauthenticatedError('Invalid or expired refresh token');
    }
  })
);

identityRouter.post('/auth/logout', (_req: Request, res: Response) => {
  sendSuccess(res, { message: 'Logged out successfully' });
});

identityRouter.get(
  '/me',
  requireAuth,
  asyncHandler(async (req: Request, res: Response) => {
    const userId = req.user!.userId;
    const userRes = await query(
      `SELECT id, display_name, email, phone_e164, status, created_at FROM users WHERE id = $1`,
      [userId]
    );

    if (userRes.rowCount === 0) {
      throw new UnauthenticatedError('User not found');
    }

    const user = userRes.rows[0];

    const wsRes = await query(
      `SELECT w.id, w.name, wm.role
       FROM workspaces w
       JOIN workspace_memberships wm ON wm.workspace_id = w.id
       WHERE wm.user_id = $1 AND wm.status = 'ACTIVE'`,
      [userId]
    );

    sendSuccess(res, {
      user: {
        id: user.id,
        displayName: user.display_name,
        email: user.email,
        phone: user.phone_e164,
      },
      workspaces: wsRes.rows.map((r) => ({
        id: r.id,
        name: r.name,
        role: r.role,
      })),
      activeWorkspaceId: req.user!.workspaceId,
    });
  })
);

// modules/workspaces/presentation/routes.ts
import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { query, withTransaction } from '../../../shared/infrastructure/postgres/connection.js';
import { sendCreated, sendSuccess } from '../../../shared/presentation/response.js';
import { NotFoundError } from '../../../shared/domain/errors.js';
import { asyncHandler } from '../../../shared/presentation/async-handler.js';
import {
  requireAuth,
  requireWorkspaceRole,
} from '../../../shared/presentation/middlewares/auth.middleware.js';

export const workspacesRouter = Router();

workspacesRouter.get(
  '/workspaces',
  requireAuth,
  asyncHandler(async (req: Request, res: Response) => {
    const userId = req.user!.userId;
    const result = await query(
      `SELECT w.id, w.name, w.created_at, wm.role
       FROM workspaces w
       JOIN workspace_memberships wm ON wm.workspace_id = w.id
       WHERE wm.user_id = $1 AND wm.status = 'ACTIVE'
       ORDER BY w.created_at ASC`,
      [userId]
    );

    sendSuccess(res, result.rows);
  })
);

const createWorkspaceSchema = z.object({
  name: z.string().min(2, 'Workspace name must be at least 2 characters'),
});

workspacesRouter.post(
  '/workspaces',
  requireAuth,
  asyncHandler(async (req: Request, res: Response) => {
    const userId = req.user!.userId;
    const body = createWorkspaceSchema.parse(req.body);

    const workspace = await withTransaction(async (client) => {
      const wsRes = await client.query(
        `INSERT INTO workspaces (owner_user_id, name) VALUES ($1, $2) RETURNING id, name, created_at`,
        [userId, body.name]
      );
      const ws = wsRes.rows[0];

      await client.query(
        `INSERT INTO workspace_memberships (workspace_id, user_id, role, status) VALUES ($1, $2, 'OWNER', 'ACTIVE')`,
        [ws.id, userId]
      );

      await client.query(
        `INSERT INTO audit_events (workspace_id, actor_id, action, entity_type, entity_id, metadata)
         VALUES ($1, $2, 'WORKSPACE_CREATED', 'WORKSPACE', $1, $3)`,
        [ws.id, userId, JSON.stringify({ name: ws.name })]
      );

      return ws;
    });

    sendCreated(res, { ...workspace, role: 'OWNER' });
  })
);

workspacesRouter.get(
  '/workspaces/:workspaceId',
  requireAuth,
  asyncHandler(async (req: Request, res: Response) => {
    const userId = req.user!.userId;
    const { workspaceId } = req.params;

    const result = await query(
      `SELECT w.id, w.name, w.created_at, wm.role
       FROM workspaces w
       JOIN workspace_memberships wm ON wm.workspace_id = w.id
       WHERE w.id = $1 AND wm.user_id = $2 AND wm.status = 'ACTIVE'`,
      [workspaceId, userId]
    );

    if (result.rowCount === 0) {
      throw new NotFoundError('Workspace not found or access denied');
    }

    sendSuccess(res, result.rows[0]);
  })
);

workspacesRouter.get(
  '/workspaces/:workspaceId/memberships',
  requireAuth,
  requireWorkspaceRole(['OWNER', 'ADMIN']),
  asyncHandler(async (req: Request, res: Response) => {
    const { workspaceId } = req.params;

    const result = await query(
      `SELECT wm.workspace_id, wm.user_id, wm.role, wm.status, wm.created_at,
              u.display_name, u.email, u.phone_e164
       FROM workspace_memberships wm
       JOIN users u ON u.id = wm.user_id
       WHERE wm.workspace_id = $1`,
      [workspaceId]
    );

    sendSuccess(res, result.rows);
  })
);

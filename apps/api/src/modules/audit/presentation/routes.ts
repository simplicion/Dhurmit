// modules/audit/presentation/routes.ts
import { Router, Request, Response } from 'express';
import { query } from '../../../shared/infrastructure/postgres/connection.js';
import { sendSuccess } from '../../../shared/presentation/response.js';
import { asyncHandler } from '../../../shared/presentation/async-handler.js';
import { NotFoundError } from '../../../shared/domain/errors.js';
import { requireAuth } from '../../../shared/presentation/middlewares/auth.middleware.js';

export const auditRouter = Router();

auditRouter.use('/committees', requireAuth);

async function getAuthorizedCommittee(committeeId: string, userId: string) {
  const res = await query(
    `SELECT c.*, wm.role as user_role
     FROM committees c
     JOIN workspace_memberships wm ON wm.workspace_id = c.workspace_id
     WHERE c.id = $1 AND wm.user_id = $2 AND wm.status = 'ACTIVE'`,
    [committeeId, userId]
  );
  if (!res.rowCount || res.rowCount === 0) {
    throw new NotFoundError('Committee not found or access denied');
  }
  return res.rows[0];
}

// GET /committees/:committeeId/audit-events
auditRouter.get(
  '/committees/:committeeId/audit-events',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    const committee = await getAuthorizedCommittee(committeeId, req.user!.userId);

    const eventsRes = await query(
      `SELECT a.id, a.action, a.entity_type, a.entity_id, a.reason, a.metadata, a.created_at,
              u.display_name as actor_name, u.email as actor_email
       FROM audit_events a
       JOIN users u ON u.id = a.actor_id
       WHERE a.workspace_id = $1
         AND (a.entity_id = $2 OR a.metadata->>'committeeId' = $2::text)
       ORDER BY a.created_at DESC
       LIMIT 100`,
      [committee.workspace_id, committeeId]
    );

    sendSuccess(res, {
      auditEvents: eventsRes.rows,
    });
  })
);

import { Router, Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { query, withTransaction } from '../../../shared/infrastructure/postgres/connection.js';
import { sendCreated, sendSuccess } from '../../../shared/presentation/response.js';
import { asyncHandler } from '../../../shared/presentation/async-handler.js';
import {
  ForbiddenError,
  NotFoundError,
} from '../../../shared/domain/errors.js';
import { requireAuth } from '../../../shared/presentation/middlewares/auth.middleware.js';
import { StatusCalculator } from '../../ledger/domain/status-calculator.js';

export const membersRouter = Router();

membersRouter.use('/committees', requireAuth);

async function getAuthorizedCommittee(
  committeeId: string,
  userId: string,
  requiredRoles: string[] = ['OWNER', 'ADMIN', 'COLLECTOR', 'VIEWER']
) {
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
  const committee = res.rows[0];
  if (!requiredRoles.includes(committee.user_role)) {
    throw new ForbiddenError('Insufficient permissions on this committee');
  }
  return committee;
}

// GET /committees/:committeeId/members
membersRouter.get(
  '/committees/:committeeId/members',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    const search = req.query['search'] as string;
    const status = req.query['status'] as string;
    await getAuthorizedCommittee(committeeId, req.user!.userId);

    let searchClause = '';
    const params: any[] = [committeeId];

    if (search && search.trim()) {
      params.push(`%${search.trim().toLowerCase()}%`);
      searchClause += ` AND (LOWER(m.display_name) LIKE $${params.length} OR LOWER(m.phone) LIKE $${params.length})`;
    }

    if (status && status.trim()) {
      params.push(status.trim().toUpperCase());
      searchClause += ` AND cm.membership_status = $${params.length}`;
    }

    const result = await query(
      `SELECT m.id, m.display_name, m.phone, (m.password_hash IS NOT NULL) as has_password, m.external_reference, m.notes, m.status as member_status,
              cm.membership_status, cm.joined_at, cm.left_at,
              COALESCE(
                (SELECT SUM(o.due_amount_minor) FROM obligations o WHERE o.committee_id = $1 AND o.member_id = m.id), 0
              ) as total_due_minor,
              COALESCE(
                (SELECT SUM(ca.amount_minor) 
                 FROM collection_allocations ca 
                 JOIN obligations o ON o.id = ca.obligation_id 
                 WHERE o.committee_id = $1 AND o.member_id = m.id), 0
              ) as total_paid_minor
       FROM members m
       JOIN committee_members cm ON cm.member_id = m.id AND cm.committee_id = $1
       WHERE 1=1 ${searchClause}
       ORDER BY m.display_name ASC`,
      params
    );

    const members = result.rows.map((row) => {
      const totalDue = BigInt(row.total_due_minor);
      const totalPaid = BigInt(row.total_paid_minor);
      const totalOutstanding = totalDue > totalPaid ? totalDue - totalPaid : 0n;

      return {
        id: row.id,
        displayName: row.display_name,
        phone: row.phone,
        hasPassword: Boolean(row.has_password),
        externalReference: row.external_reference,
        notes: row.notes,
        memberStatus: row.member_status,
        membershipStatus: row.membership_status,
        joinedAt: row.joined_at,
        leftAt: row.left_at,
        totalDueMinor: totalDue.toString(),
        totalPaidMinor: totalPaid.toString(),
        totalOutstandingMinor: totalOutstanding.toString(),
      };
    });

    sendSuccess(res, members);
  })
);

// POST /committees/:committeeId/members
const addMemberSchema = z.object({
  displayName: z.string().min(2, 'Member name must be at least 2 characters'),
  phone: z.string().optional(),
  password: z.string().min(3, 'Password or PIN must be at least 3 characters').optional(),
  externalReference: z.string().optional(),
  notes: z.string().optional(),
  joinedAt: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});

membersRouter.post(
  '/committees/:committeeId/members',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    const userId = req.user!.userId;
    const committee = await getAuthorizedCommittee(committeeId, userId, ['OWNER', 'ADMIN']);

    const body = addMemberSchema.parse(req.body);
    const joinedDate = body.joinedAt || (committee.start_date instanceof Date ? committee.start_date.toISOString().split('T')[0] : committee.start_date);

    const passwordHash = body.password ? await bcrypt.hash(body.password, 10) : null;

    const member = await withTransaction(async (client) => {
      const mRes = await client.query(
        `INSERT INTO members (workspace_id, display_name, phone, password_hash, external_reference, notes, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING *`,
        [committee.workspace_id, body.displayName, body.phone || null, passwordHash, body.externalReference || null, body.notes || null, userId]
      );
      const newMember = mRes.rows[0];

      await client.query(
        `INSERT INTO committee_members (committee_id, member_id, membership_status, joined_at)
         VALUES ($1, $2, 'ACTIVE', $3)
         ON CONFLICT (committee_id, member_id) DO UPDATE SET membership_status = 'ACTIVE'`,
        [committeeId, newMember.id, joinedDate]
      );

      if (committee.status === 'ACTIVE') {
        const existingDueDates = await client.query(
          `SELECT DISTINCT due_date, due_amount_minor, currency_code, schedule_version
           FROM obligations
           WHERE committee_id = $1
           ORDER BY due_date ASC`,
          [committeeId]
        );

        for (const d of existingDueDates.rows) {
          const dueDateStr = d.due_date instanceof Date ? d.due_date.toISOString().split('T')[0] : d.due_date;
          await client.query(
            `INSERT INTO obligations (
              workspace_id, committee_id, member_id, due_date,
              due_amount_minor, currency_code, schedule_version
            ) VALUES ($1, $2, $3, $4, $5, $6, $7)
            ON CONFLICT (committee_id, member_id, due_date) DO NOTHING`,
            [
              committee.workspace_id,
              committeeId,
              newMember.id,
              dueDateStr,
              d.due_amount_minor,
              d.currency_code,
              d.schedule_version,
            ]
          );
        }
      }

      await client.query(
        `INSERT INTO audit_events (workspace_id, actor_id, action, entity_type, entity_id, metadata)
         VALUES ($1, $2, 'MEMBER_ADDED_TO_COMMITTEE', 'MEMBER', $3, $4)`,
        [committee.workspace_id, userId, newMember.id, JSON.stringify({ committeeId, name: newMember.display_name })]
      );

      return newMember;
    });

    sendCreated(res, member);
  })
);

// GET /committees/:committeeId/members/:memberId
membersRouter.get(
  '/committees/:committeeId/members/:memberId',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    const memberId = req.params['memberId'] || '';
    await getAuthorizedCommittee(committeeId, req.user!.userId);

    const resMember = await query(
      `SELECT m.*, cm.membership_status, cm.joined_at, cm.left_at
     FROM members m
     JOIN committee_members cm ON cm.member_id = m.id AND cm.committee_id = $1
     WHERE m.id = $2`,
      [committeeId, memberId]
    );

    if (!resMember.rowCount || resMember.rowCount === 0) {
      throw new NotFoundError('Member not found in this committee');
    }

    sendSuccess(res, resMember.rows[0]);
  })
);

// PATCH /committees/:committeeId/members/:memberId
const updateMemberSchema = z.object({
  displayName: z.string().min(2).optional(),
  phone: z.string().optional(),
  password: z.string().min(3, 'Password or PIN must be at least 3 characters').optional(),
  externalReference: z.string().optional(),
  notes: z.string().optional(),
});

membersRouter.patch(
  '/committees/:committeeId/members/:memberId',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    const memberId = req.params['memberId'] || '';
    const userId = req.user!.userId;
    const committee = await getAuthorizedCommittee(committeeId, userId);
    const body = updateMemberSchema.parse(req.body);

    const passwordHash = body.password ? await bcrypt.hash(body.password, 10) : undefined;

    const resUpdate = await query(
      `UPDATE members
       SET display_name = COALESCE($1, display_name),
           phone = COALESCE($2, phone),
           password_hash = COALESCE($3, password_hash),
           external_reference = COALESCE($4, external_reference),
           notes = COALESCE($5, notes),
           updated_at = NOW()
       WHERE id = $6 AND workspace_id = $7
       RETURNING id, display_name, phone, (password_hash IS NOT NULL) as has_password, external_reference, notes, status`,
      [body.displayName, body.phone, passwordHash, body.externalReference, body.notes, memberId, committee.workspace_id]
    );

    if (!resUpdate.rowCount || resUpdate.rowCount === 0) {
      throw new NotFoundError('Member not found');
    }

    sendSuccess(res, resUpdate.rows[0]);
  })
);

// POST /committees/:committeeId/members/:memberId/deactivate
membersRouter.post(
  '/committees/:committeeId/members/:memberId/deactivate',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    const memberId = req.params['memberId'] || '';
    const userId = req.user!.userId;
    const committee = await getAuthorizedCommittee(committeeId, userId, ['OWNER', 'ADMIN']);

    await withTransaction(async (client) => {
      await client.query(
        `UPDATE committee_members
         SET membership_status = 'INACTIVE', left_at = NOW()
         WHERE committee_id = $1 AND member_id = $2`,
        [committeeId, memberId]
      );

      await client.query(
        `INSERT INTO audit_events (workspace_id, actor_id, action, entity_type, entity_id, metadata)
         VALUES ($1, $2, 'MEMBER_DEACTIVATED', 'MEMBER', $3, $4)`,
        [committee.workspace_id, userId, memberId, JSON.stringify({ committeeId })]
      );
    });

    sendSuccess(res, { message: 'Member deactivated successfully', memberId });
  })
);

// GET /committees/:committeeId/members/:memberId/statement
membersRouter.get(
  '/committees/:committeeId/members/:memberId/statement',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    const memberId = req.params['memberId'] || '';
    await getAuthorizedCommittee(committeeId, req.user!.userId);

    const mRes = await query(`SELECT * FROM members WHERE id = $1`, [memberId]);
    if (!mRes.rowCount || mRes.rowCount === 0) {
      throw new NotFoundError('Member not found');
    }
    const member = mRes.rows[0];

    const obsRes = await query(
      `SELECT o.id, o.due_date, o.due_amount_minor, o.currency_code,
              json_agg(
                json_build_object(
                  'allocationId', ca.id,
                  'collectionId', c.id,
                  'amountMinor', ca.amount_minor,
                  'receivedAt', c.received_at,
                  'methodLabel', c.method_label,
                  'reference', c.reference
                )
              ) FILTER (WHERE ca.id IS NOT NULL) as allocations_json
       FROM obligations o
       LEFT JOIN collection_allocations ca ON ca.obligation_id = o.id
       LEFT JOIN collections c ON c.id = ca.collection_id AND c.reversal_status = 'ACTIVE'
       WHERE o.committee_id = $1 AND o.member_id = $2
       GROUP BY o.id, o.due_date, o.due_amount_minor, o.currency_code
       ORDER BY o.due_date ASC`,
      [committeeId, memberId]
    );

    let cumulativeDue = 0n;
    let cumulativePaid = 0n;

    const obligations = obsRes.rows.map((row) => {
      const dueDateStr = row.due_date instanceof Date ? row.due_date.toISOString().split('T')[0] : String(row.due_date);
      const allocations = (row.allocations_json || []).map((a: any) => ({
        allocationId: a.allocationId,
        collectionId: a.collectionId,
        amountMinor: BigInt(a.amountMinor),
        receivedAt: a.receivedAt,
        methodLabel: a.methodLabel,
        reference: a.reference,
      }));

      const state = StatusCalculator.calculate({
        dueDate: dueDateStr,
        dueAmountMinor: BigInt(row.due_amount_minor),
        allocations,
      });

      cumulativeDue += state.dueAmountMinor;
      cumulativePaid += state.allocatedAmountMinor;
      const runningOutstanding = cumulativeDue > cumulativePaid ? cumulativeDue - cumulativePaid : 0n;

      return {
        obligationId: row.id,
        dueDate: dueDateStr,
        dueAmountMinor: state.dueAmountMinor.toString(),
        allocatedAmountMinor: state.allocatedAmountMinor.toString(),
        outstandingAmountMinor: state.outstandingAmountMinor.toString(),
        runningOutstandingMinor: runningOutstanding.toString(),
        status: state.status,
        allocations: allocations.map((a: any) => ({
          allocationId: a.allocationId,
          collectionId: a.collectionId,
          amountMinor: a.amountMinor.toString(),
          receivedAt: a.receivedAt,
          methodLabel: a.methodLabel,
          reference: a.reference,
        })),
      };
    });

    sendSuccess(res, {
      member: {
        id: member.id,
        displayName: member.display_name,
        phone: member.phone,
        externalReference: member.external_reference,
      },
      statement: {
        totalDueMinor: cumulativeDue.toString(),
        totalPaidMinor: cumulativePaid.toString(),
        totalOutstandingMinor: (cumulativeDue > cumulativePaid ? cumulativeDue - cumulativePaid : 0n).toString(),
        obligations,
      },
    });
  })
);

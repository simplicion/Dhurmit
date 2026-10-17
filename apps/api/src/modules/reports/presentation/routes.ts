// modules/reports/presentation/routes.ts
import { Router, Request, Response } from 'express';
import { query } from '../../../shared/infrastructure/postgres/connection.js';
import { sendSuccess } from '../../../shared/presentation/response.js';
import { asyncHandler } from '../../../shared/presentation/async-handler.js';
import { NotFoundError } from '../../../shared/domain/errors.js';
import { requireAuth } from '../../../shared/presentation/middlewares/auth.middleware.js';

export const reportsRouter = Router();

reportsRouter.use('/committees', requireAuth);

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

// GET /committees/:committeeId/reports/summary
reportsRouter.get(
  '/committees/:committeeId/reports/summary',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    const committee = await getAuthorizedCommittee(committeeId, req.user!.userId);

    const statsRes = await query(
      `SELECT 
         (SELECT COUNT(*) FROM committee_members cm WHERE cm.committee_id = $1 AND cm.membership_status = 'ACTIVE') as member_count,
         (SELECT COUNT(*) FROM collections c WHERE c.committee_id = $1 AND c.reversal_status = 'ACTIVE') as total_collections_count,
         (SELECT COALESCE(SUM(o.due_amount_minor), 0) FROM obligations o WHERE o.committee_id = $1) as total_expected_minor,
         (SELECT COALESCE(SUM(ca.amount_minor), 0) 
          FROM collection_allocations ca 
          JOIN collections c ON c.id = ca.collection_id 
          WHERE ca.obligation_id IN (SELECT id FROM obligations WHERE committee_id = $1) 
            AND c.reversal_status = 'ACTIVE') as total_collected_minor`,
      [committeeId]
    );

    const stats = statsRes.rows[0];
    const totalExpected = BigInt(stats.total_expected_minor || 0);
    const totalCollected = BigInt(stats.total_collected_minor || 0);
    const totalOutstanding = totalExpected > totalCollected ? totalExpected - totalCollected : 0n;

    sendSuccess(res, {
      committeeId: committee.id,
      committeeName: committee.name,
      currencyCode: committee.currency_code,
      asOfDate: new Date().toISOString(),
      isManuallyReported: true,
      memberCount: Number(stats.member_count),
      totalCollectionsCount: Number(stats.total_collections_count),
      totalExpectedMinor: totalExpected.toString(),
      totalCollectedMinor: totalCollected.toString(),
      totalOutstandingMinor: totalOutstanding.toString(),
    });
  })
);

// GET /committees/:committeeId/reports/overdue
reportsRouter.get(
  '/committees/:committeeId/reports/overdue',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    await getAuthorizedCommittee(committeeId, req.user!.userId);

    const todayStr = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kathmandu' }).format(new Date());

    const overdueRes = await query(
      `SELECT m.id as member_id, m.display_name as member_name, m.phone as member_phone,
              COUNT(o.id) as overdue_obligations_count,
              MIN(o.due_date) as oldest_unpaid_due_date,
              SUM(o.due_amount_minor - COALESCE(ca.allocated_minor, 0)) as total_overdue_minor
       FROM obligations o
       JOIN members m ON m.id = o.member_id
       LEFT JOIN (
         SELECT ca_inner.obligation_id, SUM(ca_inner.amount_minor) as allocated_minor
         FROM collection_allocations ca_inner
         JOIN collections c_inner ON c_inner.id = ca_inner.collection_id
         WHERE c_inner.reversal_status = 'ACTIVE'
         GROUP BY ca_inner.obligation_id
       ) ca ON ca.obligation_id = o.id
       WHERE o.committee_id = $1
         AND o.due_date < $2
         AND (o.due_amount_minor > COALESCE(ca.allocated_minor, 0))
       GROUP BY m.id, m.display_name, m.phone
       ORDER BY total_overdue_minor DESC`,
      [committeeId, todayStr]
    );

    sendSuccess(res, {
      asOfDate: todayStr,
      overdueMembers: overdueRes.rows.map((row) => ({
        memberId: row.member_id,
        memberName: row.member_name,
        memberPhone: row.member_phone,
        overdueObligationsCount: Number(row.overdue_obligations_count),
        oldestUnpaidDueDate: row.oldest_unpaid_due_date instanceof Date ? row.oldest_unpaid_due_date.toISOString().split('T')[0] : String(row.oldest_unpaid_due_date),
        totalOverdueMinor: row.total_overdue_minor.toString(),
      })),
    });
  })
);

// GET /committees/:committeeId/reports/collections
reportsRouter.get(
  '/committees/:committeeId/reports/collections',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    await getAuthorizedCommittee(committeeId, req.user!.userId);

    const registerRes = await query(
      `SELECT c.id, c.amount_minor, c.currency_code, c.received_at, c.method_label, c.reference, c.reversal_status,
              m.display_name as member_name, u.display_name as collector_name,
              (SELECT COUNT(*) FROM collection_allocations ca WHERE ca.collection_id = c.id) as allocation_count
     FROM collections c
     JOIN members m ON m.id = c.member_id
     JOIN users u ON u.id = c.recorded_by
     WHERE c.committee_id = $1
     ORDER BY c.received_at DESC`,
      [committeeId]
    );

    sendSuccess(res, {
      collections: registerRes.rows,
    });
  })
);

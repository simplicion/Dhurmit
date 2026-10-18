// modules/committees/presentation/routes.ts
import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { query, withTransaction } from '../../../shared/infrastructure/postgres/connection.js';
import { sendCreated, sendSuccess } from '../../../shared/presentation/response.js';
import { asyncHandler } from '../../../shared/presentation/async-handler.js';
import {
  DomainError,
  ForbiddenError,
  NotFoundError,
} from '../../../shared/domain/errors.js';
import { requireAuth } from '../../../shared/presentation/middlewares/auth.middleware.js';
import { ScheduleGenerator } from '../../schedule/domain/schedule-generator.js';
import { StatusCalculator } from '../../ledger/domain/status-calculator.js';

export const committeesRouter = Router();

committeesRouter.use('/committees', requireAuth);

async function getAuthorizedCommittee(committeeId: string, userId: string, requiredRoles: string[] = ['OWNER', 'ADMIN', 'COLLECTOR', 'VIEWER']) {
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
    throw new ForbiddenError(`Insufficient permissions on this committee`);
  }
  return committee;
}

function generateCommitteeCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

// GET /committees
committeesRouter.get(
  '/committees',
  asyncHandler(async (req: Request, res: Response) => {
    const userId = req.user!.userId;
    const workspaceId = req.user!.workspaceId || (req.headers['x-workspace-id'] as string);

    // Organizers see all committees in their workspaces; Members see committees they are enrolled in
    const resCommittees = await query(
      `SELECT c.*,
              (SELECT COUNT(*) FROM committee_members cm WHERE cm.committee_id = c.id AND cm.membership_status = 'ACTIVE') as member_count,
              (SELECT COALESCE(SUM(o.due_amount_minor), 0) FROM obligations o WHERE o.committee_id = c.id) as total_expected_minor,
              (SELECT COALESCE(SUM(ca.amount_minor), 0) FROM collection_allocations ca WHERE ca.obligation_id IN (SELECT id FROM obligations WHERE committee_id = c.id)) as total_collected_minor
       FROM committees c
       WHERE (
         c.workspace_id IN (SELECT workspace_id FROM workspace_memberships WHERE user_id = $1 AND status = 'ACTIVE')
         OR c.id IN (SELECT cm.committee_id FROM committee_members cm JOIN members m ON m.id = cm.member_id WHERE m.user_id = $1)
       )
       ${workspaceId ? 'AND c.workspace_id = $2' : ''}
       ORDER BY c.created_at DESC`,
      workspaceId ? [userId, workspaceId] : [userId]
    );

    sendSuccess(res, resCommittees.rows);
  })
);

// POST /committees
const createCommitteeSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters'),
  currencyCode: z.string().length(3).default('NPR'),
  timezone: z.string().default('Asia/Kathmandu'),
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Start date must be YYYY-MM-DD'),
  duration: z.object({
    count: z.number().int().positive(),
    unit: z.enum(['DAY', 'MONTH']),
  }),
  schedule: z.object({
    frequency: z.enum(['DAILY', 'WEEKLY', 'MONTHLY', 'CUSTOM']),
    rule: z.record(z.any()).default({}),
  }),
  contributionAmountMinor: z.number().int().positive('Contribution amount must be positive in paisa'),
  allowPartialPayment: z.boolean().default(false),
  allowUnallocatedCredit: z.boolean().default(false),
  allocationPolicy: z.enum(['FIFO', 'MANUAL']).default('FIFO'),
  memberIds: z.array(z.string().uuid()).optional().default([]),
});

committeesRouter.post(
  '/committees',
  asyncHandler(async (req: Request, res: Response) => {
    const userId = req.user!.userId;
    const body = createCommitteeSchema.parse(req.body);

    const workspaceId = req.user!.workspaceId || (req.headers['x-workspace-id'] as string);
    if (!workspaceId) {
      throw new DomainError('VALIDATION_ERROR', 'No target workspace provided');
    }

    const wsCheck = await query(
      `SELECT role FROM workspace_memberships WHERE workspace_id = $1 AND user_id = $2 AND status = 'ACTIVE'`,
      [workspaceId, userId]
    );
    if (!wsCheck.rowCount || wsCheck.rowCount === 0 || !['OWNER', 'ADMIN'].includes(wsCheck.rows[0].role)) {
      throw new ForbiddenError('Only workspace owners and admins can create committees');
    }

    const committee = await withTransaction(async (client) => {
      let code = generateCommitteeCode();
      for (let attempt = 0; attempt < 5; attempt++) {
        const check = await client.query('SELECT id FROM committees WHERE code = $1', [code]);
        if (check.rowCount === 0) {
          break;
        }
        code = generateCommitteeCode();
      }

      const cRes = await client.query(
        `INSERT INTO committees (
          workspace_id, name, status, currency_code, timezone,
          start_date, duration_count, duration_unit, frequency,
          contribution_amount_minor, schedule_rule, allocation_policy,
          allow_partial_payment, allow_unallocated_credit, created_by, code
        ) VALUES (
          $1, $2, 'DRAFT', $3, $4,
          $5, $6, $7, $8,
          $9, $10, $11,
          $12, $13, $14, $15
        ) RETURNING *`,
        [
          workspaceId,
          body.name,
          body.currencyCode,
          body.timezone,
          body.startDate,
          body.duration.count,
          body.duration.unit,
          body.schedule.frequency,
          body.contributionAmountMinor,
          JSON.stringify(body.schedule.rule),
          body.allocationPolicy,
          body.allowPartialPayment,
          body.allowUnallocatedCredit,
          userId,
          code,
        ]
      );

      const newCommittee = cRes.rows[0];

      if (body.memberIds && body.memberIds.length > 0) {
        for (const mId of body.memberIds) {
          await client.query(
            `INSERT INTO committee_members (committee_id, member_id, membership_status, joined_at)
             VALUES ($1, $2, 'ACTIVE', $3)
             ON CONFLICT (committee_id, member_id) DO NOTHING`,
            [newCommittee.id, mId, body.startDate]
          );
        }
      }

      await client.query(
        `INSERT INTO audit_events (workspace_id, actor_id, action, entity_type, entity_id, metadata)
         VALUES ($1, $2, 'COMMITTEE_CREATED', 'COMMITTEE', $3, $4)`,
        [workspaceId, userId, newCommittee.id, JSON.stringify({ name: newCommittee.name })]
      );

      return newCommittee;
    });

    sendCreated(res, committee);
  })
);

// POST /committees/join
const joinCommitteeSchema = z.object({
  committeeCode: z.string().min(4).max(16).transform((s) => s.trim().toUpperCase()),
  phoneNumber: z.string().min(5),
  countryCode: z.string().default('+977'),
});

committeesRouter.post(
  '/committees/join',
  asyncHandler(async (req: Request, res: Response) => {
    const userId = req.user!.userId;
    const body = joinCommitteeSchema.parse(req.body);

    // 1. Find committee by code
    const cRes = await query(`SELECT * FROM committees WHERE UPPER(code) = $1`, [body.committeeCode]);
    if (!cRes.rowCount || cRes.rowCount === 0) {
      throw new NotFoundError(`No committee found with code "${body.committeeCode}". Please check with your organizer.`);
    }
    const committee = cRes.rows[0];

    // 2. Extract digits from phone number for robust matching
    const inputDigits = (body.countryCode + body.phoneNumber).replace(/\D/g, '');
    const localDigits = body.phoneNumber.replace(/\D/g, '');

    // 3. Search for member belonging to this committee with this phone number
    const mRes = await query(
      `SELECT m.* 
       FROM members m
       JOIN committee_members cm ON cm.member_id = m.id
       WHERE cm.committee_id = $1
         AND (
           REGEXP_REPLACE(m.phone, '\\D', '', 'g') = $2
           OR REGEXP_REPLACE(m.phone, '\\D', '', 'g') LIKE '%' || $3
           OR m.phone = $4
         )`,
      [committee.id, inputDigits, localDigits.slice(-8), body.phoneNumber]
    );

    if (!mRes.rowCount || mRes.rowCount === 0) {
      throw new NotFoundError(
        `No member found with mobile number ending in "${body.phoneNumber}" in committee "${committee.name}". Please ask your organizer to add you to the committee roster with this mobile number.`
      );
    }

    const member = mRes.rows[0];

    // 4. Link member to this user in DB and ensure workspace membership
    await withTransaction(async (client) => {
      await client.query(`UPDATE members SET user_id = $1 WHERE id = $2`, [userId, member.id]);
      await client.query(
        `INSERT INTO workspace_memberships (workspace_id, user_id, role, status)
         VALUES ($1, $2, 'VIEWER', 'ACTIVE')
         ON CONFLICT (workspace_id, user_id) DO UPDATE SET status = 'ACTIVE'`,
        [committee.workspace_id, userId]
      );
    });

    // 5. Get member's obligations & dues in this committee
    const duesRes = await query(
      `SELECT o.id, o.due_date, o.due_amount_minor,
              COALESCE(SUM(ca.amount_minor), 0) as allocated_minor
       FROM obligations o
       LEFT JOIN collection_allocations ca ON ca.obligation_id = o.id
       WHERE o.committee_id = $1 AND o.member_id = $2
       GROUP BY o.id, o.due_date, o.due_amount_minor
       ORDER BY o.due_date ASC`,
      [committee.id, member.id]
    );

    let totalDue = 0n;
    let totalAllocated = 0n;
    const obligations = duesRes.rows.map((row) => {
      const due = BigInt(row.due_amount_minor);
      const allocated = BigInt(row.allocated_minor);
      const outstanding = due > allocated ? due - allocated : 0n;
      totalDue += due;
      totalAllocated += allocated;
      return {
        id: row.id,
        dueDate: row.due_date instanceof Date ? row.due_date.toISOString().split('T')[0] : String(row.due_date),
        dueAmountMinor: due.toString(),
        allocatedAmountMinor: allocated.toString(),
        outstandingAmountMinor: outstanding.toString(),
        isPaid: outstanding === 0n,
      };
    });

    const totalOutstanding = totalDue > totalAllocated ? totalDue - totalAllocated : 0n;

    sendSuccess(res, {
      committee: {
        id: committee.id,
        name: committee.name,
        code: committee.code,
        status: committee.status,
        currencyCode: committee.currency_code,
        startDate: committee.start_date,
        contributionAmountMinor: committee.contribution_amount_minor,
      },
      member: {
        id: member.id,
        displayName: member.display_name,
        phone: member.phone,
      },
      obligations,
      duesSummary: {
        totalDueMinor: totalDue.toString(),
        totalAllocatedMinor: totalAllocated.toString(),
        totalOutstandingMinor: totalOutstanding.toString(),
        overdueCount: obligations.filter((o) => !o.isPaid && new Date(o.dueDate) < new Date()).length,
      },
    });
  })
);

// GET /committees/:committeeId
committeesRouter.get(
  '/committees/:committeeId',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    const committee = await getAuthorizedCommittee(committeeId, req.user!.userId);

    const aggRes = await query(
      `SELECT 
         (SELECT COUNT(*) FROM committee_members cm WHERE cm.committee_id = $1 AND cm.membership_status = 'ACTIVE') as member_count,
         (SELECT COALESCE(SUM(o.due_amount_minor), 0) FROM obligations o WHERE o.committee_id = $1) as total_expected_minor,
         (SELECT COALESCE(SUM(ca.amount_minor), 0) FROM collection_allocations ca WHERE ca.obligation_id IN (SELECT id FROM obligations WHERE committee_id = $1)) as total_collected_minor`,
      [committeeId]
    );

    const agg = aggRes.rows[0];
    const totalExpected = BigInt(agg.total_expected_minor || 0);
    const totalCollected = BigInt(agg.total_collected_minor || 0);
    const totalOutstanding = totalExpected > totalCollected ? totalExpected - totalCollected : 0n;

    sendSuccess(res, {
      ...committee,
      memberCount: Number(agg.member_count),
      totalExpectedMinor: totalExpected.toString(),
      totalCollectedMinor: totalCollected.toString(),
      totalOutstandingMinor: totalOutstanding.toString(),
    });
  })
);

// POST /committees/:committeeId/schedule-preview
committeesRouter.post(
  '/committees/:committeeId/schedule-preview',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    const committee = await getAuthorizedCommittee(committeeId, req.user!.userId);

    const dueDates = ScheduleGenerator.generateDueDates({
      startDate: committee.start_date instanceof Date ? committee.start_date.toISOString().split('T')[0] : committee.start_date,
      durationCount: committee.duration_count,
      durationUnit: committee.duration_unit,
      frequency: committee.frequency,
      rule: committee.schedule_rule,
    });

    const memberRes = await query(
      `SELECT COUNT(*) as count FROM committee_members WHERE committee_id = $1 AND membership_status = 'ACTIVE'`,
      [committeeId]
    );
    const memberCount = Number(memberRes.rows[0].count);

    const contributionAmount = BigInt(committee.contribution_amount_minor);
    const expectedPerMember = contributionAmount * BigInt(dueDates.length);
    const totalExpectedMinor = expectedPerMember * BigInt(memberCount);

    sendSuccess(res, {
      committeeId,
      startDate: committee.start_date,
      frequency: committee.frequency,
      dueDates,
      dueDatesCount: dueDates.length,
      activeMembersCount: memberCount,
      contributionAmountMinor: committee.contribution_amount_minor,
      expectedTotalPerMemberMinor: expectedPerMember.toString(),
      totalExpectedMinor: totalExpectedMinor.toString(),
    });
  })
);

// POST /committees/:committeeId/activate
committeesRouter.post(
  '/committees/:committeeId/activate',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    const userId = req.user!.userId;
    const committee = await getAuthorizedCommittee(committeeId, userId, ['OWNER', 'ADMIN']);

    if (committee.status !== 'DRAFT') {
      throw new DomainError('CONFLICT', `Committee cannot be activated from status: ${committee.status}`);
    }

    const membersRes = await query(
      `SELECT member_id FROM committee_members WHERE committee_id = $1 AND membership_status = 'ACTIVE'`,
      [committeeId]
    );

    const activeMemberCount = membersRes.rowCount ?? 0;
    if (activeMemberCount === 0) {
      throw new DomainError('VALIDATION_ERROR', 'Cannot activate committee without any active members');
    }

    const startDateStr = committee.start_date instanceof Date
      ? committee.start_date.toISOString().split('T')[0]
      : committee.start_date;

    const dueDates = ScheduleGenerator.generateDueDates({
      startDate: startDateStr,
      durationCount: committee.duration_count,
      durationUnit: committee.duration_unit,
      frequency: committee.frequency,
      rule: committee.schedule_rule,
    });

    await withTransaction(async (client) => {
      await client.query(
        `INSERT INTO committee_config_versions (committee_id, version, config_snapshot, effective_from, created_by)
         VALUES ($1, $2, $3, $4, $5)`,
        [
          committeeId,
          committee.config_version,
          JSON.stringify(committee),
          startDateStr,
          userId,
        ]
      );

      for (const member of membersRes.rows) {
        for (const dueDate of dueDates) {
          await client.query(
            `INSERT INTO obligations (
              workspace_id, committee_id, member_id, due_date,
              due_amount_minor, currency_code, schedule_version
            ) VALUES ($1, $2, $3, $4, $5, $6, $7)
            ON CONFLICT (committee_id, member_id, due_date) DO NOTHING`,
            [
              committee.workspace_id,
              committeeId,
              member.member_id,
              dueDate,
              committee.contribution_amount_minor,
              committee.currency_code,
              committee.config_version,
            ]
          );
        }
      }

      await client.query(
        `UPDATE committees SET status = 'ACTIVE', updated_at = NOW() WHERE id = $1`,
        [committeeId]
      );

      await client.query(
        `INSERT INTO audit_events (workspace_id, actor_id, action, entity_type, entity_id, metadata)
         VALUES ($1, $2, 'COMMITTEE_ACTIVATED', 'COMMITTEE', $3, $4)`,
        [committee.workspace_id, userId, committeeId, JSON.stringify({ dueDatesCount: dueDates.length })]
      );
    });

    sendSuccess(res, {
      message: 'Committee activated successfully',
      committeeId,
      status: 'ACTIVE',
      generatedObligationsCount: dueDates.length * activeMemberCount,
    });
  })
);

// GET /committees/:committeeId/dashboard
committeesRouter.get(
  '/committees/:committeeId/dashboard',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    const committee = await getAuthorizedCommittee(committeeId, req.user!.userId);

    const statsRes = await query(
      `SELECT 
         (SELECT COUNT(*) FROM committee_members cm WHERE cm.committee_id = $1 AND cm.membership_status = 'ACTIVE') as member_count,
         (SELECT COALESCE(SUM(o.due_amount_minor), 0) FROM obligations o WHERE o.committee_id = $1) as total_expected_minor,
         (SELECT COALESCE(SUM(ca.amount_minor), 0) FROM collection_allocations ca WHERE ca.obligation_id IN (SELECT id FROM obligations WHERE committee_id = $1)) as total_collected_minor`,
      [committeeId]
    );

    const stats = statsRes.rows[0];
    const totalExpected = BigInt(stats.total_expected_minor || 0);
    const totalCollected = BigInt(stats.total_collected_minor || 0);
    const totalOutstanding = totalExpected > totalCollected ? totalExpected - totalCollected : 0n;

    const todayStr = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kathmandu' }).format(new Date());

    const overdueMembersRes = await query(
      `SELECT COUNT(DISTINCT o.member_id) as overdue_count
       FROM obligations o
       LEFT JOIN (
         SELECT obligation_id, SUM(amount_minor) as total_alloc
         FROM collection_allocations
         GROUP BY obligation_id
       ) ca ON ca.obligation_id = o.id
       WHERE o.committee_id = $1
         AND o.due_date < $2
         AND (o.due_amount_minor > COALESCE(ca.total_alloc, 0))`,
      [committeeId, todayStr]
    );

    const recentCollectionsRes = await query(
      `SELECT c.id, c.member_id, m.display_name as member_name, c.amount_minor, c.currency_code, c.received_at, c.reversal_status
       FROM collections c
       JOIN members m ON m.id = c.member_id
       WHERE c.committee_id = $1
       ORDER BY c.received_at DESC
       LIMIT 5`,
      [committeeId]
    );

    sendSuccess(res, {
      committeeId: committee.id,
      name: committee.name,
      status: committee.status,
      memberCount: Number(stats.member_count),
      totalExpectedMinor: totalExpected.toString(),
      totalCollectedMinor: totalCollected.toString(),
      totalOutstandingMinor: totalOutstanding.toString(),
      overdueMembersCount: Number(overdueMembersRes.rows[0].overdue_count),
      recentCollections: recentCollectionsRes.rows,
    });
  })
);

// GET /committees/:committeeId/calendar
committeesRouter.get(
  '/committees/:committeeId/calendar',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    const month = req.query['month'] as string;
    await getAuthorizedCommittee(committeeId, req.user!.userId);

    let dateFilter = '';
    const params: any[] = [committeeId];

    if (month && /^\d{4}-\d{2}$/.test(month)) {
      dateFilter = `AND to_char(o.due_date, 'YYYY-MM') = $2`;
      params.push(month);
    }

    const resObs = await query(
      `SELECT o.id, o.due_date, o.due_amount_minor, o.member_id, m.display_name as member_name,
              COALESCE(SUM(ca.amount_minor), 0) as allocated_minor,
              json_agg(
                json_build_object(
                  'amountMinor', ca.amount_minor,
                  'receivedAt', c.received_at
                )
              ) FILTER (WHERE ca.id IS NOT NULL) as allocations_json
       FROM obligations o
       JOIN members m ON m.id = o.member_id
       LEFT JOIN collection_allocations ca ON ca.obligation_id = o.id
       LEFT JOIN collections c ON c.id = ca.collection_id AND c.reversal_status = 'ACTIVE'
       WHERE o.committee_id = $1 ${dateFilter}
       GROUP BY o.id, o.due_date, o.due_amount_minor, o.member_id, m.display_name
       ORDER BY o.due_date ASC`,
      params
    );

    const daysMap = new Map<string, any>();

    for (const row of resObs.rows) {
      const dueDateStr = row.due_date instanceof Date
        ? row.due_date.toISOString().split('T')[0]
        : String(row.due_date);

      const allocations = (row.allocations_json || []).map((a: any) => ({
        amountMinor: BigInt(a.amountMinor),
        receivedAt: a.receivedAt,
      }));

      const state = StatusCalculator.calculate({
        dueDate: dueDateStr,
        dueAmountMinor: BigInt(row.due_amount_minor),
        allocations,
      });

      if (!daysMap.has(dueDateStr)) {
        daysMap.set(dueDateStr, {
          date: dueDateStr,
          obligationsCount: 0,
          paidOnTimeCount: 0,
          paidLateCount: 0,
          overdueCount: 0,
          upcomingCount: 0,
          partialCount: 0,
          totalDueMinor: 0n,
          totalCollectedMinor: 0n,
          totalOutstandingMinor: 0n,
          items: [],
        });
      }

      const dayGroup = daysMap.get(dueDateStr)!;
      dayGroup.obligationsCount += 1;
      dayGroup.totalDueMinor += state.dueAmountMinor;
      dayGroup.totalCollectedMinor += state.allocatedAmountMinor;
      dayGroup.totalOutstandingMinor += state.outstandingAmountMinor;

      if (state.status === 'PAID_ON_TIME') dayGroup.paidOnTimeCount += 1;
      else if (state.status === 'PAID_LATE') dayGroup.paidLateCount += 1;
      else if (state.status === 'UNPAID_OVERDUE') dayGroup.overdueCount += 1;
      else if (state.status === 'PARTIALLY_PAID') dayGroup.partialCount += 1;
      else if (state.status === 'UPCOMING') dayGroup.upcomingCount += 1;

      dayGroup.items.push({
        obligationId: row.id,
        memberId: row.member_id,
        memberName: row.member_name,
        dueAmountMinor: state.dueAmountMinor.toString(),
        allocatedAmountMinor: state.allocatedAmountMinor.toString(),
        outstandingAmountMinor: state.outstandingAmountMinor.toString(),
        status: state.status,
      });
    }

    // Fetch bidding rounds for this committee to display in calendar
    const roundsRes = await query(
      `SELECT br.*, m.display_name as winner_name
       FROM bidding_rounds br
       LEFT JOIN members m ON m.id = br.winner_member_id
       WHERE br.committee_id = $1
       ORDER BY br.round_number ASC`,
      [committeeId]
    );

    const rounds = roundsRes.rows.map((r) => ({
      id: r.id,
      roundNumber: r.round_number,
      roundDate: r.round_date instanceof Date ? r.round_date.toISOString().split('T')[0] : String(r.round_date),
      totalPotMinor: r.total_pot_minor,
      minBidMinor: r.min_bid_minor,
      status: r.status,
      winnerMemberId: r.winner_member_id,
      winnerName: r.winner_name,
      winningBidMinor: r.winning_bid_minor,
      netPayoutMinor: r.net_payout_minor,
      awardedAt: r.awarded_at,
      notes: r.notes,
    }));

    for (const round of rounds) {
      if (daysMap.has(round.roundDate)) {
        daysMap.get(round.roundDate)!.biddingRound = round;
      } else {
        // If the round date isn't an obligation due date, include it in the calendar days
        daysMap.set(round.roundDate, {
          date: round.roundDate,
          obligationsCount: 0,
          paidOnTimeCount: 0,
          paidLateCount: 0,
          overdueCount: 0,
          upcomingCount: 0,
          partialCount: 0,
          totalDueMinor: 0n,
          totalCollectedMinor: 0n,
          totalOutstandingMinor: 0n,
          items: [],
          biddingRound: round,
        });
      }
    }

    const days = Array.from(daysMap.values())
      .sort((a, b) => a.date.localeCompare(b.date))
      .map((d) => ({
        ...d,
        totalDueMinor: d.totalDueMinor.toString(),
        totalCollectedMinor: d.totalCollectedMinor.toString(),
        totalOutstandingMinor: d.totalOutstandingMinor.toString(),
      }));

    sendSuccess(res, { days, rounds });
  })
);

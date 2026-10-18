// modules/bidding/presentation/routes.ts
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

export const biddingRouter = Router();

biddingRouter.use('/committees', requireAuth);
biddingRouter.use('/bidding-rounds', requireAuth);

async function getAuthorizedCommittee(
  committeeId: string,
  userId: string,
  allowedRoles = ['OWNER', 'ADMIN', 'COLLECTOR', 'VIEWER']
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
  if (!allowedRoles.includes(committee.user_role)) {
    throw new ForbiddenError('Insufficient role to access bidding in this committee');
  }
  return committee;
}

// GET /committees/:committeeId/bidding-rounds
biddingRouter.get(
  '/committees/:committeeId/bidding-rounds',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    const userId = req.user!.userId;
    await getAuthorizedCommittee(committeeId, userId);

    const roundsRes = await query(
      `SELECT br.*, m.display_name as winner_name
       FROM bidding_rounds br
       LEFT JOIN members m ON m.id = br.winner_member_id
       WHERE br.committee_id = $1
       ORDER BY br.round_number ASC`,
      [committeeId]
    );

    const bidsRes = await query(
      `SELECT b.*, m.display_name as member_name
       FROM bids b
       JOIN members m ON m.id = b.member_id
       WHERE b.committee_id = $1
       ORDER BY b.bid_amount_minor DESC, b.submitted_at ASC`,
      [committeeId]
    );

    const bidsByRound = new Map<string, any[]>();
    for (const b of bidsRes.rows) {
      const list = bidsByRound.get(b.round_id) || [];
      list.push({
        id: b.id,
        memberId: b.member_id,
        memberName: b.member_name,
        bidAmountMinor: b.bid_amount_minor,
        submittedAt: b.submitted_at,
        status: b.status,
        notes: b.notes,
      });
      bidsByRound.set(b.round_id, list);
    }

    const rounds = roundsRes.rows.map((r: any) => ({
      id: r.id,
      committeeId: r.committee_id,
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
      createdAt: r.created_at,
      bids: bidsByRound.get(r.id) || [],
    }));

    sendSuccess(res, { rounds });
  })
);

// POST /committees/:committeeId/bidding-rounds (Organizer releases/opens an auction round)
const createRoundSchema = z.object({
  roundNumber: z.number().int().positive().optional(),
  roundDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  totalPotMinor: z.number().int().positive('Total pot must be positive'),
  minBidMinor: z.number().int().nonnegative().optional().default(0),
  notes: z.string().optional(),
});

biddingRouter.post(
  '/committees/:committeeId/bidding-rounds',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    const userId = req.user!.userId;
    const body = createRoundSchema.parse(req.body);
    const committee = await getAuthorizedCommittee(committeeId, userId, ['OWNER', 'ADMIN']);

    let roundNum = body.roundNumber;
    if (!roundNum) {
      const maxRes = await query(
        `SELECT COALESCE(MAX(round_number), 0) + 1 as next_round
         FROM bidding_rounds
         WHERE committee_id = $1`,
        [committeeId]
      );
      roundNum = parseInt(maxRes.rows[0].next_round, 10);
    }

    const resInsert = await query(
      `INSERT INTO bidding_rounds (
        workspace_id, committee_id, round_number, round_date,
        total_pot_minor, min_bid_minor, status, notes
      ) VALUES ($1, $2, $3, $4, $5, $6, 'OPEN', $7)
      RETURNING *`,
      [
        committee.workspace_id,
        committeeId,
        roundNum,
        body.roundDate,
        body.totalPotMinor.toString(),
        body.minBidMinor.toString(),
        body.notes || null,
      ]
    );

    const round = resInsert.rows[0];

    await query(
      `INSERT INTO audit_events (
        workspace_id, actor_id, action, entity_type, entity_id, metadata
      ) VALUES ($1, $2, 'BIDDING_ROUND_CREATED', 'BIDDING_ROUND', $3, $4)`,
      [
        committee.workspace_id,
        userId,
        round.id,
        JSON.stringify({ roundNumber: roundNum, totalPotMinor: body.totalPotMinor }),
      ]
    );

    sendCreated(res, { round });
  })
);

// POST /bidding-rounds/:roundId/bids (Member or Organizer places a bid)
const placeBidSchema = z.object({
  memberId: z.string().uuid().optional(),
  bidAmountMinor: z.number().int().positive('Bid discount/margin must be positive'),
  notes: z.string().optional(),
});

biddingRouter.post(
  '/bidding-rounds/:roundId/bids',
  asyncHandler(async (req: Request, res: Response) => {
    const roundId = req.params['roundId'] || '';
    const userId = req.user!.userId;
    const body = placeBidSchema.parse(req.body);

    const roundRes = await query(
      `SELECT br.*, c.workspace_id
       FROM bidding_rounds br
       JOIN committees c ON c.id = br.committee_id
       WHERE br.id = $1`,
      [roundId]
    );
    if (!roundRes.rowCount || roundRes.rowCount === 0) {
      throw new NotFoundError('Bidding round not found');
    }
    const round = roundRes.rows[0];

    if (round.status !== 'OPEN') {
      throw new DomainError('CONFLICT', `Bidding round is currently ${round.status} and cannot accept bids`);
    }

    if (BigInt(body.bidAmountMinor) < BigInt(round.min_bid_minor)) {
      throw new DomainError('VALIDATION_ERROR', `Bid must be at least NPR ${BigInt(round.min_bid_minor) / 100n}`);
    }

    if (BigInt(body.bidAmountMinor) >= BigInt(round.total_pot_minor)) {
      throw new DomainError('VALIDATION_ERROR', 'Bid discount cannot exceed or equal the total pot amount');
    }

    let targetMemberId = body.memberId;
    if (!targetMemberId) {
      // Find linked member for this user in this committee
      const memberQuery = await query(
        `SELECT m.id FROM members m
         JOIN committee_members cm ON cm.member_id = m.id
         WHERE cm.committee_id = $1 AND m.user_id = $2`,
        [round.committee_id, userId]
      );
      if (!memberQuery.rowCount || memberQuery.rowCount === 0) {
        throw new DomainError('FORBIDDEN', 'No committee membership found linked to your account');
      }
      targetMemberId = memberQuery.rows[0].id;
    }

    const bidRes = await query(
      `INSERT INTO bids (
        round_id, committee_id, member_id, bid_amount_minor, notes
      ) VALUES ($1, $2, $3, $4, $5)
      RETURNING *`,
      [
        roundId,
        round.committee_id,
        targetMemberId,
        body.bidAmountMinor.toString(),
        body.notes || null,
      ]
    );

    const bid = bidRes.rows[0];
    sendCreated(res, { bid });
  })
);

// POST /bidding-rounds/:roundId/award (Organizer awards round to winning member)
const awardRoundSchema = z.object({
  winnerMemberId: z.string().uuid(),
  winningBidMinor: z.number().int().nonnegative(),
  notes: z.string().optional(),
});

biddingRouter.post(
  '/bidding-rounds/:roundId/award',
  asyncHandler(async (req: Request, res: Response) => {
    const roundId = req.params['roundId'] || '';
    const userId = req.user!.userId;
    const body = awardRoundSchema.parse(req.body);

    const roundRes = await query(
      `SELECT br.*, c.workspace_id, wm.role
       FROM bidding_rounds br
       JOIN committees c ON c.id = br.committee_id
       JOIN workspace_memberships wm ON wm.workspace_id = c.workspace_id
       WHERE br.id = $1 AND wm.user_id = $2 AND wm.status = 'ACTIVE'`,
      [roundId, userId]
    );
    if (!roundRes.rowCount || roundRes.rowCount === 0) {
      throw new NotFoundError('Bidding round not found');
    }
    const round = roundRes.rows[0];
    if (!['OWNER', 'ADMIN'].includes(round.role)) {
      throw new ForbiddenError('Only committee organizers can award bidding rounds');
    }

    if (round.status === 'AWARDED') {
      throw new DomainError('CONFLICT', 'Bidding round has already been awarded');
    }

    const totalPot = BigInt(round.total_pot_minor);
    const winningBid = BigInt(body.winningBidMinor);
    const netPayout = totalPot > winningBid ? totalPot - winningBid : 0n;

    const updatedRound = await withTransaction(async (client) => {
      const uRes = await client.query(
        `UPDATE bidding_rounds
         SET status = 'AWARDED',
             winner_member_id = $1,
             winning_bid_minor = $2,
             net_payout_minor = $3,
             awarded_at = NOW(),
             notes = COALESCE($4, notes)
         WHERE id = $5
         RETURNING *`,
        [body.winnerMemberId, winningBid.toString(), netPayout.toString(), body.notes || null, roundId]
      );

      // Update bids status
      await client.query(
        `UPDATE bids
         SET status = CASE WHEN member_id = $1 THEN 'WINNING' ELSE 'ACTIVE' END
         WHERE round_id = $2`,
        [body.winnerMemberId, roundId]
      );

      await client.query(
        `INSERT INTO audit_events (
          workspace_id, actor_id, action, entity_type, entity_id, metadata
        ) VALUES ($1, $2, 'BIDDING_ROUND_AWARDED', 'BIDDING_ROUND', $3, $4)`,
        [
          round.workspace_id,
          userId,
          roundId,
          JSON.stringify({
            winnerMemberId: body.winnerMemberId,
            winningBidMinor: winningBid.toString(),
            netPayoutMinor: netPayout.toString(),
          }),
        ]
      );

      return uRes.rows[0];
    });

    sendSuccess(res, { round: updatedRound });
  })
);

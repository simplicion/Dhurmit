// modules/ledger/presentation/routes.ts
import { Router, Request, Response } from 'express';
import crypto from 'crypto';
import { z } from 'zod';
import { query, withTransaction } from '../../../shared/infrastructure/postgres/connection.js';
import { sendSuccess } from '../../../shared/presentation/response.js';
import { asyncHandler } from '../../../shared/presentation/async-handler.js';
import {
  DomainError,
  ForbiddenError,
  IdempotencyConflictError,
  NotFoundError,
} from '../../../shared/domain/errors.js';
import { requireAuth } from '../../../shared/presentation/middlewares/auth.middleware.js';
import { StatusCalculator } from '../domain/status-calculator.js';
import { AllocationEngine } from '../domain/allocation-engine.js';

export const ledgerRouter = Router();

ledgerRouter.use('/committees', requireAuth);
ledgerRouter.use('/collections', requireAuth);

async function getAuthorizedCommittee(committeeId: string, userId: string, allowedRoles = ['OWNER', 'ADMIN', 'COLLECTOR']) {
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
    throw new ForbiddenError('Insufficient role to record or modify collections');
  }
  return committee;
}

// POST /committees/:committeeId/collections
const recordCollectionSchema = z.object({
  memberId: z.string().uuid(),
  amountMinor: z.number().int().positive('Collection amount must be positive'),
  currencyCode: z.string().length(3).default('NPR'),
  receivedAt: z.string().datetime().or(z.string().regex(/^\d{4}-\d{2}-\d{2}(T.*)?$/)),
  methodLabel: z.string().optional().default('CASH'),
  reference: z.string().nullable().optional(),
  note: z.string().nullable().optional(),
  allocations: z
    .array(
      z.object({
        obligationId: z.string().uuid(),
        amountMinor: z.number().int().positive(),
      })
    )
    .optional(),
});

ledgerRouter.post(
  '/committees/:committeeId/collections',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    const userId = req.user!.userId;
    const body = recordCollectionSchema.parse(req.body);
    const committee = await getAuthorizedCommittee(committeeId, userId, ['OWNER', 'ADMIN', 'COLLECTOR']);
    const idempotencyKey = (req.headers['idempotency-key'] as string) || (req.headers['x-idempotency-key'] as string);

    const requestPayloadString = JSON.stringify({
      committeeId,
      memberId: body.memberId,
      amountMinor: body.amountMinor,
      receivedAt: body.receivedAt,
      allocations: body.allocations,
    });
    const requestHash = crypto.createHash('sha256').update(requestPayloadString).digest('hex');

    if (idempotencyKey) {
      const existingIdem = await query(
        `SELECT request_hash, response_status, response_body
         FROM idempotency_records
         WHERE workspace_id = $1 AND actor_id = $2 AND idempotency_key = $3`,
        [committee.workspace_id, userId, idempotencyKey]
      );

      if (existingIdem.rowCount && existingIdem.rowCount > 0) {
        const rec = existingIdem.rows[0];
        if (rec.request_hash !== requestHash) {
          throw new IdempotencyConflictError();
        }
        res.status(rec.response_status).json(rec.response_body);
        return;
      }
    }

    const result = await withTransaction(async (client) => {
      const memberCheck = await client.query(
        `SELECT membership_status FROM committee_members WHERE committee_id = $1 AND member_id = $2`,
        [committeeId, body.memberId]
      );
      if (!memberCheck.rowCount || memberCheck.rowCount === 0) {
        throw new DomainError('VALIDATION_ERROR', 'Member is not enrolled in this committee');
      }

      // Lock member obligations to prevent concurrent race conditions
      await client.query(
        `SELECT id FROM obligations
         WHERE committee_id = $1 AND member_id = $2
         ORDER BY due_date ASC
         FOR UPDATE`,
        [committeeId, body.memberId]
      );

      const openObligationsRes = await client.query(
        `SELECT o.id, o.due_date, o.due_amount_minor, o.currency_code,
                COALESCE(SUM(ca.amount_minor), 0) as already_allocated_minor
         FROM obligations o
         LEFT JOIN collection_allocations ca ON ca.obligation_id = o.id
         LEFT JOIN collections c ON c.id = ca.collection_id AND c.reversal_status = 'ACTIVE'
         WHERE o.committee_id = $1 AND o.member_id = $2
         GROUP BY o.id, o.due_date, o.due_amount_minor, o.currency_code
         ORDER BY o.due_date ASC`,
        [committeeId, body.memberId]
      );

      const obligations = openObligationsRes.rows.map((row: any) => {
        const due = BigInt(row.due_amount_minor);
        const allocated = BigInt(row.already_allocated_minor);
        const remaining = due > allocated ? due - allocated : 0n;
        return {
          id: row.id,
          dueDate: row.due_date instanceof Date ? row.due_date.toISOString().split('T')[0] : String(row.due_date),
          dueAmountMinor: due,
          alreadyAllocatedMinor: allocated,
          remainingAmountMinor: remaining,
        };
      });

      const collectionAmount = BigInt(body.amountMinor);
      const allocationResult = AllocationEngine.computeAllocations({
        collectionAmountMinor: collectionAmount,
        obligations,
        manualAllocations: body.allocations
          ? body.allocations.map((a) => ({
              obligationId: a.obligationId,
              amountMinor: BigInt(a.amountMinor),
            }))
          : undefined,
        allowPartialPayment: committee.allow_partial_payment,
        allowUnallocatedCredit: committee.allow_unallocated_credit,
        allocationPolicy: committee.allocation_policy,
      });

      const finalAllocations = allocationResult.allocations;

      const colRes = await client.query(
        `INSERT INTO collections (
          workspace_id, committee_id, member_id, amount_minor,
          currency_code, received_at, method_label, reference, note, recorded_by
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        RETURNING *`,
        [
          committee.workspace_id,
          committeeId,
          body.memberId,
          collectionAmount.toString(),
          body.currencyCode,
          new Date(body.receivedAt).toISOString(),
          body.methodLabel || 'CASH',
          body.reference || null,
          body.note || null,
          userId,
        ]
      );

      const collection = colRes.rows[0];

      for (const alloc of finalAllocations) {
        await client.query(
          `INSERT INTO collection_allocations (
            workspace_id, collection_id, obligation_id, amount_minor, created_by
          ) VALUES ($1, $2, $3, $4, $5)`,
          [
            committee.workspace_id,
            collection.id,
            alloc.obligationId,
            alloc.amountMinor.toString(),
            userId,
          ]
        );
      }

      await client.query(
        `INSERT INTO audit_events (
          workspace_id, actor_id, action, entity_type, entity_id, metadata
        ) VALUES ($1, $2, 'COLLECTION_RECORDED', 'COLLECTION', $3, $4)`,
        [
          committee.workspace_id,
          userId,
          collection.id,
          JSON.stringify({
            memberId: body.memberId,
            amountMinor: collectionAmount.toString(),
            allocationsCount: finalAllocations.length,
          }),
        ]
      );

      let updatedObligations: any[] = [];
      if (finalAllocations.length > 0) {
        const updatedObligationsRes = await client.query(
          `SELECT o.id, o.due_date, o.due_amount_minor,
                  json_agg(
                    json_build_object(
                      'amountMinor', ca.amount_minor,
                      'receivedAt', c.received_at
                    )
                  ) FILTER (WHERE ca.id IS NOT NULL) as allocations_json
           FROM obligations o
           LEFT JOIN collection_allocations ca ON ca.obligation_id = o.id
           LEFT JOIN collections c ON c.id = ca.collection_id AND c.reversal_status = 'ACTIVE'
           WHERE o.id = ANY($1::uuid[])
           GROUP BY o.id, o.due_date, o.due_amount_minor`,
          [finalAllocations.map((a) => a.obligationId)]
        );

        updatedObligations = updatedObligationsRes.rows.map((row: any) => {
          const dueDateStr = row.due_date instanceof Date ? row.due_date.toISOString().split('T')[0] : String(row.due_date);
          const allocs = (row.allocations_json || []).map((a: any) => ({
            amountMinor: BigInt(a.amountMinor),
            receivedAt: a.receivedAt,
          }));
          const state = StatusCalculator.calculate({
            dueDate: dueDateStr,
            dueAmountMinor: BigInt(row.due_amount_minor),
            allocations: allocs,
          });

          return {
            obligationId: row.id,
            dueDate: dueDateStr,
            dueAmountMinor: state.dueAmountMinor.toString(),
            allocatedAmountMinor: state.allocatedAmountMinor.toString(),
            outstandingAmountMinor: state.outstandingAmountMinor.toString(),
            status: state.status,
          };
        });
      }

      const responsePayload = {
        data: {
          collectionId: collection.id,
          committeeId: collection.committee_id,
          memberId: collection.member_id,
          amountMinor: collection.amount_minor,
          currencyCode: collection.currency_code,
          receivedAt: collection.received_at,
          allocations: finalAllocations.map((a) => ({
            obligationId: a.obligationId,
            amountMinor: a.amountMinor.toString(),
          })),
          updatedObligations,
        },
        meta: {
          requestId: req.requestId,
        },
      };

      if (idempotencyKey) {
        await client.query(
          `INSERT INTO idempotency_records (
            workspace_id, actor_id, idempotency_key, request_hash,
            response_status, response_body
          ) VALUES ($1, $2, $3, $4, 201, $5)
          ON CONFLICT (workspace_id, actor_id, idempotency_key) DO UPDATE
          SET response_body = EXCLUDED.response_body`,
          [
            committee.workspace_id,
            userId,
            idempotencyKey,
            requestHash,
            JSON.stringify(responsePayload),
          ]
        );
      }

      return responsePayload;
    });

    res.status(201).json(result);
  })
);

// GET /committees/:committeeId/collections
ledgerRouter.get(
  '/committees/:committeeId/collections',
  asyncHandler(async (req: Request, res: Response) => {
    const committeeId = req.params['committeeId'] || '';
    const memberId = req.query['memberId'] as string;
    const from = req.query['from'] as string;
    const to = req.query['to'] as string;
    await getAuthorizedCommittee(committeeId, req.user!.userId, ['OWNER', 'ADMIN', 'COLLECTOR', 'VIEWER']);

    let filterClause = '';
    const params: any[] = [committeeId];

    if (memberId) {
      params.push(memberId);
      filterClause += ` AND c.member_id = $${params.length}`;
    }
    if (from) {
      params.push(from);
      filterClause += ` AND c.received_at >= $${params.length}`;
    }
    if (to) {
      params.push(to);
      filterClause += ` AND c.received_at <= $${params.length}`;
    }

    const result = await query(
      `SELECT c.*, m.display_name as member_name, u.display_name as recorded_by_name,
              (SELECT COUNT(*) FROM collection_allocations ca WHERE ca.collection_id = c.id) as allocation_count
       FROM collections c
       JOIN members m ON m.id = c.member_id
       JOIN users u ON u.id = c.recorded_by
       WHERE c.committee_id = $1 ${filterClause}
       ORDER BY c.received_at DESC`,
      params
    );

    sendSuccess(res, result.rows);
  })
);

// GET /collections/:collectionId
ledgerRouter.get(
  '/collections/:collectionId',
  asyncHandler(async (req: Request, res: Response) => {
    const collectionId = req.params['collectionId'] || '';
    const userId = req.user!.userId;

    const colRes = await query(
      `SELECT c.*, m.display_name as member_name, comm.name as committee_name, u.display_name as recorded_by_name
       FROM collections c
       JOIN members m ON m.id = c.member_id
       JOIN committees comm ON comm.id = c.committee_id
       JOIN users u ON u.id = c.recorded_by
       JOIN workspace_memberships wm ON wm.workspace_id = c.workspace_id
       WHERE c.id = $1 AND wm.user_id = $2 AND wm.status = 'ACTIVE'`,
      [collectionId, userId]
    );

    if (!colRes.rowCount || colRes.rowCount === 0) {
      throw new NotFoundError('Collection not found or access denied');
    }

    const collection = colRes.rows[0];

    const allocRes = await query(
      `SELECT ca.id, ca.obligation_id, ca.amount_minor, o.due_date, o.due_amount_minor
       FROM collection_allocations ca
       JOIN obligations o ON o.id = ca.obligation_id
       WHERE ca.collection_id = $1
       ORDER BY o.due_date ASC`,
      [collectionId]
    );

    sendSuccess(res, {
      ...collection,
      allocations: allocRes.rows,
    });
  })
);

// POST /collections/:collectionId/reverse
const reverseCollectionSchema = z.object({
  reason: z.string().min(5, 'Reversal reason must be at least 5 characters'),
});

ledgerRouter.post(
  '/collections/:collectionId/reverse',
  asyncHandler(async (req: Request, res: Response) => {
    const collectionId = req.params['collectionId'] || '';
    const userId = req.user!.userId;
    const body = reverseCollectionSchema.parse(req.body);

    const colRes = await query(
      `SELECT c.*, wm.role
       FROM collections c
       JOIN workspace_memberships wm ON wm.workspace_id = c.workspace_id
       WHERE c.id = $1 AND wm.user_id = $2 AND wm.status = 'ACTIVE'`,
      [collectionId, userId]
    );

    if (!colRes.rowCount || colRes.rowCount === 0) {
      throw new NotFoundError('Collection not found');
    }

    const collection = colRes.rows[0];
    if (!['OWNER', 'ADMIN'].includes(collection.role)) {
      throw new ForbiddenError('Only workspace owners and admins can reverse collections');
    }

    if (collection.reversal_status === 'REVERSED') {
      throw new DomainError('CONFLICT', 'Collection has already been reversed');
    }

    await withTransaction(async (client) => {
      await client.query(
        `UPDATE collections SET reversal_status = 'REVERSED' WHERE id = $1`,
        [collectionId]
      );

      await client.query(
        `INSERT INTO ledger_adjustments (
          workspace_id, committee_id, member_id, collection_id,
          adjustment_type, amount_minor, reason, created_by
        ) VALUES ($1, $2, $3, $4, 'REVERSAL', $5, $6, $7)`,
        [
          collection.workspace_id,
          collection.committee_id,
          collection.member_id,
          collectionId,
          collection.amount_minor,
          body.reason,
          userId,
        ]
      );

      await client.query(
        `INSERT INTO audit_events (
          workspace_id, actor_id, action, entity_type, entity_id, reason, metadata
        ) VALUES ($1, $2, 'COLLECTION_REVERSED', 'COLLECTION', $3, $4, $5)`,
        [
          collection.workspace_id,
          userId,
          collectionId,
          body.reason,
          JSON.stringify({ originalAmountMinor: collection.amount_minor }),
        ]
      );
    });

    sendSuccess(res, {
      message: 'Collection reversed successfully',
      collectionId,
      reversalStatus: 'REVERSED',
    });
  })
);

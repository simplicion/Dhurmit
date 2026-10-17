# ADR-006: Allocation Engine, Lump-Sum Arrears, and Partial Payments

## Status
Accepted

## Context
A major pain point in paper-based committee recordkeeping is handling lump-sum payments covering multiple past missed dues (e.g., member misses 5 due dates and pays NPR 12,000 on the 26th). The application must maintain financial ledger integrity, preserve actual collection dates, support retry-safe idempotency, and prevent cross-member or cross-committee allocations.

## Decision
1. **Separation of Dates:** The actual collection received timestamp (`received_at`) is stored in UTC and displayed in local time. The obligation due date (`due_date`) remains the original historical date. The collection date is never rewritten to match past due dates.
2. **Allocation Policies:**
   - `FIFO` (Oldest due first): Default policy where allocations apply to the oldest open obligation until depleted. The client displays a preview showing exact allocations per due date before confirmation.
   - `MANUAL`: Organizer specifies explicit amounts per obligation.
3. **Atomic Persistence:** In a single PostgreSQL transaction under row-level locks:
   - Lock member obligations `FOR UPDATE` in deterministic date order.
   - Insert `collections` record.
   - Insert `collection_allocations` records linking collection to obligations.
   - Record `audit_events`.
   - Store `idempotency_records` with request hash and response payload.
4. **Status Transitions:**
   - An obligation is `PAID_ON_TIME` (green) if and only if outstanding is zero and all active allocations were received on or before `due_date`.
   - An obligation is `PAID_LATE` (orange) if outstanding is zero and at least one allocation was received after `due_date`.
   - Any obligation with remaining due is `PARTIALLY_PAID` or `UNPAID_OVERDUE` (red).
5. **Partial and Overpayment Invariants:**
   - Allocation sum must equal collection amount (unless `allow_unallocated_credit` is enabled).
   - Zero or negative amounts are rejected.
   - Cross-member and cross-committee allocations are rejected.
6. **Reversals:** Mistaken entries are reversed by creating an audited reversal record linking back to the original collection and recalculating derived balances.

## Consequences
- Guarantees financial ledger integrity and prevents race conditions under concurrent network retries.
- Auditable history is preserved forever without destructive row deletion.

# 03 — Low-Level Design (LLD)

## 1. Layering

Each backend module follows:

1. **Presentation:** HTTP controllers, request/response DTOs, validation, route registration.
2. **Application:** use cases, orchestration, transaction boundaries, authorization policy invocation.
3. **Domain:** entities/value objects, invariants, status calculation, domain policies.
4. **Infrastructure:** PostgreSQL repositories, query implementations, external adapters.

Dependencies point inward. Domain must not import HTTP framework, ORM, or infrastructure modules.

Flutter follows feature-first clean layering:
- `presentation/`: screens, widgets, view models/state controllers.
- `application/`: commands, queries, state orchestration.
- `domain/`: entities, value objects, repository contracts.
- `data/`: API DTOs, mappers, repository implementations.

## 2. Backend use cases

### Committee
- `CreateCommittee`
- `GetCommitteeDetails`
- `UpdateCommitteeDraft`
- `ActivateCommittee`
- `PreviewSchedule`
- `ArchiveCommittee`
- `ApplyFutureScheduleChange`

### Members
- `AddMemberToCommittee`
- `UpdateMemberDetails`
- `DeactivateMember`
- `SearchCommitteeMembers`
- `GetMemberStatement`

### Schedule
- `GenerateObligations`
- `GetCalendarStatuses`
- `GetOutstandingObligations`
- `RebuildFutureSchedule` (future dues only unless an approved migration is explicitly invoked)

### Ledger
- `RecordCollection`
- `GetCollection`
- `ListCollections`
- `AllocateCollection`
- `ReverseCollection`
- `RecordAdjustment`
- `GetCommitteeLedgerSummary`

### Access and audit
- `InviteStaff` (optional)
- `ChangeMemberRole`
- `ListAuditEvents`

## 3. Domain types

- `Money`: integer `minorUnits`, currency code; addition/subtraction require matching currency.
- `CommitteeId`, `MemberId`, `ObligationId`, `CollectionId`: opaque IDs (UUID recommended).
- `DueDate`: date-only value in committee schedule timezone.
- `ReceivedAt`: timestamp with explicit timezone; persist as UTC.
- `ContributionSchedule`: frequency, anchor date, rule, end condition, timezone.
- `Obligation`: due date, due amount, active allocations, outstanding amount, derived status.
- `Collection`: actual received date/time, amount, member, committee, creator, reference.
- `Allocation`: collection, obligation, amount.
- `Reversal`: references original collection/allocation and includes reason and actor.

## 4. RecordCollection algorithm

```text
input: committeeId, memberId, amountMinor, receivedAt, allocations?, idempotencyKey
authenticate actor
authorize actor for committee
validate amountMinor > 0
begin database transaction
  if idempotency key already exists:
    return stored response for same request; reject if payload differs
  lock target member/committee obligations that may be allocated
  verify member belongs to committee
  load open obligations in deterministic order
  if allocations explicitly supplied:
    validate each obligation belongs to same committee and member
    validate each allocation amount > 0
    validate sum(allocations) <= amountMinor
  else:
    apply configured allocation policy; if policy requires manual allocation, return allocation-required error
  validate partial payment / overpayment rules
  insert collection
  insert allocation rows
  insert audit event
  save idempotency result
commit
return canonical collection + updated obligation statuses
```

Do not create a collection first and allocate later without a clear pending state and reconciliation flow. The default should be one atomic operation.

## 5. Status calculation

For an obligation:
- `dueMinor` = configured due amount plus/minus approved adjustments.
- `allocatedMinor` = sum of active allocations less valid reversals.
- `outstandingMinor` = max(dueMinor - allocatedMinor, 0).
- If outstanding is zero and all relevant allocations were received on/before due date: `PAID_ON_TIME`.
- If outstanding is zero and any amount needed to fully settle it was received after due date: `PAID_LATE`.
- If allocated > 0 and outstanding > 0: `PARTIALLY_PAID`, with a separate overdue/upcoming qualifier.
- If outstanding > 0 and due date is before the current date in committee timezone: `UNPAID_OVERDUE`.
- Otherwise: `UPCOMING`.

For complex partial allocations across multiple dates, define late-paid semantics carefully: status is `PAID_LATE` if the obligation's final settlement date is after the due date; retain all individual allocation dates in the statement.

## 6. Concurrency and idempotency

- Use PostgreSQL transactions.
- Lock obligation rows in stable sorted order (`FOR UPDATE`) when allocations can compete.
- Add unique constraint for `(actor_id, idempotency_key)` or equivalent scope.
- Store request hash and response payload/status for idempotency.
- Reject same key with a different payload.
- Use optimistic version fields for concurrent committee configuration edits.
- Do not rely on Flutter button disabling as duplicate prevention.

## 7. Error model

Use consistent machine-readable errors:
- `VALIDATION_ERROR`
- `UNAUTHENTICATED`
- `FORBIDDEN`
- `NOT_FOUND`
- `CONFLICT`
- `IDEMPOTENCY_KEY_REUSED`
- `ALLOCATION_REQUIRED`
- `ALLOCATION_EXCEEDS_COLLECTION`
- `OVERPAYMENT_NOT_ALLOWED`
- `PARTIAL_PAYMENT_NOT_ALLOWED`
- `SCHEDULE_CHANGE_REQUIRES_PREVIEW`
- `INTERNAL_ERROR`

Never return SQL, stack traces, secrets, or sensitive cross-tenant details to the client.

## 8. Transactions and side effects

- Database state changes occur inside explicit transaction boundaries.
- Audit rows are written in the same transaction as the operation they audit.
- External notifications, if added, should use an outbox table and worker; do not call a flaky provider inside a long-running database transaction.
- If PDF/CSV exports are generated asynchronously later, use job records and signed, expiring download URLs.

## 9. Open design decisions

- Framework and ORM/query layer.
- Auth provider versus first-party auth.
- Exact ID strategy and token/session model.
- Whether collection allocations are mandatory at write time.
- Whether member accounts exist in MVP.
- Whether soft-deleted non-financial metadata is needed.

# 08 — Testing and Quality Plan

## 1. Testing pyramid

- Unit tests: domain calculations, schedule generation, status calculation, allocation validation.
- Integration tests: PostgreSQL repositories, transactions, constraints, migrations, idempotency.
- API tests: authorization, validation, response contracts, error handling.
- Flutter widget tests: components, theme switching, calendar states, forms.
- End-to-end tests: create committee → add members → record collection → review overdue → reverse entry.
- Security tests: tenant isolation, IDOR, privilege escalation, injection, rate limits.
- Performance tests: common read queries and collection write path at defined expected load.

## 2. Critical domain test cases

### Amount and allocation
- Reject zero and negative collection amounts.
- Reject allocation sum greater than collection amount.
- Reject allocation to another member's obligation.
- Reject allocation to another committee's obligation.
- Reject duplicate write after client timeout when same idempotency key is retried.
- Reject same idempotency key with different payload.
- Ensure partial payments obey committee policy.
- Ensure overpayment is blocked unless an explicit supported policy allows it.
- Ensure total allocated amount cannot exceed due amount without approved credit behavior.

### Status and calendar
- Fully paid before/on due date → green / `PAID_ON_TIME`.
- Fully paid after due date → orange / `PAID_LATE`.
- Past due with outstanding amount → red / `UNPAID_OVERDUE`.
- Future due with no allocation → neutral / `UPCOMING`.
- Partial payment before due date → partial, remaining amount visible.
- Partial payment after due date → partial + overdue qualifier.
- A late lump-sum collection preserves actual received date while settling historical obligations.
- Changing device timezone does not change committee due-date interpretation.

### Schedule
- Daily schedule generates expected dates.
- Monthly schedule on days 28, 29, 30, and 31.
- Leap-year February.
- Start/end boundaries.
- Schedule generation is idempotent.
- Schedule changes do not silently alter past obligations.
- Duplicate schedule generation does not create duplicate obligations.

### Audit and correction
- Collection and audit event commit together.
- Failed transaction creates neither partial collection nor partial allocation.
- Reversal references original collection and reason.
- Reversal recalculates outstanding dues.
- Financial history is not physically deleted by ordinary API routes.

### Authorization
- User A cannot read User B's committee.
- Collector cannot activate committee or change rules without permission.
- Viewer cannot record or reverse collections.
- Member identifiers cannot be used to query unrelated workspaces.

## 3. Flutter UI test cases

- Blue theme applies consistently.
- Red theme applies consistently.
- Theme switch persists after app restart.
- Status colors and text labels remain correct in both themes.
- Large font/text scaling does not hide amounts or buttons.
- Empty, loading, error, and retry states render correctly.
- Bottom sheet handles keyboard and small screens.
- Date picker shows correct local date.
- Confirmation screen displays exact allocation.
- Double tap does not create duplicate record.

## 4. Definition of test data

Use synthetic names and amounts. Never copy real member financial data into automated tests, screenshots, or logs.

## 5. Quality gates in CI

Required before merge:
- Formatter passes.
- TypeScript strict compile passes.
- Linter passes.
- Unit and integration tests pass.
- Flutter analyzer and tests pass.
- Migration validation passes.
- OpenAPI generation/validation passes.
- Dependency and secret scans pass.
- Build succeeds for target platforms.

## 6. Release acceptance scenario

1. Create workspace and authenticate.
2. Create committee with an explicit schedule rule.
3. Preview and activate schedule.
4. Add at least three members.
5. Verify generated obligations.
6. Record an on-time collection.
7. Record a late lump sum that allocates across older dues.
8. Verify green/orange/red/neutral statuses and outstanding totals.
9. Reverse a mistaken collection and verify history remains.
10. Test unauthorized access from another account.
11. Export report if feature is enabled.
12. Restore a backup into a test environment.

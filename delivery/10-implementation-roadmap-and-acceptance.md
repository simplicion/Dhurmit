# 10 — Implementation Roadmap and Acceptance

## Phase 0 — Product and legal validation

Deliverables:
- Interviews with 10–15 organizers.
- Confirmed contribution schedule vocabulary and calendar rules.
- Written legal review of software-only recordkeeping scope in Nepal.
- Final decisions on allocation, partial payments, overpayments, and membership access.
- Product glossary and approved copy.

Exit gate: unresolved legal or financial business rules are not hidden inside implementation assumptions.

## Phase 1 — Foundation

Deliverables:
- Monorepo/repository setup.
- Node.js + TypeScript strict configuration.
- Flutter app skeleton.
- PostgreSQL schema and migration framework.
- Authentication and workspace authorization.
- Central error handling and structured logging.
- CI pipeline.
- Centralized design tokens and Blue/Red theme switcher.

Exit gate: users cannot access other workspaces; CI is green.

## Phase 2 — Committee setup and schedules

Deliverables:
- Committee create/edit draft flow.
- Member CRUD/deactivation.
- Schedule preview.
- Deterministic obligation generation.
- Calendar screen with neutral/upcoming and overdue states.
- Configuration version snapshots.

Exit gate: schedule tests pass for all approved calendar edge cases.

## Phase 3 — Ledger and collections

Deliverables:
- Collection bottom sheet.
- Member search.
- Actual received date.
- Allocation preview and confirmation.
- Atomic collection/allocation persistence.
- Idempotency.
- Member statements and outstanding list.
- Audit events and reversal workflow.

Exit gate: all financial integrity tests pass, including lump-sum arrears.

## Phase 4 — Reports and usability

Deliverables:
- Committee dashboard.
- Collection register.
- Overdue report.
- Member statement.
- CSV/PDF export only if approved.
- Accessibility and localization review.
- Analytics without sensitive financial payloads.

Exit gate: representative organizers can complete core workflows without developer assistance.

## Phase 5 — Hardening and release

Deliverables:
- Security review and cross-tenant tests.
- Performance baseline.
- Backup restore test.
- Monitoring/alerts.
- User terms/privacy notice and support workflow.
- Store release builds and rollout plan.

Exit gate: legal, security, data integrity, operational, and usability gates are all passed.

## Acceptance criteria for MVP

- Organizer can create, configure, and archive a committee.
- Organizer can add and search members.
- Schedule preview clearly shows every generated due date and expected amount.
- Collection can be recorded against the actual received date.
- One collection can be allocated across multiple due obligations if policy permits.
- The app correctly distinguishes paid on time, paid late, partially paid, overdue unpaid, and upcoming.
- A lump-sum collection on the 26th can settle older due obligations without changing their historical due dates.
- Outstanding totals reconcile with due amounts, active allocations, and audited adjustments.
- Duplicate API retries do not create duplicate collections.
- Financial records cannot be silently deleted or rewritten.
- User can switch between Blue and Red themes; both use centralized tokens.
- All critical authorization, integrity, and calendar tests pass.
- Documentation and OpenAPI are up to date.
- No wallet or money movement capability exists in MVP.

## Definition of done for every feature

- Acceptance criteria written.
- Domain/business rules implemented on server.
- Authorization enforced and tested.
- Migrations and indexes included where required.
- Loading, empty, error, success, and retry states implemented.
- Unit/integration/widget tests added.
- Accessibility and both themes checked.
- Logs are privacy-safe.
- API docs and relevant design docs updated.
- No unapproved assumption is silently promoted to a product rule.

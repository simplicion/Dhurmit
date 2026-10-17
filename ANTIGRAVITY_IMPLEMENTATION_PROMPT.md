# Antigravity Master Implementation Prompt — Committee Ledger

You are the senior product engineer, software architect, backend engineer, Flutter engineer, QA lead, and security reviewer for this project. Build the project from the specification files in this documentation pack. Do not jump straight into writing a large amount of code.

## Mission

Build a reliable mobile-first committee recordkeeping application for organizers who currently maintain committee contributions in paper notebooks. It records committees, members, scheduled obligations, manually reported collections, allocation of lump-sum collections to due dates, outstanding dues, and audit history.

## Mandatory stack and architecture

- Mobile: Flutter using Dart.
- Backend: Node.js runtime with TypeScript strict mode.
- Database: PostgreSQL.
- Architecture: modular monolith; do not create microservices.
- API: versioned REST/JSON under `/api/v1`, documented using OpenAPI.
- Database changes: versioned migrations.
- UI: reusable components and a centralized design-token system.
- Themes: user-selectable Blue and Red themes.
- Financial values: integer minor units (NPR paisa), never floating point.
- Date handling: due dates are date-only in the committee timezone; event timestamps stored in UTC.
- Ledger integrity: append-only financial history; corrections use reversals/adjustments.
- PostgreSQL is the authoritative source of truth.

## Read and follow the docs first

Read all of these before implementing:
1. `product/01-product-requirements.md`
2. `architecture/02-high-level-design.md`
3. `architecture/03-low-level-design.md`
4. `architecture/04-domain-model-and-database.md`
5. `engineering/05-api-contract.md`
6. `design/06-ux-ui-and-design-system.md`
7. `engineering/07-security-privacy-and-compliance.md`
8. `engineering/08-testing-and-quality-plan.md`
9. `delivery/09-devops-observability-and-release.md`
10. `delivery/10-implementation-roadmap-and-acceptance.md`
11. `engineering/11-folder-structure-and-conventions.md`

## Product behavior that must be implemented exactly

### Committee setup
- Users can create and manage multiple committees.
- Configuration includes name, duration, start/end conditions, contribution frequency, contribution amount, schedule rule, timezone, members, partial-payment policy, and allocation policy.
- Show a schedule preview before activation.
- Do not silently rewrite past obligations when configuration changes.
- Schedule edge cases that are not resolved in docs must be recorded as Open Decisions and surfaced to the product owner before implementation.

### Member management
- Add/search/edit/deactivate members.
- A member with financial history must not be destructively deleted.
- Member records belong to a workspace and committee membership must be explicit.
- Enforce workspace/committee access in the API, not just in Flutter.

### Recording collections
- Committee detail offers a **Record collection** bottom sheet.
- Search/select member.
- Choose actual date money was received (today by default in `Asia/Kathmandu`).
- Enter amount and optional method/reference/note.
- Display due obligations with due dates, amount due, amount already allocated, and remaining amount.
- Preview exactly which due dates the collection will cover.
- Support one collection allocated across several older obligations when the selected policy allows it.
- Record the actual received date separately from each obligation's due date.
- Save collection, allocations, idempotency result, and audit event atomically.
- Retry-safe writes: a network retry must not duplicate a collection.
- Do not allow allocation across different members or committees.
- Do not silently discard or carry forward unallocated money.
- If allocation/partial-payment rules are not configured, block ambiguous cases and ask for a decision.

### Status colors and meaning
- Green + icon + label: fully paid on or before due date (`PAID_ON_TIME`).
- Orange + icon + label: fully settled after due date (`PAID_LATE`).
- Red + icon + label: past due with outstanding amount (`UNPAID_OVERDUE`).
- Neutral gray + icon + label: not yet due (`UPCOMING`).
- Partial payment must have its own label/icon and visible remaining amount.
- Colors are semantic tokens and must remain consistent when switching the primary app theme.
- Do not use color as the only status signal.
- In the scenario where five due dates were missed and the member pays a lump sum on the 26th, keep the real collection date as the 26th and allocate the amount to the covered old dues. Those dues turn orange only when fully settled late; any remaining unpaid balance stays red/partial. Never falsify historical receipt dates.

### Reports
- Committee summary, outstanding/overdue members, collection register, and member statement.
- Statements must show due date, amount due, each actual received date, allocation, and outstanding balance.
- Any export must respect permissions and not leak other workspaces' data.

### Themes
- Build Blue and Red themes from a single centralized semantic token system.
- No hardcoded hex colors in individual screens/components.
- Add a live theme switch in Settings and persist preference locally.
- Test all screens in both themes.
- The Red primary theme must not break red overdue status semantics; status includes label and icon.

## Legal and financial product boundary

This is a software recordkeeping tool. MVP must not implement or imply:
- wallet or stored value,
- custody/escrow of funds,
- bank/payment gateway integration,
- money transfers or payouts,
- auction/bidding engine,
- lending or credit scoring,
- automated financial settlement.

Do not market a manually recorded collection as independently verified proof of payment. Legal review in Nepal is a pre-launch gate; document this gate but do not try to provide legal conclusions in code.

## Implementation method — follow in order

### Step 1: Repository inspection and plan
- Inspect the existing repository before changing anything.
- If empty, scaffold the documented monorepo.
- Identify existing code and preserve working conventions unless they conflict with a mandatory requirement.
- Produce `docs/IMPLEMENTATION_PLAN.md` with phases, dependencies, risks, and acceptance criteria.
- Produce `docs/OPEN_DECISIONS.md` listing every unresolved product, legal, architecture, or UX choice.
- Do not fabricate answers to open decisions.

### Step 2: Architecture decisions
- Record ADRs for framework, database access/migrations, authentication, Flutter state management/router, schedule edge cases, allocation policy, and hosting.
- Choose mature dependencies with active maintenance.
- Explain tradeoffs briefly in each ADR.
- Keep module boundaries explicit.

### Step 3: Foundation
- Configure TypeScript strict mode, formatter, linter, test runner, environment validation, structured logs, centralized error handling, and health endpoints.
- Configure Flutter formatting, analyzer, routing, state management, API client, error handling, localization-ready strings, and secure token storage.
- Configure PostgreSQL and migration tooling.
- Add `.env.example` containing placeholders only.
- Add CI workflows for lint, type checks, tests, migrations, OpenAPI validation, and builds.

### Step 4: Database and backend domain
- Implement migrations and constraints from the database document.
- Implement domain value objects and status/allocation calculations.
- Implement transaction-safe repositories.
- Implement identity, workspace authorization, committees, members, schedules, ledger, reports, and audit modules.
- Generate OpenAPI from actual schemas/controllers or validate a checked-in spec.
- Add integration tests before wiring UI to the API.

### Step 5: Flutter design system and app shell
- Implement centralized semantic tokens, typography, spacing, radii, reusable controls, and Blue/Red themes.
- Implement navigation, loading/empty/error states, and settings theme switch.
- Keep business rules out of widgets.
- Use server responses for balances/statuses; client calculations may only support preview and must match tested domain logic.

### Step 6: Product flows
Implement in this order:
1. Authentication and workspace.
2. Committee list and creation wizard.
3. Schedule preview and activation.
4. Member management.
5. Committee dashboard and calendar.
6. Collection bottom sheet and allocation preview.
7. Collection history and receipt detail.
8. Outstanding/overdue list and member statement.
9. Reversal/correction flow.
10. Reports and optional export only if approved.

### Step 7: Quality and hardening
- Test late lump-sum allocations and all status transitions.
- Test timezone behavior and schedule boundaries.
- Test idempotency, concurrency, authorization, and cross-workspace isolation.
- Test both themes and accessibility/text scaling.
- Run dependency and secret scanning.
- Verify no financial data is logged unnecessarily.
- Test backup restore procedure if deployment infrastructure is configured.

### Step 8: Final review
Create `docs/IMPLEMENTATION_STATUS.md` containing:
- What is implemented.
- What remains incomplete.
- Commands to run backend, database, and Flutter app.
- Required environment variables.
- How to run migrations and tests.
- Test results actually observed.
- Known limitations and unresolved decisions.
- Deployment steps and rollback notes.

## Non-negotiable engineering rules

1. Do not place the entire application in one file.
2. Do not put business logic in HTTP controllers or Flutter widgets.
3. Do not use floating-point arithmetic for money.
4. Do not store mutable balances as the only source of truth.
5. Do not silently edit/delete collections or audit history.
6. Do not trust client-supplied authorization scope.
7. Do not use direct database calls from Flutter.
8. Do not create microservices for this MVP.
9. Do not hardcode colors across screens.
10. Do not invent unresolved business rules; document and request a decision.
11. Do not claim tests pass unless they were actually executed and passed.
12. Do not claim production readiness without security, legal, backup, and operational gates.
13. Do not add payment handling or wallet behavior.
14. Prefer a smaller, correct vertical slice over many incomplete screens.

## Required final deliverables

- Working repository with clear folder structure.
- Backend API and migrations.
- Flutter app with centralized theme switcher.
- OpenAPI specification.
- All required tests.
- `.env.example`.
- Docker/development setup.
- Updated PRD/HLD/LLD/schema/API/design/security/testing/DevOps docs.
- ADRs.
- `docs/OPEN_DECISIONS.md`.
- `docs/IMPLEMENTATION_STATUS.md`.
- `README.md` with exact setup and run commands.

Start by inspecting the repository and producing the implementation plan and open-decisions list. Then implement Phase 1 and proceed incrementally. At each phase, run the relevant tests and report concrete results. Never hide failing tests or unresolved requirements.

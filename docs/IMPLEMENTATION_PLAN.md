# Committee Ledger — Implementation Plan

## 1. Project Overview & Scope
- **Mission:** Build a mobile-first committee recordkeeping application for organizers transitioning from paper notebooks. Records committees, member rosters, scheduled obligations, manually reported collections, allocation of lump sums across due dates, outstanding dues, and audit trails.
- **Architectural Paradigm:** Modular monolith (single Node.js TypeScript backend, PostgreSQL database, Flutter mobile app). No microservices, no direct database queries from Flutter, no wallet/custody/escrow/payment processing.

---

## 2. Implementation Phases & Milestones

### Phase 1: Foundation & Scaffold
- **Goal:** Set up the monorepo structure, Node.js + TypeScript strict backend, PostgreSQL migration harness, Flutter app foundation, and the centralized semantic design-token system with Blue/Red theme switcher.
- **Dependencies:** Node.js v24+, Flutter 3.47+, PostgreSQL.
- **Deliverables:**
  - `apps/api`: Express/Fastify + TypeScript strict mode, Zod validation, pg/knex migration harness, structured logger, centralized error handling, `/health/live` & `/health/ready`.
  - `apps/mobile`: Flutter skeleton with GoRouter/State management, clean architecture layers (`core/theme`, `core/api`, `core/widgets`), centralized `AppColorTokens` for Blue and Red themes with semantic status tokens (green, orange, red, neutral).
  - Versioned migration 001 with core tables (`users`, `workspaces`, `workspace_memberships`, `committees`, `members`, `committee_members`, `obligations`, `collections`, `collection_allocations`, `ledger_adjustments`, `idempotency_records`, `audit_events`).
  - Baseline CI/test commands.
- **Risks:** Divergence between client and server money/date representations. (Mitigated by integer minor units and ISO 8601 UTC timestamps).

### Phase 2: Committee Setup & Deterministic Schedule Engine
- **Goal:** Enable organizers to create committees, configure contribution frequency, start date, duration, amounts, and member rosters with deterministic schedule preview and activation.
- **Deliverables:**
  - Committee creation wizard with validation.
  - Member search, add, edit, and soft-deactivation (preventing hard deletion of financial history).
  - Deterministic schedule generator supporting Daily, Weekly, Monthly (with day clamping rules), and Custom intervals.
  - Schedule preview API & UI rendering expected obligation count, dates, and amounts.
  - Committee activation creating immutable `committee_config_versions` snapshot and generating obligation rows.
- **Acceptance Criteria:**
  - Schedule generator generates correct dates across month lengths and leap years.
  - Activated committees cannot silently overwrite historical obligations.

### Phase 3: Ledger, Collections & Allocation Engine
- **Goal:** Implement the atomic collection recording workflow, multi-obligation allocation (arrears lump sum), status derivation, idempotency, and reversals.
- **Deliverables:**
  - "Record Collection" bottom sheet with member picker, actual received date (default today `Asia/Kathmandu`), amount input (NPR paisa), and optional notes/reference.
  - Allocation engine supporting FIFO (oldest due first) and manual allocation preview.
  - Atomic PostgreSQL transaction creating `collections`, `collection_allocations`, `idempotency_records`, and `audit_events` under row locks.
  - Due status calculator: `PAID_ON_TIME` (green), `PAID_LATE` (orange), `UNPAID_OVERDUE` (red), `UPCOMING` (neutral), `PARTIALLY_PAID` (partial badge + remaining amount).
  - Collection reversal workflow linked to original record with mandatory reason.
- **Acceptance Criteria:**
  - Missed 5 dues scenario: lump sum on 26th allocates to 5 older obligations, keeping collection date as 26th and marking settled historical dues as `PAID_LATE` (orange).
  - Re-sending requests with identical `Idempotency-Key` returns cached response without duplicate insertions.
  - Negative/zero amounts or cross-committee allocations are rejected with standard error codes.

### Phase 4: Committee Dashboard, Calendar, Statements & Reports
- **Goal:** Provide intuitive visualizations of dues, member statements, and collection registers.
- **Deliverables:**
  - Committee Dashboard displaying total expected, collected, outstanding, and overdue member counts.
  - Contribution Calendar rendering color-coded day cells with icons, labels, and remaining amounts.
  - Member Statement screen displaying chronologically ordered due obligations, actual collection receipt dates, allocated amounts, and running balances.
  - Overdue Members list with filtering and collection register.
- **Acceptance Criteria:**
  - Status is never communicated by color alone; distinct accessible icons and text labels accompany every status.
  - Statements accurately show separate due dates and receipt dates.

### Phase 5: Verification, Quality Assurance & Security Hardening
- **Goal:** Execute comprehensive unit, integration, and UI tests, verify cross-tenant isolation, validate OpenAPI spec, and complete documentation.
- **Deliverables:**
  - Backend integration tests verifying authorization, idempotency, transaction rollback, and status transitions.
  - Flutter widget tests testing both Blue and Red themes, theme persistence, and touch target constraints.
  - OpenAPI 3.1 documentation (`openapi.yaml` or JSON).
  - `docs/IMPLEMENTATION_STATUS.md` recording actual test execution results, running instructions, and operational verification.

---

## 3. Core Technical Decisions & Safeguards
1. **Financial Integrity:** BigInt minor units (paisa) everywhere. No floating-point division in balance or allocation math.
2. **Authoritative Server:** Client state never invents balances; all balances and statuses are returned from or verified by the backend.
3. **Tenant Isolation:** Every repository query includes `workspace_id` and checks user role permissions.
4. **Audit Trail:** Append-only records; mistakes corrected via linked reversals.

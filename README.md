# Committee Ledger

Mobile-first committee recordkeeping application for organizers replacing paper notebooks with an audit-proof digital ledger.

Version: 1.0.0-rc1  
Product Scope: Recordkeeping and committee administration tool; no custody or movement of money in MVP.

---

## Architecture Overview

- **Mobile Client (`apps/mobile`):** Flutter (Dart) app using a centralized design-token system, user-switchable Blue and Red themes, Provider state management, and GoRouter navigation.
- **Backend API (`apps/api`):** Modular monolith in Node.js (TypeScript strict mode) with Fastify, versioned REST/JSON under `/api/v1`, and OpenAPI 3.1 specification.
- **Database:** PostgreSQL with append-only ledger entries, versioned SQL migrations (`apps/api/migrations`), and transaction-bound repositories.
- **Financial Integrity:** Strict integer minor units (NPR paisa) everywhere; zero floating-point math.
- **Audit & Idempotency:** Append-only ledger; corrections handled by reversals; write requests require `Idempotency-Key` headers.

---

## Project Structure

```text
├── apps/
│   ├── api/                   # Node.js + TypeScript Modular Monolith
│   │   ├── migrations/        # Versioned PostgreSQL DDL migrations
│   │   ├── openapi/           # OpenAPI 3.1 specification
│   │   ├── src/               # Modules: identity, committees, ledger, reports, etc.
│   │   └── tests/             # Vitest unit and integration test suites
│   └── mobile/                # Flutter (Dart) Mobile Application
│       ├── lib/
│       │   ├── core/          # Theme tokens, money value object, reusable widgets
│       │   ├── features/      # Committees, collections, members, reports, settings
│       │   └── app/           # App root & GoRouter configuration
│       └── test/              # Flutter unit and widget tests
├── docs/                      # Implementation plan, open decisions, and ADRs
│   ├── architecture/adr/      # Architecture Decision Records (ADR 001 - 007)
│   ├── IMPLEMENTATION_PLAN.md
│   ├── OPEN_DECISIONS.md
│   └── IMPLEMENTATION_STATUS.md
├── docker-compose.yml         # Container configuration for PostgreSQL & API
├── .env.example               # Environment variable templates
└── README.md
```

---

## Quickstart & Execution

### 1. Database
```bash
# Start PostgreSQL container
docker compose up postgres -d

# Run versioned migrations
cd apps/api
npm run migrate
```

### 2. Backend API
```bash
cd apps/api
cp ../../.env.example .env
npm install

# Run tests (Vitest)
npm test

# Build TypeScript
npm run build

# Start development server on port 4000
npm run dev
```

### 3. Flutter Mobile Client
```bash
cd apps/mobile
flutter pub get

# Run static analysis
flutter analyze

# Run unit and widget test suite
flutter test

# Run application
flutter run -d chrome     # Web preview
flutter run -d android    # Android device/emulator
```

---

## Key Domain Rules Implemented

1. **Integer Paisa Math**: All monetary amounts are handled as integer paisa (e.g. NPR 1,000.00 = `100000`).
2. **Arrears Lump-Sum Handling (The 26th Scenario)**:
   - When 5 past due dates are missed and a lump sum is paid on the 26th, the actual payment date is recorded as the 26th.
   - The payment is allocated via FIFO to the overdue obligations.
   - Covered obligations transition from Red (`UNPAID_OVERDUE`) to Orange (`PAID_LATE`).
   - Obligations never rewrite historical receipt dates.
3. **Semantic Status Tokens**:
   - Green + Check icon: Fully paid on time (`PAID_ON_TIME`).
   - Orange + Clock icon: Settled late (`PAID_LATE`).
   - Red + Alert icon: Past due with unpaid balance (`UNPAID_OVERDUE`).
   - Neutral Gray + Calendar icon: Not yet due (`UPCOMING`).
   - Violet + Pie icon: Partially paid with visible balance remaining (`PARTIALLY_PAID`).
   - Colors remain permanent semantic tokens across both Blue and Red themes.

---

## Documentation Pack

1. [Product Requirements Document](file:///c:/Users/saavi/Desktop/Dhurmit/product/01-product-requirements.md)
2. [High-Level Design](file:///c:/Users/saavi/Desktop/Dhurmit/architecture/02-high-level-design.md)
3. [Low-Level Design](file:///c:/Users/saavi/Desktop/Dhurmit/architecture/03-low-level-design.md)
4. [Domain Model & Database](file:///c:/Users/saavi/Desktop/Dhurmit/architecture/04-domain-model-and-database.md)
5. [API Contract & OpenAPI](file:///c:/Users/saavi/Desktop/Dhurmit/engineering/05-api-contract.md)
6. [UX/UI & Design System](file:///c:/Users/saavi/Desktop/Dhurmit/design/06-ux-ui-and-design-system.md)
7. [Security & Compliance](file:///c:/Users/saavi/Desktop/Dhurmit/engineering/07-security-privacy-and-compliance.md)
8. [Testing & Quality Plan](file:///c:/Users/saavi/Desktop/Dhurmit/engineering/08-testing-and-quality-plan.md)
9. [DevOps & Release](file:///c:/Users/saavi/Desktop/Dhurmit/delivery/09-devops-observability-and-release.md)
10. [Implementation Roadmap](file:///c:/Users/saavi/Desktop/Dhurmit/delivery/10-implementation-roadmap-and-acceptance.md)
11. [Folder Structure Conventions](file:///c:/Users/saavi/Desktop/Dhurmit/engineering/11-folder-structure-and-conventions.md)
12. [Open Decisions](file:///c:/Users/saavi/Desktop/Dhurmit/docs/OPEN_DECISIONS.md)
13. [Implementation Plan](file:///c:/Users/saavi/Desktop/Dhurmit/docs/IMPLEMENTATION_PLAN.md)
14. [Implementation Status & Verification](file:///c:/Users/saavi/Desktop/Dhurmit/docs/IMPLEMENTATION_STATUS.md)

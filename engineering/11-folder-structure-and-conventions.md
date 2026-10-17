# 11 — Repository Structure and Coding Conventions

## 1. Suggested monorepo

```text
committee-ledger/
├── apps/
│   ├── api/
│   │   ├── src/
│   │   │   ├── app.ts
│   │   │   ├── server.ts
│   │   │   ├── config/
│   │   │   ├── shared/
│   │   │   │   ├── domain/
│   │   │   │   ├── application/
│   │   │   │   ├── infrastructure/
│   │   │   │   └── presentation/
│   │   │   └── modules/
│   │   │       ├── identity/
│   │   │       ├── workspaces/
│   │   │       ├── committees/
│   │   │       ├── members/
│   │   │       ├── schedule/
│   │   │       ├── ledger/
│   │   │       ├── reports/
│   │   │       └── audit/
│   │   ├── tests/
│   │   ├── migrations/
│   │   ├── openapi/
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   └── tsconfig.json
│   └── mobile/
│       ├── lib/
│       │   ├── app/
│       │   │   ├── router/
│       │   │   ├── theme/
│       │   │   ├── localization/
│       │   │   └── bootstrap/
│       │   ├── core/
│       │   │   ├── api/
│       │   │   ├── auth/
│       │   │   ├── errors/
│       │   │   ├── money/
│       │   │   ├── date_time/
│       │   │   └── widgets/
│       │   └── features/
│       │       ├── authentication/
│       │       ├── home/
│       │       ├── committees/
│       │       ├── members/
│       │       ├── calendar/
│       │       ├── collections/
│       │       ├── reports/
│       │       └── settings/
│       ├── test/
│       ├── integration_test/
│       └── pubspec.yaml
├── packages/
│   └── api-contracts/ (optional generated OpenAPI clients/types)
├── docs/
│   ├── product/
│   ├── architecture/
│   ├── engineering/
│   ├── design/
│   └── delivery/
├── infra/
│   ├── docker/
│   ├── deployment/
│   └── scripts/
├── .github/workflows/
├── .env.example
├── README.md
└── CONTRIBUTING.md
```

## 2. Backend module shape

Example `modules/ledger/`:
```text
ledger/
├── domain/
│   ├── entities/
│   ├── value-objects/
│   ├── policies/
│   └── errors/
├── application/
│   ├── use-cases/
│   ├── ports/
│   └── dto/
├── infrastructure/
│   └── postgres/
│       ├── repositories/
│       └── mappers/
└── presentation/
    ├── http/
    │   ├── controllers/
    │   ├── routes.ts
    │   └── schemas/
```

## 3. Naming conventions

- TypeScript: `camelCase` variables/functions, `PascalCase` types/classes, explicit return types for public functions.
- Dart: follow official Dart style; `lowerCamelCase` members, `UpperCamelCase` types.
- Database: `snake_case`, plural table names.
- API JSON: `camelCase`.
- Domain enums use stable uppercase identifiers.
- Avoid abbreviations that hide business meaning.
- Use UTC timestamps and explicit timezone conversions.
- Use integer minor units for money.

## 4. TypeScript rules

- `strict: true`.
- Avoid `any`; use `unknown` at untrusted boundaries and validate it.
- No business logic in controllers.
- No raw SQL concatenation.
- Repositories return domain/application-friendly results, not HTTP responses.
- Do not import infrastructure into domain.
- Centralize transaction handling and error mapping.
- Keep modules independent; use exported application interfaces for cross-module calls.

## 5. Flutter rules

- No API calls directly from build methods.
- No hardcoded hex colors outside token definitions.
- No financial calculations that disagree with server rules.
- All user-visible text goes through localization resources.
- Use typed models and explicit DTO-to-domain mapping.
- Handle loading, empty, error, and retry states.
- Keep widgets small and reusable; do not create a giant single screen file.
- Securely store auth tokens; do not store secrets in ordinary preferences.

## 6. Architecture Decision Records (ADRs)

Create `docs/architecture/adr/` and record:
- ADR-001: HTTP framework and validation library.
- ADR-002: Database access/migration tooling.
- ADR-003: Authentication approach.
- ADR-004: Flutter state management and router.
- ADR-005: Schedule edge-case policies.
- ADR-006: Allocation and partial-payment rules.
- ADR-007: Hosting, backup, and recovery targets.

Each ADR includes context, decision, alternatives, consequences, and date. Do not let the coding agent make a major irreversible choice silently.

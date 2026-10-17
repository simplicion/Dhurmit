# 09 — DevOps, Observability, and Release

## 1. Environments

- `local`: developer machines and local PostgreSQL.
- `test`: CI/integration environment with synthetic data.
- `staging`: production-like environment with no real member data unless explicitly authorized.
- `production`: restricted access and managed secrets.

Never use production credentials in local development. Never copy production financial data into staging.

## 2. Configuration

Use validated environment configuration. Fail startup if required values are missing or invalid.

Example variables:
- `NODE_ENV`
- `PORT`
- `DATABASE_URL`
- `AUTH_ISSUER` / provider configuration
- `ACCESS_TOKEN_TTL` (if first-party auth)
- `LOG_LEVEL`
- `CORS_ALLOWED_ORIGINS` (if applicable)
- `SENTRY_DSN` or equivalent error-monitoring DSN
- `APP_ENV`

Do not commit `.env` files. Provide `.env.example` with fake placeholders only.

## 3. Database migrations

- Versioned migrations committed to source control.
- CI applies migrations to an empty database and upgrades a prior schema snapshot.
- Production migration process must be reviewed and backed up.
- Prefer backward-compatible expand/contract changes.
- Never run automatic destructive schema synchronization on production startup.
- Provide seed data only for local/test.

## 4. CI/CD pipeline

1. Checkout.
2. Install locked dependencies.
3. Formatting/lint/type checking.
4. Unit tests.
5. Integration tests with PostgreSQL.
6. Security/dependency/secret scanning.
7. Validate OpenAPI.
8. Build backend container.
9. Build Flutter target(s) and run analyzer/tests.
10. Deploy to staging.
11. Smoke tests.
12. Manual approval for production release.
13. Run reviewed migrations.
14. Deploy API.
15. Verify health, error rate, latency, and database connectivity.

## 5. Observability

Use structured logs with:
- timestamp
- level
- request ID
- route/operation
- status code
- duration
- actor ID only where appropriate and privacy-safe
- error code

Metrics:
- request rate, latency percentiles, error rate
- database connection pool usage and query latency
- collection write failures/conflicts
- idempotency replays
- schedule generation failures
- background job failures if workers are introduced

Do not log request bodies containing member details or financial records by default.

## 6. Health checks

- `/health/live`: process is alive.
- `/health/ready`: service can serve requests, including required database dependency check.
- Keep health responses free of secrets and internal topology.

## 7. Backup and recovery

- Configure automated encrypted database backups.
- Document retention period after legal review.
- Perform periodic restore tests.
- Record actual restore duration and data loss window.
- Set RPO/RTO based on business requirements, not guesses.
- Have a documented incident path for accidental deletion or corruption.

## 8. Release strategy

- Internal alpha with a small number of consenting test organizers.
- Fix usability and accounting correctness defects before adding features.
- Beta with clear manual-recording disclaimer and support path.
- Public release only after legal review, security acceptance, backup restore validation, and support ownership.
- Use feature flags for incomplete exports, multi-user access, or other optional capabilities.

## 9. Rollback

- API deploys should be reversible.
- Database changes must follow backward-compatible migration patterns.
- Do not roll back by deleting user-entered records.
- If a release causes ledger corruption, disable write operations, preserve logs, investigate, and apply an audited repair plan.

# ADR-007: Hosting, Backups, and Disaster Recovery

## Status
Accepted

## Context
As a financial recordkeeping system, data durability and backup readiness are mandatory gates. While MVP is not a bank, organizers depend on records not being lost, corrupted, or exposed.

## Decision
1. **Containerized Deployment:** Dockerized multi-stage container for the Node.js API (`apps/api/Dockerfile`) and `docker-compose.yml` for local and staging environments with PostgreSQL.
2. **Authoritative Storage:** Managed PostgreSQL with encrypted storage at rest and in transit (TLS/SSL).
3. **Backup Strategy:**
   - Daily automated logical backups via `pg_dump` with gzip compression and AES-256 encryption.
   - Point-in-time recovery (WAL archiving) enabled in production environments.
   - Documented backup restore testing script (`scripts/backup-restore-test.sh`).
4. **Health Endpoints:**
   - `/health/live`: Basic liveness probe.
   - `/health/ready`: Dependency check verifying PostgreSQL pool connectivity.

## Consequences
- Clean separation between ephemeral application compute and persistent PostgreSQL storage.
- Safe rollback procedure documented without destructive data wipes.

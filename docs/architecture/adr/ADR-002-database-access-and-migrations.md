# ADR-002: Database Access and Migration Tooling

## Status
Accepted

## Context
PostgreSQL is the single authoritative source of truth. The application requires strict transactional guarantees, row-level locking (`SELECT ... FOR UPDATE`) during collection allocations to prevent concurrent race conditions, versioned SQL migrations, and exact handling of 64-bit BigInt minor currency units (NPR paisa).

## Decision
1. **Driver & Query Execution:** Direct parameterized PostgreSQL client (`pg` connection pool) with clean Repository patterns, or type-safe SQL query builder (such as Kysely or Knex). Raw SQL concatenation is strictly forbidden.
2. **Data Types:** 
   - Monies stored as `BIGINT` minor units.
   - Due dates stored as `DATE`.
   - Event timestamps stored as `TIMESTAMPTZ` (UTC).
3. **Migration Engine:** Versioned forward SQL migration runner executing numbered `.sql` files with schema verification tracking in a `schema_migrations` table.
4. **Transactions:** Explicit transaction boundary helpers wrapping Application use cases to ensure collections, allocations, audit logs, and idempotency records commit or roll back atomically.

## Alternatives Considered
- *Prisma ORM:* Good DX, but generates complex nested queries, abstracts away fine-grained transactional row locks (`FOR UPDATE`), and can complicate custom database triggers or locking strategies.
- *TypeORM:* Known historical issues with connection pooling and complex migrations in TypeScript.

## Consequences
- Repositories encapsulate all SQL queries behind clean interface contracts.
- Database constraints (foreign keys, check constraints on positive amounts, uniqueness on idempotency keys) act as a secondary defense layer alongside domain rules.

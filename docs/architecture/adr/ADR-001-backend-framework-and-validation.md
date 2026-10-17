# ADR-001: Backend HTTP Framework and Validation Library

## Status
Accepted

## Context
The Committee Ledger requires a robust, modular, and maintainable Node.js backend using TypeScript strict mode. It exposes a versioned REST/JSON API under `/api/v1` and OpenAPI documentation. The framework must support clean layering (Presentation -> Application -> Domain -> Infrastructure), middleware for authentication, correlation IDs, structured logging, centralized error handling, and robust schema validation.

## Decision
1. **HTTP Framework:** Express with TypeScript strict mode (or Fastify). We choose Express for its universal ecosystem compatibility, mature middleware support, simplicity in modular monolith architectures, and zero-fuss test execution via `supertest`.
2. **Schema Validation:** Zod for all request boundary validations (DTOs, path parameters, query strings, and environment variables). Zod provides compile-time TypeScript type inference from runtime schemas.
3. **OpenAPI Documentation:** Generated OpenAPI 3.1 specification declaring all `/api/v1` routes and error schemas.

## Alternatives Considered
- *Fastify:* High performance and built-in schema validation, but Express offers maximum compatibility with mock servers, Supertest integration testing, and straightforward route registration across submodules.
- *NestJS:* Provides heavy opinionated structure, but introduces high boilerplate, decorators, and unnecessary reflection complexity for this modular monolith.

## Consequences
- Controllers remain thin and delegate directly to Application use cases.
- Request parsing and validation are enforced at the HTTP boundary before use cases are invoked.
- All validation failures return a standard `VALIDATION_ERROR` response envelope.

# ADR-003: Authentication Approach and Workspace Authorization

## Status
Accepted

## Context
The Committee Ledger requires secure authentication and strict tenant (workspace) data isolation. Organizers and collectors manage committee data; no user may view or manipulate data belonging to another workspace.

## Decision
1. **Authentication:** First-party password-based authentication with `argon2` or `bcrypt` hashing, returning signed JWT Access Tokens and Refresh Tokens. 
2. **Access Tokens:** Signed with HMAC SHA-256 (`HS256`), containing `userId` and active `workspaceId`.
3. **Workspace Isolation:** 
   - Every request is validated by an authorization middleware that verifies the user has an active membership in the requested workspace.
   - Roles include: `OWNER`, `ADMIN`, `COLLECTOR`, `VIEWER`.
   - All queries filter by `workspace_id`. Cross-workspace ID probing returns `404 Not Found` (never leaking existence).
4. **Member Scope:** In MVP, committee members are records managed by organizers, not authenticated accounts.

## Alternatives Considered
- *Third-party Auth (Firebase/Auth0):* Adds external network dependencies and vendor lock-in for local development and self-contained environments in Nepal.
- *Session cookies:* Mobile clients in Flutter operate more reliably with standard Bearer authorization headers and platform-secure keystore/keychain token storage.

## Consequences
- No plaintext credentials are ever stored.
- Secure token storage implemented in Flutter using encrypted secure storage.

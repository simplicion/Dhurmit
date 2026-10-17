# 07 — Security, Privacy, and Compliance

## 1. Scope and posture

The product records financial information about members. Treat the data as sensitive even though the MVP does not move money. This is not a legal opinion. Obtain Nepal-qualified legal advice before public launch, including on the permitted scope and marketing of software used in connection with Dhukuti/committee activities.

## 2. Authentication and sessions

- Use a mature authentication provider or a carefully reviewed first-party implementation.
- Never store plaintext passwords.
- Use short-lived access tokens and secure refresh-token rotation if token auth is selected.
- Protect token storage on device using platform-secure storage.
- Rate-limit login, registration, password reset, and OTP endpoints.
- Do not expose account existence through recovery messages.
- Support logout/revocation.

## 3. Authorization

- Default deny.
- Roles: `OWNER`, `ADMIN`, `COLLECTOR`, `VIEWER`.
- Define a permission matrix in code and test it.
- Verify committee/workspace scope on every read and write.
- Do not trust `workspaceId`, `committeeId`, or `memberId` sent by client without server-side ownership checks.
- Avoid insecure direct object references (IDOR).
- Do not expose a member's data to other members unless a dedicated, consented member view is implemented.

## 4. Financial record integrity

- Use database transactions for collection plus allocations plus audit event.
- Idempotency for retries.
- Lock rows when concurrent allocation could overspend a due amount.
- Never silently edit or delete financial records.
- Reverse or adjust with reason and actor.
- Show actual received date and due date separately.
- Make manual-record status explicit; an app entry is not bank/payment verification.
- Restrict exports and record access.

## 5. Data protection

- Collect only necessary personal data.
- Avoid storing government IDs, bank details, passwords in notes, or unrelated sensitive details.
- Encrypt traffic with HTTPS.
- Use encrypted managed database storage and encrypted backups.
- Use secrets manager/environment injection.
- Mask phone numbers where full display is unnecessary.
- Establish retention and account deletion rules after legal review.
- Document data export and correction requests.
- Never put personal or financial data in analytics events.

## 6. Application security

- Validate inputs at boundary and domain layers.
- Use parameterized SQL / safe ORM methods.
- Apply request body size limits and rate limiting.
- Configure CORS only for intended origins if a web client exists.
- Secure headers and production error responses.
- Pin and audit dependencies; run vulnerability scans.
- Protect against SQL injection, broken access control, mass assignment, brute force, and sensitive-data exposure.
- Use least-privilege database roles.
- Separate dev/staging/prod credentials.

## 7. Audit logging

Audit events include actor, action, entity, timestamp, reason, and minimal metadata. Never log auth secrets, full tokens, passwords, or unnecessary member financial details. Application audit logs should be append-only; production database permissions should prevent ordinary application code from modifying past audit events.

## 8. Backups and incident response

- Automated encrypted backups.
- Define recovery point objective (RPO) and recovery time objective (RTO) before production; do not invent a promise.
- Test restoration to an isolated environment.
- Document incident severity, containment, credential rotation, user communication, and postmortem.
- Restrict production data access to authorized personnel and log privileged access.

## 9. Legal and marketing gate

Before launch:
1. Obtain a written legal assessment of the intended software-only scope under current Nepal law.
2. Confirm whether any feature or marketing language could be interpreted as organizing, facilitating, collecting, or distributing funds in a prohibited activity.
3. Do not add wallet, escrow, payment gateway, auction, lending, or automatic payout functions without a separate legal and compliance review.
4. Publish accurate terms, privacy notice, support contact, and data handling disclosures.
5. Do not market records as guaranteed proof of payment.

## 10. Security acceptance criteria

- Cross-workspace access tests fail safely.
- Collector cannot edit committee financial rules unless authorized.
- Viewer cannot create collections or export restricted reports.
- Same idempotency key cannot create duplicate collections.
- Reversal does not erase original record.
- No secrets in repository or logs.
- Backup restore test passes before production.

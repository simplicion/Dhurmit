# 05 — API Contract (REST / OpenAPI)

## 1. Conventions

- Base path: `/api/v1`
- Content type: `application/json`
- Authentication: bearer token or documented session mechanism.
- All writes use server-side validation and authorization.
- All financial write endpoints should accept `Idempotency-Key`.
- List endpoints use cursor pagination where practical.
- Dates use ISO 8601; date-only fields use `YYYY-MM-DD`.
- Money fields are integer minor units plus `currencyCode`; UI converts to/from decimal display.
- Errors follow a stable envelope.

Example error:
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The amount must be greater than zero.",
    "details": [{"field": "amountMinor", "issue": "must_be_positive"}],
    "requestId": "..."
  }
}
```

## 2. Endpoint inventory

### Identity
- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`
- `POST /auth/logout`
- `GET /me`

If an external identity provider is chosen, adapt this inventory to its flow and do not duplicate authentication unnecessarily.

### Workspaces
- `GET /workspaces`
- `POST /workspaces`
- `GET /workspaces/{workspaceId}`
- `GET /workspaces/{workspaceId}/memberships`
- `POST /workspaces/{workspaceId}/memberships` (optional staff access)

### Committees
- `GET /committees`
- `POST /committees`
- `GET /committees/{committeeId}`
- `PATCH /committees/{committeeId}` (draft or safe metadata only)
- `POST /committees/{committeeId}/schedule-preview`
- `POST /committees/{committeeId}/activate`
- `POST /committees/{committeeId}/archive`
- `GET /committees/{committeeId}/dashboard`
- `GET /committees/{committeeId}/calendar?month=YYYY-MM`

### Members
- `GET /committees/{committeeId}/members?search=&status=`
- `POST /committees/{committeeId}/members`
- `GET /committees/{committeeId}/members/{memberId}`
- `PATCH /committees/{committeeId}/members/{memberId}`
- `POST /committees/{committeeId}/members/{memberId}/deactivate`
- `GET /committees/{committeeId}/members/{memberId}/statement`

### Obligations
- `GET /committees/{committeeId}/obligations?memberId=&from=&to=&status=`
- `GET /committees/{committeeId}/members/{memberId}/obligations`
- `GET /obligations/{obligationId}`

### Collections and allocations
- `POST /committees/{committeeId}/collections`
- `GET /committees/{committeeId}/collections?from=&to=&memberId=`
- `GET /collections/{collectionId}`
- `POST /collections/{collectionId}/reverse`
- `POST /collections/{collectionId}/allocations` only if allocation is intentionally a separate workflow; prefer atomic collection-plus-allocation in MVP.

### Reports and audit
- `GET /committees/{committeeId}/reports/summary`
- `GET /committees/{committeeId}/reports/overdue`
- `GET /committees/{committeeId}/reports/collections`
- `GET /committees/{committeeId}/audit-events`

## 3. Example request: create committee

```json
{
  "name": "Market Committee A",
  "currencyCode": "NPR",
  "timezone": "Asia/Kathmandu",
  "startDate": "2026-11-01",
  "duration": {"count": 10, "unit": "MONTH"},
  "schedule": {
    "frequency": "MONTHLY",
    "rule": {"dayOfMonth": 26, "monthEndPolicy": "REQUIRES_CONFIRMATION"}
  },
  "contributionAmountMinor": 200000,
  "allowPartialPayment": false,
  "allocationPolicy": "MANUAL"
}
```

`200000` paisa equals NPR 2,000. This example is illustrative; API schema and month-end policy must be finalized.

## 4. Example request: record collection

```json
{
  "memberId": "00000000-0000-4000-8000-000000000001",
  "amountMinor": 1200000,
  "currencyCode": "NPR",
  "receivedAt": "2026-11-26T12:00:00+05:45",
  "methodLabel": "CASH",
  "reference": null,
  "note": "Received in person",
  "allocations": [
    {"obligationId": "00000000-0000-4000-8000-000000000010", "amountMinor": 200000},
    {"obligationId": "00000000-0000-4000-8000-000000000011", "amountMinor": 200000}
  ]
}
```

The sample intentionally allocates only part of the total. The API must reject it if partial/unallocated amounts are not allowed. Never silently invent where the remainder goes.

## 5. Example success response

```json
{
  "data": {
    "collectionId": "00000000-0000-4000-8000-000000000100",
    "amountMinor": 1200000,
    "currencyCode": "NPR",
    "receivedAt": "2026-11-26T06:15:00Z",
    "allocations": [
      {"obligationId": "00000000-0000-4000-8000-000000000010", "amountMinor": 200000},
      {"obligationId": "00000000-0000-4000-8000-000000000011", "amountMinor": 200000}
    ],
    "unallocatedAmountMinor": 800000,
    "updatedObligations": []
  },
  "meta": {"requestId": "..."}
}
```

This is an illustrative shape, not permission to allow unallocated balances. Production schema must reflect the configured policy.

## 6. API requirements

- Validate every path/body/query parameter.
- Return `401` for unauthenticated requests, `403` for unauthorized access, `404` for missing/inaccessible resources where appropriate, `409` for conflicts, `422` or `400` for invalid business input, and `500` only for unexpected failures.
- Never reveal whether a foreign tenant's resource exists.
- Return request IDs for support/debugging.
- Use request size limits and rate limits on auth endpoints.
- Version breaking API changes.
- Generate and validate OpenAPI spec in CI.
- Add contract tests for DTOs and response envelopes.

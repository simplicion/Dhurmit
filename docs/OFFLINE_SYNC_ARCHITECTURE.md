# Offline-First Architecture & Automatic Synchronization Specification

**Document Version:** 1.0.0  
**Target Applications:** `apps/mobile` (Flutter Client) & `apps/api` (PostgreSQL Modular Monolith)  
**Problem Statement:** Organizers in Nepal collect committee contributions in rural and transit areas with intermittent or zero cellular connectivity. Paper notebooks are used because they never fail offline. The digital ledger must offer the same offline resilience.

---

## 1. Core Principles

1. **Local Writes Never Block**: Recording collections, creating committees, and adding members can be performed fully offline without blocking the organizer.
2. **Deterministic Append-Only History**: The actual date and time a payment was received (`received_at`) is captured at the moment of recording on the device in `Asia/Kathmandu` and never rewritten upon later sync.
3. **Idempotent Queue Replay**: Every offline mutation is minted with a client-generated UUID (`idempotency_key`). When the internet reconnects, mutations replay sequentially with their original `Idempotency-Key`. Retries or repeated sync attempts will never create duplicate ledger entries.
4. **Optimistic Local Reflection**: Dues and balances update immediately in the local UI with an amber "Pending Sync" indicator, so the organizer immediately knows the state of their cash collection.
5. **Authoritative Server Convergence**: Once online, server responses provide the definitive ledger state and refresh local caches.

---

## 2. Architecture & Data Flow Diagram

```
+-----------------------------------------------------------------------+
|                         FLUTTER MOBILE CLIENT                         |
|                                                                       |
|  [ User Action: Record Collection ]                                   |
|                 │                                                     |
|                 ▼                                                     |
|  [ Offline Storage & Outbox Queue ]                                   |
|    ├── 1. Persist mutation to SyncOutbox (PENDING)                    |
|    └── 2. Apply optimistic local update to LocalCache                 |
|                 │                                                     |
|                 ▼                                                     |
|  [ Connectivity Monitor (connectivity_plus + health ping) ]           |
|         │                        │                                    |
|     (Offline)                (Online)                                 |
|         │                        │                                    |
|         ▼                        ▼                                    |
|   Show "Offline" banner    [ Sync Engine Auto-Trigger ]               |
|   Queue remains intact           │                                    |
|                                  ├── Process Outbox FIFO              |
|                                  ├── Send POST /api/v1/...            |
|                                  │   with Idempotency-Key             |
|                                  └── On Success: Mark SYNCED          |
|                                            │                          |
+--------------------------------------------┼--------------------------+
                                             │ HTTP (TLS)
                                             ▼
+-----------------------------------------------------------------------+
|                          NODE.JS POSTGRES API                         |
|                                                                       |
|  1. Verify Idempotency Record (check if requestHash already processed)|
|  2. If fresh: execute ledger transaction, write audit event           |
|  3. Store response in `idempotency_records` table                     |
|  4. Return 201 Created with authoritative collection & allocation data|
+-----------------------------------------------------------------------+
```

---

## 3. Data Structures & Entities

### `SyncOutboxItem`
- `id`: Client UUID.
- `mutationType`: `RECORD_COLLECTION` | `CREATE_COMMITTEE` | `ADD_MEMBER` | `REVERSE_COLLECTION`.
- `endpoint`: API path (e.g. `/committees/{id}/collections`).
- `method`: `POST` | `PATCH` | `DELETE`.
- `payload`: JSON object with request body.
- `idempotencyKey`: Unique client UUID sent in `Idempotency-Key` header.
- `createdAt`: ISO 8601 timestamp in UTC.
- `retryCount`: Integer.
- `status`: `PENDING` | `SYNCING` | `SYNCED` | `FAILED`.
- `lastError`: Error message if last sync attempt failed.

### `OfflineCacheStore`
- Cached committee lists, committee details, member rosters, obligation calendars, and member statements.
- Key format: `cache_{entity}_{id}` with versioning and last-synced timestamp.

---

## 4. Conflict Resolution Strategy

- **Ledger Entries (Collections & Allocations)**: Strictly **append-only**. Because payments are additive ledger credits against obligations with FIFO allocation, concurrent collections from the same organizer apply in the order recorded (`createdAt`).
- **Idempotency Guard**: If the mobile client drops connection after the backend commits but before receiving the HTTP 201 response, the next sync retry resends the identical `Idempotency-Key`. The backend detects the existing record and returns the cached 201 without creating duplicate ledger records.
- **Deactivations & Reversals**: Reversals are also append-only adjustments referencing the original collection ID.

---

## 5. UI Status Signals

- **Sync Status Banner**:
  - `Offline`: Amber banner with cloud-off icon: *"Working offline — 3 collections queued for sync."*
  - `Syncing`: Blue banner with animated sync icon: *"Syncing 3 items..."*
  - `Synced`: Green banner: *"All changes up to date."*
- **Badge Indicators**:
  - Unsynced collections have an amber badge: `Pending Sync` alongside the receipt.
  - Manual "Sync Now" button in app bar and Settings.

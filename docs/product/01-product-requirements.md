# 01 — Product Requirements Document (PRD)

## 1. Product summary

**Working name:** Committee Ledger  
**Purpose:** Replace paper notebooks and manual calculations used by local committee organizers with a simple, transparent digital recordkeeping tool.

The product helps an organizer configure a committee, add members, define contribution schedules, record amounts received against due dates, identify late and unpaid obligations, and view member-wise outstanding balances.

## 2. Problem statement

Today, organizers often track members, dates, collections, and outstanding amounts in paper diaries. This creates predictable failure modes:
- A diary can be lost, damaged, or unavailable.
- It is difficult to calculate arrears after several missed due dates.
- A lump-sum payment may be incorrectly recorded as one payment without specifying which due obligations it covers.
- Organizers and members may disagree about what was paid, when it was received, or what remains outstanding.
- There may be no consistent receipt or audit trail for edits.

The app's job is to make records clearer and calculations repeatable. It does not guarantee that money was actually transferred.

## 3. Goals

1. Allow an organizer to create and manage multiple committees.
2. Configure committee duration, contribution amount/frequency, calendar rules, member count, and timezone.
3. Add, edit, deactivate, and search members with permission controls.
4. Record a collection on the actual date it was received.
5. Allocate one collection to one or more due obligations, including arrears.
6. Display due-date statuses: green = paid on time; orange = paid late; red = unpaid/overdue; neutral = not yet due or no obligation.
7. Provide member-wise dues, date-wise collection history, committee summaries, and exportable reports.
8. Make the app usable by non-technical local businesspeople with clear labels, large touch targets, and minimal steps.
9. Support a centralized Blue/Red theme switcher without duplicating components.
10. Maintain accurate, auditable records with server-side validation and tenant isolation.

## 4. Non-goals for MVP

- Holding, receiving, transferring, or safeguarding money.
- Wallet, escrow, bank account, payment gateway, automatic payout, lending, or credit scoring.
- Running or brokering an auction/bidding mechanism.
- Guaranteeing member solvency or repayment.
- Public member discovery, social feeds, or marketplace functionality.
- Complex accounting/tax filing.
- Offline multi-device synchronization unless explicitly added after the online MVP is validated.
- OCR of paper diaries in MVP.

## 5. Personas

### Organizer / owner
Creates committees, configures rules, adds members, records collections, corrects mistakes through adjustment flows, and reviews reports.

### Collector / staff member
Can record collections for assigned committees, but cannot change committee configuration, export all data, or manage owner access unless explicitly granted.

### Member (optional read-only access, later phase)
May view only their own statement if a secure member portal is approved. MVP may treat members as records without app accounts.

## 6. Core terminology

- **Committee:** A configured recordkeeping group with a fixed schedule and a roster of members.
- **Member:** A person listed in a committee.
- **Contribution obligation / due:** An expected amount for a member for a specific due date or period.
- **Collection:** A real-world amount reported as received by an organizer/collector on a particular received date.
- **Allocation:** The part of a collection applied to one or more due obligations.
- **Arrears:** Unpaid amount associated with due obligations whose due dates have passed.
- **Unallocated amount:** Amount recorded as received but not assigned to a due obligation. This must be shown clearly and must not silently reduce arrears.
- **Adjustment / reversal:** An auditable correction that references the original record.
- **Status color:** A derived presentation state, not the source of truth.

## 7. Main user journeys

### Journey A — Create a committee
1. User signs in.
2. Selects **Create committee**.
3. Enters committee name, currency (NPR default; configurable only if supported), start date, duration, contribution frequency, contribution amount, schedule/calendar rule, timezone, and rounding/partial-payment policy.
4. Adds members manually or from the user's own member directory.
5. Reviews a generated schedule preview showing the number of due obligations and expected amounts.
6. Confirms and creates the committee.
7. System stores a versioned configuration and generates due obligations.

### Journey B — Record a normal collection
1. Open committee.
2. Open **Record collection** bottom sheet.
3. Search/select member.
4. Select actual received date (today by default).
5. Enter amount received and optional note/reference.
6. App shows open due obligations and proposes allocation according to the configured allocation policy.
7. User reviews which due dates will be covered.
8. Confirm.
9. Backend records the collection and allocation(s) atomically.
10. Calendar and outstanding balances refresh from server response.

### Journey C — Record arrears as a lump sum
Example: A member missed five due dates and pays NPR 12,000 on the 26th.
1. Select member and actual received date = 26th.
2. Enter NPR 12,000.
3. System displays overdue obligations, each with its due date and remaining amount.
4. Default allocation policy is **oldest due first** only if the organizer explicitly accepts this policy during setup; otherwise require manual allocation.
5. Preview states: “This collection will cover these five earlier dues and/or part of the current due.” Show exact amounts.
6. User confirms.
7. Each covered old due becomes **Paid late** (orange); the actual collection remains recorded on the 26th.
8. Any partially covered due remains **Partially paid** with its remaining amount; any unpaid overdue due remains red.
9. A receipt/history item shows “Received on the 26th; allocated to due dates …”. Never rewrite the historical received date to make the past due date appear as the collection date.

### Journey D — Review unpaid dues
1. Open committee dashboard.
2. View outstanding total and list of members with dues.
3. Filter by overdue, partially paid, not yet due, or paid late.
4. Open a member to see due-date calendar and ledger.
5. Export or share a statement only if the user has permission.

### Journey E — Correct a mistaken entry
1. Open a collection.
2. Choose **Reverse/correct**.
3. Enter reason.
4. System records reversal/adjustment linked to original transaction.
5. Balances and statuses recalculate.
6. Original entry remains visible in audit history.

## 8. Functional requirements

### FR-01 Authentication
- Secure sign-up/sign-in and sign-out.
- Use a proven authentication mechanism; never store plaintext passwords.
- Access and refresh token handling must be documented.
- Account recovery must not reveal whether arbitrary emails/phone numbers exist.

### FR-02 User and workspace isolation
- A user can only access committees they own or have been explicitly assigned to.
- All data queries must include an authorized tenant/workspace scope.
- Cross-tenant identifiers must not expose data.

### FR-03 Committee configuration
Required fields:
- Name
- Start date
- Duration: count and unit (days/months), or explicit end date
- Contribution frequency: daily, weekly, monthly, or custom scheduled dates
- Amount per obligation
- Schedule generation rule
- Timezone (default Asia/Kathmandu)
- Member roster
- Partial-payment policy
- Allocation policy for lump-sum collections
- Status: draft, active, completed, archived

Configuration changes after obligations exist must not silently rewrite history. Require a preview and an explicit “apply to future dues only” or a documented migration process. **Open decision:** whether changes to past obligations are ever permitted.

### FR-04 Calendar and schedule
- Generate due dates deterministically from committee configuration.
- Support a configurable number of contribution days per month only through a clear schedule rule, not a vague integer alone.
- Monthly schedules must define what happens when a chosen day does not exist in a month (e.g., day 31 in February): clamp to last day, skip, or custom date. **Open decision:** default rule must be approved.
- Daily schedules must define weekends/holidays behavior if relevant. **Open decision:** default is every calendar day until product owner confirms otherwise.
- Show future dues as neutral, paid on time as green, paid late as orange, and overdue unpaid as red.
- A due date with a partial allocation must show partial status and remaining amount; use a non-color indicator/icon as well for accessibility.

### FR-05 Member management
- Add name and optional phone/contact/reference.
- Prevent accidental duplicate members within the same committee using a warning, not a hard rule based solely on name.
- Support member search and status filters.
- Removing a member with financial history must mean deactivate/archive, not destructive deletion.
- Store optional notes carefully; discourage sensitive personal data.

### FR-06 Collection recording
- Collection fields: committee, member, amount in minor units, actual received date/time, payment method label (cash/other/manual note; no integrated payment in MVP), optional reference, notes, created by, created at.
- Allow one collection to cover multiple due obligations.
- Allow multiple collections to cover one obligation.
- Partial payments are supported only if enabled in committee settings.
- Amount must be positive; zero/negative collections are rejected.
- Allocation total cannot exceed collection amount.
- The total amount allocated plus any explicitly unallocated remainder must equal the collection amount.
- Server transaction must atomically create collection, allocations, audit event, and updated derived balances.
- Use idempotency key or equivalent duplicate prevention for retries.

### FR-07 Due statuses
For each obligation:
- `UPCOMING`: due date is in the future and no payment is allocated.
- `UNPAID_OVERDUE`: due date has passed and outstanding amount > 0.
- `PARTIALLY_PAID`: some amount allocated but outstanding amount > 0; UI may add overdue/upcoming qualifier.
- `PAID_ON_TIME`: fully covered by allocations received on or before due date.
- `PAID_LATE`: fully covered but at least part of the amount was received after due date.
- `CANCELLED/WAIVED`: only through authorized, audited action if this capability is approved.

Do not determine status solely from the latest collection. Calculate it from the due amount, active allocations, due date, and actual collection timestamps/dates.

### FR-08 Reports
- Committee overview: members, expected amounts, recorded collections, outstanding dues, overdue members.
- Member statement: each due date, due amount, amounts allocated, actual received dates, remaining amount.
- Collection register: date, member, amount, collector, allocation summary.
- Export CSV/PDF only after permissions and privacy controls are in place.
- Reports must show the “as of” date and clarify that data is manually recorded.

### FR-09 Audit history
Record actor, action, entity, timestamp, reason where required, and before/after diff for non-financial metadata. Financial corrections must use reversal/adjustment records.
- Audit records are append-only at the application layer.
- Do not log passwords, tokens, or unnecessary personal information.

### FR-10 Theme
- Theme selector: Blue or Red.
- Centralized semantic tokens; components must not hardcode hex colors.
- Persist preference locally and optionally to user profile when signed in.
- Maintain contrast and legibility in both themes.
- Theme changes must not alter status semantics: paid-on-time remains green, overdue remains red, late-paid remains orange in both themes. Use icons/labels in addition to color.

## 9. Business rules and calculations

- All financial values are stored as integer minor units (NPR paisa).
- Use `amount_due_minor`, `amount_allocated_minor`, and `amount_outstanding_minor`.
- `outstanding = max(due - active_allocations, 0)`, subject to audited adjustments.
- An allocation must belong to a collection and a due obligation for the same member and committee.
- A collection must not be allocated across members or committees.
- Overpayment behavior: block by default; allow explicit unallocated credit only if product owner approves. Do not silently carry it forward.
- Default allocation order: oldest overdue due first is a proposed default, not final until confirmed by the organizer and legal/product review.
- Never treat “not entered” as proof that no cash was received; it means the app has no record of a collection.

## 10. Non-functional requirements

- Mobile-first UX; Android is the initial validation target; maintain iOS compatibility.
- Common read operations target p95 under 500 ms at expected MVP load, excluding network latency.
- Collection writes target p95 under 800 ms at expected MVP load, excluding network latency.
- API availability target and scale are **Open decisions**; do not claim an SLA before deployment design.
- Strong data integrity and tenant isolation take priority over premature microservices.
- Accessible text contrast, scalable text, and touch targets of approximately 44–48 logical pixels.
- Localization-ready strings; English and Nepali are candidates for MVP, but exact translation scope is an **Open decision**.
- Graceful error states and retry-safe writes.
- Backup and restore process must be tested before production.

## 11. Success metrics

- Time required to record one collection.
- Percentage of active committees with complete configuration.
- Number of collection entries with allocations and no unexplained remainder.
- Frequency of correction/reversal events.
- Number of active organizers retained after 4 weeks.
- Willingness-to-pay conversion among interviewed organizers.
- Support incidents caused by confusing due status or incorrect allocation.

## 12. Open decisions to resolve before implementation

1. Product name and supported languages.
2. Whether contribution schedules are daily, monthly, or fully custom for initial release.
3. Monthly day 29/30/31 behavior and leap-year behavior.
4. Whether partial payments and unallocated credits are allowed.
5. Whether allocation is oldest-due-first by default or always manual.
6. Whether members get their own login or are organizer-managed records only.
7. Whether multiple organizers/staff can access a committee.
8. Whether the app supports exports in MVP.
9. Whether users can edit a committee schedule after it becomes active.
10. Current legal review and permitted marketing scope in Nepal.

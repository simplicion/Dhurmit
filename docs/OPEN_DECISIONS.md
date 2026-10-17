# Open Decisions Log — Committee Ledger

This document tracks unresolved product, legal, architecture, and UX decisions as identified across the specification pack. In accordance with the project rules, decisions are never silently fabricated in implementation code.

---

## OD-01: Monthly Schedule Day-of-Month Clamping Policy (Days 29, 30, 31)
- **Context:** If a monthly committee is configured with a contribution due date on the 29th, 30th, or 31st of the month, February (and 30-day months for day 31) does not contain that day.
- **Options:**
  1. *Clamp to last day of the month* (e.g., Feb 28 or Feb 29 in a leap year).
  2. *Skip the month* (rarely desirable for monthly committees).
  3. *Roll over to the 1st of the following month*.
- **Current Technical Default for Preview:** Clamping to the last calendar day of the month with explicit UI notification in schedule preview.
- **Status:** PENDING PRODUCT OWNER CONFIRMATION.

---

## OD-02: Daily Schedule Weekend and Holiday Handling
- **Context:** Local daily committees may operate 7 days a week, 6 days a week (excluding Saturday in Nepal), or on gazetted holidays.
- **Options:**
  1. Every calendar day (7 days/week).
  2. Skip Saturday (official weekly rest day in Nepal).
  3. Custom selectable days of the week.
- **Current Technical Default for Preview:** Every calendar day unless a day-of-week rule is configured.
- **Status:** PENDING PRODUCT OWNER CONFIRMATION.

---

## OD-03: Past Obligation Immutability upon Committee Configuration Edits
- **Context:** An organizer may want to alter contribution amounts, frequency, or schedule rule after obligations exist.
- **Specification Rule:** Past obligations and completed/partial collections must never be silently rewritten.
- **Options:**
  1. Disallow changing financial parameters once activated (archive and create new committee).
  2. Allow changing future obligations only from an effective date forward, creating a new `committee_config_version`.
- **Current Technical Default:** Option 2 (apply strictly to future due dates with mandatory preview).
- **Status:** PENDING PRODUCT OWNER CONFIRMATION.

---

## OD-04: Default Allocation Policy for Arrears and Lump Sums
- **Context:** When a lump sum is recorded against multiple overdue obligations (e.g. 5 missed dues settled on the 26th).
- **Options:**
  1. *Oldest-due-first (FIFO)* automatically applied with organizer preview and approval.
  2. *Strict manual allocation* where the organizer must specify the amount per due obligation.
- **Current Technical Default:** Committee-level setting with default to FIFO allocation subject to explicit user review and confirmation before submission. Ambiguous cases block and require manual input.
- **Status:** PENDING PRODUCT OWNER CONFIRMATION.

---

## OD-05: Overpayment and Unallocated Credit Handling
- **Context:** A member hands the organizer an amount exceeding all open dues.
- **Options:**
  1. Block overpayment with an error (`OVERPAYMENT_NOT_ALLOWED`).
  2. Allow an explicitly recorded `unallocated_amount_minor` attached to the collection that does not silently reduce future/uncreated dues until allocated.
- **Current Technical Default:** Block overpayment by default; allow unallocated remainder only if committee setting `allow_unallocated_credit` is explicitly set to true.
- **Status:** PENDING PRODUCT OWNER CONFIRMATION.

---

## OD-06: Member Authentication and Portal Scope in MVP
- **Context:** Whether members need accounts/passwords to log in and view statements.
- **Options:**
  1. Members are organizer-managed records only in MVP (no member app login).
  2. Read-only member portal via magic link or phone OTP.
- **Current Technical Default:** Option 1 (records managed by organizer/staff only).
- **Status:** PENDING PRODUCT OWNER CONFIRMATION.

---

## OD-07: Calendar System (Bikram Sambat vs Gregorian)
- **Context:** Many local committees in Nepal operate according to the Bikram Sambat (BS) calendar rather than the Gregorian (AD) calendar.
- **Options:**
  1. Gregorian dates stored internally; dual AD/BS display in presentation layer.
  2. Pure Gregorian in MVP with BS introduced in Phase 2.
- **Current Technical Default:** Gregorian `DATE` (ISO 8601) in database with timezone `Asia/Kathmandu`. Nepali calendar mapping isolated in UI utility boundary.
- **Status:** PENDING PRODUCT OWNER CONFIRMATION.

---

## OD-08: Export Formats and Distribution Permissions
- **Context:** Generating CSV or PDF reports of member statements and collection registers.
- **Options:**
  1. On-device CSV generation for authorized roles only.
  2. Server-side PDF export with signed temporary download URLs.
- **Current Technical Default:** In-app tabular reporting; exports gated behind role permissions and privacy sanitization.
- **Status:** PENDING PRODUCT OWNER CONFIRMATION.

---

## OD-09: Legal Review Gate in Nepal
- **Context:** Nepal Rastra Bank (NRB) regulations and civil code considerations regarding informal fund collection, chit funds/Dhukuti, and digital recordkeeping.
- **Mandatory Position:** The application is exclusively a non-custodial recordkeeping and transparency tool. It must never handle funds, hold balances, provide credit scoring, run auctions, or act as an escrow/wallet.
- **Status:** PRE-LAUNCH LEGAL GATE REQUIRED BEFORE PUBLIC ROLLOUT.

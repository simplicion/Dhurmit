# ADR-005: Schedule Generation, Edge-Case Policies, and Immutability

## Status
Accepted

## Context
Committees generate due obligations across Daily, Weekly, and Monthly frequencies. Edge cases occur when a monthly due date falls on the 29th, 30th, or 31st (e.g., February), during leap years, and when organizers edit configurations after obligations exist.

## Decision
1. **Deterministic Generator:** Obligation due dates are generated deterministically based on `start_date`, `duration_count`, `duration_unit`, and `schedule_rule`.
2. **Month-End Policy (Days 29, 30, 31):** Clamping policy (`CLAMP_TO_LAST_DAY`) is adopted as the deterministic default. When a month lacks day 31 (e.g. April 30, February 28/29), the due date is clamped to the last valid day of that calendar month. The preview explicitly renders this to the organizer prior to activation.
3. **Leap Years:** Properly evaluated using calendar date math (February has 29 days in leap years, 28 otherwise).
4. **Timezone:** Dates are generated and stored as date-only (`YYYY-MM-DD`) anchored to the committee timezone (`Asia/Kathmandu`). Changing device timezone does not distort historical due dates.
5. **Configuration Immutability:** Once a committee is activated, past obligations and historical records are strictly immutable. Configuration changes create a new `committee_config_version` and only apply to future dues.

## Alternatives Considered
- *Skipping non-existent days:* Skipping February would disrupt the monthly financial cadence and lead to missing contributions.
- *Rolling over to 1st of next month:* Creates two payments in the subsequent month, confusing organizers.

## Consequences
- Schedule generation is strictly reproducible and idempotent.
- Duplicate generation calls for the same committee and schedule version do not insert duplicate obligations.

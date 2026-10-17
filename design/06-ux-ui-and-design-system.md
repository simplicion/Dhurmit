# 06 — UX/UI and Centralized Design System

## 1. Product UX principles

- Optimize for fast, repeated use by a busy local organizer.
- One primary action per screen.
- Large touch targets and readable amounts.
- Use plain language, not accounting jargon.
- Show actual received date separately from due date.
- Never use color as the only signal.
- Make financial effects visible before confirming.
- Keep destructive/corrective actions explicit and auditable.

## 2. Main navigation

Suggested bottom navigation:
1. **Home** — active committees, overdue total, recent collections, quick actions.
2. **Committees** — search, create, active/archived filters.
3. **Activity** — collection history and corrections.
4. **Reports** — outstanding and member statements.
5. **Settings** — profile, language, theme, access, help.

A committee detail page contains:
- Overview summary
- Members
- Calendar
- Collections
- Reports/settings

## 3. Required screens

1. Splash/loading
2. Sign in / registration
3. Home dashboard
4. Committee list
5. Create committee wizard
6. Schedule preview and validation
7. Committee dashboard
8. Member list with search/filter
9. Add/edit member
10. Member profile/statement
11. Contribution calendar
12. Record collection bottom sheet
13. Allocation preview and confirmation
14. Collection receipt/detail
15. Reverse/correct collection flow
16. Outstanding/overdue list
17. Collection register
18. Report export preview
19. Workspace/team permissions (if multi-user enabled)
20. Settings and theme selector
21. Empty, loading, offline/network error, permission denied, and server error states

## 4. Record collection bottom sheet

Fields:
- Searchable member selector.
- Actual received date; defaults to today in `Asia/Kathmandu`.
- Amount received.
- Optional method label/reference/note.
- Open obligations list with due date, original amount, already paid, remaining.
- Allocation controls or a preview using the configured policy.
- Clear summary: total received, allocated amount, remaining/unallocated amount.
- Confirm button disabled until valid.

Behavior:
- The calendar date selected for receipt is the actual receipt date, not the historical due date.
- A lump sum may settle multiple older due dates.
- Show the exact allocation before save.
- If the policy requires manual allocation, do not silently allocate.
- On success, show a receipt reference and updated statuses.
- On timeout, retry with the same idempotency key.

## 5. Calendar status design

- Green + check icon + “Paid on time”
- Orange + clock/late icon + “Paid late”
- Red + warning icon + “Overdue / unpaid”
- Neutral gray + calendar icon + “Upcoming”
- Partial state: a distinct partial-payment icon/label and visible remaining amount; use an accessible combination, not color alone.

Do not color an old due date green merely because the user entered money today. It should be orange if the obligation was settled after its due date. If still outstanding, it remains red.

## 6. Centralized theme architecture

Use semantic tokens. Components must consume semantic roles, never direct hex values.

Example token model:
```dart
enum AppThemeMode { blue, red }

class AppColorTokens {
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color surface;
  final Color onSurface;
  final Color surfaceVariant;
  final Color outline;
  final Color success;
  final Color warning;
  final Color error;
  final Color disabled;
  // ...
}

ThemeData buildAppTheme(AppColorTokens tokens) { /* central mapping */ }
```

Define `blueTokens` and `redTokens` in one location. Keep status colors semantically stable across both themes:
- `success` = green
- `warning` = orange
- `error` = red
- `neutral` = gray

The Red theme's primary accent must not override the semantic error color. A red primary brand accent and a red overdue status are distinct semantic roles; add icon/text labels and backgrounds to prevent confusion.

## 7. Component library

Build reusable widgets:
- `AppScaffold`
- `AppAppBar`
- `PrimaryButton`, `SecondaryButton`, `DestructiveButton`
- `AppTextField`, `MoneyInputField`, `DatePickerField`
- `SearchableMemberPicker`
- `StatusChip`
- `MoneySummaryCard`
- `CommitteeCard`
- `MemberListTile`
- `DueCalendarCell`
- `CollectionBottomSheet`
- `AllocationPreview`
- `EmptyState`, `ErrorState`, `LoadingState`
- `ConfirmActionDialog`
- `AppSnackBar`
- `ThemePreviewTile`

All components must use shared spacing, typography, radii, elevation, icon sizing, and color tokens.

## 8. Typography, spacing, and accessibility

- Use a centralized type scale and spacing scale.
- Support system text scaling.
- Minimum practical tap target: 44–48 logical pixels.
- Verify contrast for text, icons, and status states in both themes.
- Never communicate payment status by color alone.
- Provide labels for screen readers.
- Ensure currency input is locale-aware but stored as integer minor units.
- Use localized strings; no user-facing strings hardcoded inside business logic.

## 9. Theme preference persistence

- Apply theme immediately when switched.
- Persist local preference for startup behavior.
- If server profile preference is implemented, define conflict precedence (local last selection vs server preference).
- Theme switch must not require restart.
- Add widget tests for both themes and status semantics.

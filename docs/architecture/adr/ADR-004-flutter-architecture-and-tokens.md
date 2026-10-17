# ADR-004: Flutter State Management, Router, and Centralized Design Tokens

## Status
Accepted

## Context
The Flutter mobile client must support smooth navigation, live theme switching between user-selectable Blue and Red themes, centralized semantic color tokens, responsive form validation, accessible touch targets, and strict separation between presentation widgets and domain rules.

## Decision
1. **Routing:** `go_router` for declarative routing, deep linking, and route guard authentication checks.
2. **State Management:** Provider / ChangeNotifier or lightweight reactive state controllers. Business logic and status derivations remain strictly on the server or in dedicated pure domain calculators; widgets do not perform financial math.
3. **Design Tokens:** Centralized `AppColorTokens` abstract class with concrete `BlueAppColorTokens` and `RedAppColorTokens`.
   - Semantic status tokens: `paidOnTime` (Green), `paidLate` (Orange), `unpaidOverdue` (Red), `upcoming` (Neutral Gray), `partiallyPaid` (Distinct badge/icon with remaining amount).
   - In the Red theme, the primary brand color uses a distinct garnet/crimson shade with clear icon and label separation so as not to be confused with the error/overdue red token.
   - Live theme switching persists preference in local storage and updates `ThemeData` instantly without requiring app restart.

## Alternatives Considered
- *Hardcoded hex values:* Strictly forbidden by specification.
- *Bloc/Redux:* Heavy boilerplate for an MVP where pure services and clean view models provide better maintainability and clarity.

## Consequences
- Every screen and reusable component consumes tokens via `Theme.of(context)` or custom semantic extensions.
- Both themes are systematically tested in widget tests.

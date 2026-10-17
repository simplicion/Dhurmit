# Production Readiness Checklist & Google Play Store Submission Guide

**Application Name:** Committee Ledger (Dhurmit)  
**Package / Application ID:** `app.dhurmit.com`  
**Version:** `1.0.0` (Build Version Code: `1`)  
**Target Platform:** Android (Google Play Store) & Web  
**Legal Framework:** Pure software recordkeeping tool; zero financial custody, escrow, or money transmission.

---

## 1. Production Readiness Checklist

### A. Code & Data Integrity
- [x] **Zero Mock Data:** All mock, dummy, placeholder data and hardcoded records purged from production application paths.
- [x] **Zero Floating-Point Financials:** 100% of financial arithmetic uses integer minor units (NPR Paisa) across Flutter (`AppMoney`) and PostgreSQL (`bigint`).
- [x] **Clean Static Analysis:** `flutter analyze` returns `0 issues` (strict rules, lints, typing).
- [x] **TypeScript Strictness:** `tsc -p tsconfig.json` compiles with `0 errors`.
- [x] **Full Test Suite:** 142 automated tests passing across backend domain, integration, and Flutter widgets/flows.

### B. Live Server & Network Configuration
- [x] **Live HTTPS Endpoint:** Release builds default to production HTTPS endpoint (`https://api.dhurmit.app/api/v1`).
- [x] **Configurable `--dart-define`:** Supports custom staging or on-premise URLs via `--dart-define=API_URL=https://...`.
- [x] **Android Network Permissions:** `android.permission.INTERNET` and `android.permission.ACCESS_NETWORK_STATE` declared in `AndroidManifest.xml`.
- [x] **Offline Synchronization:** Persistent outbox queue with `SharedPreferences`, automatic retry on reconnection via `connectivity_plus`, and SHA-256 idempotency key caching.

### C. Security & Authentication
- [x] **Strict Authentication:** JWT access & refresh tokens with secure storage.
- [x] **Idempotency Protection:** All mutating endpoints require `Idempotency-Key` headers to prevent duplicate debit/credit records upon network retry.
- [x] **Append-Only Auditing:** Immutable ledger entries; corrections only via linked reversal records with mandatory audit reasons.
- [x] **Boundary Enforcement:** Roster and committee membership bounds strictly validated before collection allocations.

---

## 2. Google Play Store Listing Metadata

### App Title (Max 30 characters)
```text
Committee Ledger - Dhurmit
```

### Short Description (Max 80 characters)
```text
Digital committee contribution recordkeeping & audit ledger for organizers.
```

### Full Description (Max 4,000 characters)
```text
Committee Ledger by Dhurmit is a specialized, mobile-first recordkeeping application built for organizers, community groups, and rotating savings/dhukuti coordinators who need to replace vulnerable paper notebooks with an audit-proof digital ledger.

KEY FEATURES FOR ORGANIZERS:

1. COMPLETE COMMITTEE MANAGEMENT
- Create and organize daily, weekly, monthly, or custom committee schedules.
- Automatic month-end date clamping (safely handles Feb 28/29, Apr 30, and leap years).
- Maintain comprehensive member rosters with contact details and active/inactive status.

2. OFFLINE-FIRST ARCHITECTURE
- Record collections, verify dues, and manage members anywhere—even without cellular or Wi-Fi connectivity.
- Offline mutations are securely stored in a persistent local queue.
- Automatic synchronization: all queued records sync automatically with zero duplicate records as soon as internet connectivity returns.

3. ACCURATE ARREARS & LUMP-SUM ALLOCATION
- Smart FIFO Allocation: When members pay missed dues in a lump sum, the app accurately allocates payments to the oldest overdue obligations first while preserving the exact payment receipt date.
- Clear distinction between "Paid On Time" and "Paid Late", eliminating confusion and notebook disputes.

4. REAL-TIME AUDIT & TRANSPARENCY
- Append-only digital ledger: every collection and allocation is logged with timestamps.
- Zero floating-point drift: all monetary values are computed in exact integer paisa minor units.
- Instant financial reports: view total expected, total collected, overdue arrears, and individual member statements.

5. ACCESSIBLE & TAILORED DESIGN
- Switchable Blue and Red themes with high-contrast readability.
- Clear semantic status tokens: Green (Paid On Time), Orange (Paid Late), Red (Overdue), Violet (Partial), and Gray (Upcoming).

IMPORTANT NOTICE & OPERATIONAL BOUNDARIES:
Committee Ledger is exclusively an administrative software recordkeeping tool. It does NOT process payments, hold deposits, provide escrow services, offer credit, or custody user funds. All financial settlement and money movement happens directly and independently between committee organizers and members outside of the software.
```

### Categorization & Tags
- **Application Category:** Business / Productivity
- **Content Rating:** PEGI 3 / Everyone
- **Tags / Keywords:** `Committee`, `Ledger`, `Recordkeeping`, `Organizer`, `Community Contributions`, `Dues Tracker`, `Offline Ledger`

---

## 3. Data Safety & Privacy Declarations

When completing the Google Play Console **Data Safety Form**, declare the following:

| Question | Value / Declaration |
| :--- | :--- |
| **Does your app collect or share user data?** | Yes (collected for core app functionality) |
| **Is all user data encrypted in transit?** | **Yes** (HTTPS TLS 1.3 enforced for all live API traffic) |
| **Can users request data deletion?** | **Yes** (Account deletion and workspace member anonymization) |

### Specific Data Types Collected:
1. **Personal Info:**
   - **Name:** Used for organizer workspace account and committee member identification.
   - **Email Address:** Used for organizer login and authentication.
   - **Phone Number (Optional):** Used for member roster communication by the organizer.
2. **Financial Information:**
   - **User Payment/Contribution Records:** Recorded manually by organizers for ledger bookkeeping only (no credit card, bank account, or CVV data is ever collected or processed).
3. **App Info & Performance:**
   - **Crash Logs / Diagnostics:** Used to improve app stability and resolve sync issues.

---

## 4. Release Build Commands & Artifact Output Paths

### 1. Build Production Android App Bundle (AAB for Google Play Console)
```bash
cd apps/mobile
flutter build appbundle --release --dart-define=API_URL=https://api.dhurmit.app/api/v1
```
- **Output Artifact:** `apps/mobile/build/app/outputs/bundle/release/app-release.aab`
- **Use Case:** Upload directly to Google Play Console under **Production > Releases**.

### 2. Build Production Universal APK (For Internal QA & Device Sideloading)
```bash
cd apps/mobile
flutter build apk --release --dart-define=API_URL=https://api.dhurmit.app/api/v1
```
- **Output Artifact:** `apps/mobile/build/app/outputs/flutter-apk/app-release.apk`
- **Use Case:** Direct installation on physical Android devices for testing.

---

## 5. Production Keystore Setup (Google Play App Signing)

To generate a dedicated release keystore for your organization:

```bash
keytool -genkey -v -keystore android/app/release-keystore.jks -alias dhurmit-key -keyalg RSA -keysize 2048 -validity 10000
```

Add your keystore credentials in `apps/mobile/android/key.properties`:
```properties
storePassword=<YOUR_STORE_PASSWORD>
keyPassword=<YOUR_KEY_PASSWORD>
keyAlias=dhurmit-key
storeFile=release-keystore.jks
```
*(Ensure `key.properties` and `*.jks` remain in `.gitignore` to protect signing secrets).*

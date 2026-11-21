# BUDOWA GROUP — TEST Android

Flutter Android application for **TEST copies** of two company Google Sheets: work hours/payroll and finance/purchasing. This repository is **not a production accounting app**.

## Current working status (audit 21 November 2026)

- Google Sign-In and owner read-only navigation were demonstrated on an Android tablet.
- Nine tab views (five for work hours/payroll, four for finance) are implemented, including date/month sorting, dashboard, employee/site cards and project colors.
- Create/edit forms and the Apps Script **v0.5 source code** exist in this repository. **The deployed Apps Script verified on the tablet was v0.4/read-only**. A successful APK build does not activate writes.
- Write operations in TEST sheets have **not been verified end-to-end**. Do not enable `ENABLE_TEST_WRITES=true` until all P0 blockers and staged checks are complete.
- Server code does not accept arbitrary spreadsheet IDs and is explicitly restricted to the two TEST copies.
- Original Google Sheets and all scheduled backups are out of scope for all development changes.

## Project control center

- **[Full 21.11.2026 audit](docs/AUDIT_2026-11-21.md)** — authoritative requirements, findings, evidence and safety rules.
- **[Work process and gates](docs/WORKFLOW.md)** — one issue at a time, CI, staged deployment and acceptance.
- **[Current status](docs/STATUS.md)** — what is confirmed, in progress and blocked.
- **[Prioritized GitHub Issues](https://github.com/budowagroup/BUDOWA-GROUP-Android/issues)** — P0/P1/P2 task board.
- **[TEST server deployment playbook](backend/DEPLOY.md)** — controlled Apps Script rollout and rollback.

## Builds and checks

- [Android debug APK](.github/workflows/android-debug.yml) — verifies brand assets, runs Flutter analyzer and editor mapping tests, builds a debug APK with stable signing certificate.
- [Backend TEST checks](.github/workflows/backend-tests.yml) — tests read-only access, role guards, simulated writes and rollback **without changing Google Sheets**.
- The Android build requires Actions secrets `APPS_SCRIPT_URL`, `GOOGLE_WEB_CLIENT_ID` and configured stable signing credentials. No tokens or keys belong in Git.

**Build green ≠ write API deployed ≠ real data tested.** All three milestones have separate acceptance gates.

## Safety policy

Do not write to original Google Sheets, change their formulas, touch backup automations, publish confidential data, or deploy TEST writes without completing the P0 rollout plan. Owner-only audit/history is mandatory. Calculated report tabs are read-only; actual deletion of historical financial/payroll records is not implemented.

See [AUDIT_2026-11-21.md](docs/AUDIT_2026-11-21.md) before starting any change.

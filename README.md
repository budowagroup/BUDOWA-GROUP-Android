# BUDOWA GROUP Android — TEST v0.2

Flutter prototype for Google Sign-In and read-only access to **TEST copies only** of the company's hours/payroll and finance spreadsheets, through a separately deployed Google Apps Script API.

**Not production ready.** No data editing, owner/admin management, protected audit log or verified end-to-end login yet.

## Build

GitHub Actions workflow: [Android debug APK](.github/workflows/android-debug.yml). It generates Android platform files, runs Flutter analysis, builds a debug APK and uploads it as an artifact. Build success must be confirmed in Actions.

The CI workflow **fails before building** unless repository Actions secrets `APPS_SCRIPT_URL` and `GOOGLE_WEB_CLIENT_ID` are configured with valid-looking values. Passing this gate verifies only presence and format, **not** that OAuth, Apps Script, or sign-in actually works. For a local build, pass the same values via `--dart-define`. Android Google OAuth requires an Android client registered for `group.budowa.budowa_group` and the SHA-1 of the **actual stable signing certificate**; ephemeral CI debug signing must not be registered as a permanent credential. Never publish tokens or private signing keys.

Never commit credentials, tokens, employee information, or financial records. Never point this test prototype to original spreadsheets.

See [implementation status](docs/STATUS.md).

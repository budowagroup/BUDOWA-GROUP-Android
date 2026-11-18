# BUDOWA GROUP Android — TEST v0.2

Flutter prototype for Google Sign-In and read-only access to **TEST copies only** of the company's hours/payroll and finance spreadsheets, through a separately deployed Google Apps Script API.

**Not production ready.** No data editing, owner/admin management, protected audit log or verified end-to-end login yet.

## Build

GitHub Actions workflow: [Android debug APK](.github/workflows/android-debug.yml). It generates Android platform files, runs Flutter analysis, builds a debug APK and uploads it as an artifact. Build success must be confirmed in Actions.

For an authorized local build, configure `APPS_SCRIPT_URL` and `GOOGLE_WEB_CLIENT_ID` using `--dart-define`, and set up Android Google OAuth client with correct SHA-1. The default CI build intentionally omits real configuration and cannot sign in.

Never commit credentials, tokens, employee information, or financial records. Never point this test prototype to original spreadsheets.

See [implementation status](docs/STATUS.md).

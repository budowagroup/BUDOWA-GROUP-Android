# BUDOWA GROUP Android — TEST v0.2

This is a read-only prototype, NOT a production payroll or finance application.

- Flutter UI reads TEST spreadsheet copies through a separately deployed Google Apps Script API.
- Google Sign-In requires a configured OAuth Web client, Android client with signing SHA-1, and Apps Script deployment URL.
- The backend must enforce authorization. No write operations are implemented.
- Original spreadsheets and backup automations must remain untouched.
- GitHub Actions debug APK build requires independent verification.
- Debug APK built without --dart-define configuration cannot sign in.
- Never commit credentials, tokens, personal information or financial data.

Build variables: APPS_SCRIPT_URL and GOOGLE_WEB_CLIENT_ID. Values are not configured in this repository.

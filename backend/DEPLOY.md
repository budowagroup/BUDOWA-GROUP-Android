# BUDOWA GROUP — TEST API v0.5 deployment

The Android screens are ready for server-backed CREATE and UPDATE. The current deployed Apps Script v0.4 is read-only; **no write is possible until the existing API is updated**.

## Setup in the existing Apps Script project

1. Go to https://script.google.com/home/projects and open **BUDOWA GROUP Android API**.
2. Keep a private backup of the current Code.gs for rollback.
3. Replace the entire contents of the existing Code.gs with the file **backend/Code.gs** from this repository. Do not leave two doPost definitions.
4. In Project Settings > Script properties, retain **GOOGLE_OAUTH_CLIENT_ID** and add **ENABLE_TEST_WRITES** with exact value **true**.
5. In Deploy > Manage deployments > Edit the existing Web App > New version, deploy. Execute as **Me**; access **Anyone** (the API verifies Google ID tokens and only permits the owner). Editing the existing deployment normally keeps the same /exec URL.
6. If the /exec URL changed, update the GitHub Actions secret **APPS_SCRIPT_URL** before rebuilding. Never commit secrets or tokens.
7. Install the latest successful APK; sign out and sign in again so the new health capability is loaded. The button changes from **Чернетка** to **Додати** only when the server explicitly reports write access.

## Safeguards

- Only the two hardcoded TEST sheet IDs can be changed. The app cannot choose or override IDs.
- The server verifies the OAuth ID token, issuer, audience, expiry, email verification and owner email.
- New writes remain disabled when ENABLE_TEST_WRITES is absent or false.
- Calculated reports (Розрахунок / Панель) and formula columns are read-only.
- Existing row updates require its unchanged source display values. Concurrent changes are rejected.
- The first write adds a hidden audit sheet **_BG_APP_AUDIT** inside the appropriate TEST file. Request IDs prevent immediate duplicate submissions.
- Renaming established keys may be refused to protect formulas and referenced records; create new identities or use a controlled migration.
- Live deletions are not supported. Local temporary drafts are not shared with Sheets.

## Test sequence

1. Sign in as owner and check the enabled TEST write status.
2. Add one clearly labeled test operation. Check it appears once in TEST Sheets and updates financial summaries.
3. Edit that same operation; verify it updates in place, not as a duplicate.
4. Verify work hours, calculated salary/rate/remaining amounts, employee/objects and rate history in the TEST sheets.
5. To stop edits immediately, set ENABLE_TEST_WRITES=false in Script properties and sign in again to refresh the UI.

Never run this code against originals or change existing backup automations.

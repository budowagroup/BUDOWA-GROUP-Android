# BUDOWA GROUP — safe TEST-only Apps Script deployment

**Current status (21.11.2026):** Flutter Android build [#49](https://github.com/budowagroup/BUDOWA-GROUP-Android/actions/runs/44885185423) passed. The server implementation is prepared; separate read-only regression checks run in the backend workflow. **The existing deployed Apps Script verified on the tablet was v0.4 (read-only)**. Updating GitHub does not automatically update Apps Script. Updating GitHub does not automatically update Apps Script.

The source is **backend/Code.gs**, with automated checks in **backend/tests.js**. Do not deploy an untested or partially copied file.

## 1. Make a v0.4 rollback copy first (Android tablet supported)

1. On the Android tablet, open the *existing* **BUDOWA GROUP Android API** project in Chrome (⋮ → **Desktop site**, if needed). Use the account that owns this project.
2. In the Apps Script **left sidebar**, click **Overview** (ⓘ icon, often **Огляд** / **Przegląd**); then, in the Overview page **top-right**, select **Make a copy** / **Створити копію**. Name the copy **BUDOWA GROUP Android API — BACKUP v0.4 — 2026-11-21**. Confirm it is a *different* project with a different script ID. Merely clicking the project title changes its name — **it does not make a backup**.
3. Open the copied project and verify its `Код.gs` / `Code.gs` contains the original `doPost`, `health`, and `BG.admins` / authorization configuration. **Do not deploy the backup copy**. Keep the original /exec address in use until controlled rollout.
4. A copied project may **not** preserve deployment URLs or script properties. In the **original** project's Project Settings → Script properties, privately record the **property names**, confirm they will remain available, and preserve the values securely without sending them to ChatGPT/GitHub. Also privately record the original deployment ID and /exec URL for rollback.
5. In the **original v0.4 source**, locate the existing **admins** list and note its exact authorized emails privately. Do **not** publish names/email addresses in GitHub issues, screenshots, or chat.
6. Verify that the original Android app can still read both TEST workbooks, and leave `ENABLE_TEST_WRITES` absent or **false**.
7. **STOP HERE until the rollback copy and settings are confirmed.** Only then continue to step 2 below.

## 2. Preserve roles and stage the new version WITHOUT writes

In **Project Settings → Script properties**:

- `GOOGLE_OAUTH_CLIENT_ID`: verify the current **Web** OAuth client ID used by Android (not the Android client ID). The original v0.4 may have used a hardcoded value rather than this property. Create this Script property if absent, using the verified value; **do not guess or share it in chat**.
- `READ_ONLY_ADMINS`: **required to preserve the original v0.4 admin read access**. Set to a comma-separated list of *exactly* the former `admins` emails from the old `BG` configuration. They will only be able to read.
- `ENABLE_TEST_WRITES`: set to `false` for the first deployment. It fails closed if absent.

**Gate before deployment:** latest backend tests must pass; `READ_ONLY_ADMINS` and `GOOGLE_OAUTH_CLIENT_ID` must be configured and privately verified, `ENABLE_TEST_WRITES=false`, rollback copy confirmed. Then replace the **single** existing Code.gs / Kod.gs body with the complete contents of `backend/Code.gs`. Do not add two `doPost` functions.

Go to **Deploy → Manage deployments → Edit → New version → Deploy**. Keep the existing Web App deployment, Execute as **Me**, Who has access **Anyone**. The server validates Google ID tokens and email; Google Sheets remain inaccessible to unknown callers. The original `/exec` address should remain unchanged when modifying the existing deployment; if changed, update the GitHub Actions secret `APPS_SCRIPT_URL` and rebuild.

Sign out and back in to Android as the owner and verify:
- Both TEST workbooks and all tabs still load.
- The status still says read-only while `ENABLE_TEST_WRITES=false`.
- Every previously authorized admin can still view, with no ability to edit.
- No original or backup workbook was changed.

**If the read-only regression fails, roll back to the saved v0.4 immediately. Do not enable write.**

## 3. Enable writes for OWNER on TEST only

Once read-only testing passes, change the same Script property:
`ENABLE_TEST_WRITES=true`.

The property is evaluated server-side on each request; sign out/in on Android to refresh the button and capability UI. Only the owner account can perform Create/Update. Admins remain read-only.

**TEST-only destinations hardcoded in Code.gs:**
- Hours: `1pY6rcSlodNlXFRcu_UYqFnc9DB9zuIFFsoChX1Zmb_Y`
- Finance: `1l5eB0EafcIBfwosO_o5s6TYiUOvqek6uuo037DoHeGk`

No original workbook identifiers are present as writable targets.

## 4. Controlled acceptance tests (on TEST)

1. Add one obviously labeled, valid **Операції** record through Android. Verify it appears **once** in the TEST finance workbook and totals update.
2. Edit that same record. Verify update in place without duplication. If you see `EDIT_CONFLICT_REFRESH`, refresh the app before retrying.
3. In the TEST hours book, add a work-hours record for an existing worker and project. Verify time, rate, amount and remainder formulas.
4. Check employees, objects, rate history and dropdown reference lists.
5. Verify a non-owner cannot use write actions, and that a repeat requestId is idempotent.
6. Verify that no original workbook, backup workbook or backup automation was modified.

**Known limitations:** actual deletion of payroll/finance records and dependency-aware renaming are not provided. Creating new records requires the matching row's existing formula cells in TEST sheets to be present; the API refuses missing formulas rather than inserting potentially incorrect ones. Sheets writes are not database transactions: a best-effort rollback exists, but a failure with `WRITE_FAILED_REVIEW` requires manual inspection of the TEST audit sheet.

## 5. Emergency stop

Set `ENABLE_TEST_WRITES=false` under **Project Settings → Script properties**. The server stops future writes immediately. Relaunch or re-login to have Android refresh its displayed capability.

**Do not modify original Google Sheets, current backup automations, or the original accounting formulas.** Until all gates pass, do not change or deploy the existing working v0.4 project. Use Google Apps Script **Overview → Make a copy**, not the project-title rename field, on the tablet.

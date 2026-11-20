# BUDOWA GROUP — safe TEST-only Apps Script deployment

**Current status:** Flutter Android build #45 succeeded. The server implementation is prepared and regression tests pass, but **the existing deployed Apps Script is still v0.4 (read-only)**. Updating GitHub does not automatically update Apps Script.

The source is **backend/Code.gs**, with automated checks in **backend/tests.js**. Do not deploy an untested or partially copied file.

## 1. Make a v0.4 rollback copy first (Android tablet supported)

1. Open the *existing* **BUDOWA GROUP Android API** project in Chrome, with **Desktop site** enabled.
2. Make a private copy of the original project or save the entire old Kod.gs / Code.gs securely. Do not overwrite anything until you have a rollback copy.
3. In the old source, locate the existing **admins** list and note its authorized emails. Do not publish these in GitHub.
4. Verify that the old app can still read both TEST workbooks.

## 2. Preserve roles and stage the new version WITHOUT writes

In **Project Settings → Script properties**:

- `GOOGLE_OAUTH_CLIENT_ID`: retain the existing web OAuth client ID (check the current script setting).
- `READ_ONLY_ADMINS`: **required to preserve the original v0.4 admin read access**. Set to a comma-separated list of *exactly* the former `admins` emails from the old `BG` configuration. They will only be able to read.
- `ENABLE_TEST_WRITES`: set to `false` for the first deployment. It fails closed if absent.

Now replace the **single** existing Code.gs / Kod.gs body with the complete contents of `backend/Code.gs`. Do not add two `doPost` functions.

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

**Do not modify original Google Sheets, current backup automations, or the original accounting formulas.**

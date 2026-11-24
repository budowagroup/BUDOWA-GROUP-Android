# BUDOWA GROUP — safe TEST-only Apps Script deployment

**Current status (21.11.2026):** Flutter Android build [#49](https://github.com/budowagroup/BUDOWA-GROUP-Android/actions/runs/44885185423) passed. The server implementation is prepared; separate read-only regression checks run in the backend workflow. **The existing deployed Apps Script verified on the tablet was v0.4 (read-only)**. Updating GitHub does not automatically update Apps Script.

The source is **backend/Code.gs**, with automated checks in **backend/tests.js**. Do not deploy an untested or partially copied file.

## Live project manifest verified from user screenshot — 24.11.2026

The **actual working** `appsscript.json` (not the archived ZIP) contains:
`timeZone=Europe/Warsaw`, `dependencies={}`, `exceptionLogging=STACKDRIVER`,
`runtimeVersion=V8`, and `webapp: {executeAs:USER_DEPLOYING, access:ANYONE_ANONYMOUS}`.
**It does not explicitly list `oauthScopes`.** This is different from the older ZIP's
read-only manifest: Apps Script can auto-detect scopes when `oauthScopes` is absent.

The GitHub v0.5 manifest **preserves the live Web App configuration** and adds
explicit `spreadsheets` and `script.external_request` scopes. **Never paste a
manifest without the `webapp` section**: that can break the existing Web App.
Copy both `backend/appsscript.json` and `backend/Code.gs` only as part of a
staged rollout with `ENABLE_TEST_WRITES=false`; new OAuth authorization may be needed.
The existing deployment still requires a new **version** (not a new deployment)
to use the updated files.

## 0. Check the archived v0.4 package and OAuth scope migration

- Google Drive folder **BUDOWA GROUP — Android API** contains `BUDOWA_GROUP_Apps_Script_v0_4.zip` (saved **17.11.2026**). This archive contains a v0.4 `Code.gs`, `appsscript.json` and README, and is useful as a source-code reference.
- **An old ZIP is not proof of a snapshot of the currently deployed Apps Script project**. It does not preserve current Script Properties, deployment ID, authorization grants, or the precise currently deployed version. The separate rollback copy of the **actual live project** in section 1 remains mandatory.
- The v0.4 package manifest explicitly requests `https://www.googleapis.com/auth/spreadsheets.readonly`. That scope is insufficient for `setValue`, `insertSheet` and other v0.5 write operations.
- The version-controlled v0.5 `backend/appsscript.json` intentionally requests `https://www.googleapis.com/auth/spreadsheets` plus `https://www.googleapis.com/auth/script.external_request`. The project owner must review and explicitly grant the new authorization in the Apps Script editor **before attempting live TEST write operations**. Leave `ENABLE_TEST_WRITES=false` until staging checks pass.
- The original v0.4 template includes **three** administrator slots. The current requirement is **two** admins. Confirm the exact two active accounts privately against the actual live project before setting `READ_ONLY_ADMINS`; do not blindly copy the archived list or publish addresses.

## Перевірено за посиланнями користувача 24.11.2026

Існують **два окремі проєкти** (Google Drive metadata):
- Основний `BUDOWA GROUP Android API` — створений 18.11.2026.
- `BUDOWA GROUP Android API — BACKUP v0.4 — 2026-11-21` — створений 21.11.2026.

**Нову копію за рішенням власника не створювати**. Однак назва резервного проєкту та метадані не доводять, що він містить точно той самий код або дозволи, що діючий deployment. Перед оновленням перевірити `Code.gs` та `appsscript.json` в обох проектах через редактор, чинну версію deployment і можливість повернення до неї. Користувацькі URL не дають автоматичної авторизації Apps Script API; Google Drive connector не може читати чи змінювати `Code.gs`, Script Properties або deployments. Не проголошувати v0.5 deployed без browser/API readback.

## 1a. Альтернатива за рішенням власника: оновлення без окремої копії

> Користувач свідомо обрав **не створювати окремий резервний проєкт**. Це не прибирає ризик втрати останніх змін або налаштувань. Дотримуйтесь цього шляху лише за умови, що можна вибрати **попередню версію того самого deployment**. Жодного додаткового Google Drive файлу або Apps Script проєкту цей шлях не створює.

1. У діючому Apps Script обрати **Deploy → Manage deployments**. До редагування підтвердити наявність чинного deployment, його **версії** та можливості повернути попередню через **Edit → Version**. Переконатися, що ідентифікатор deployment та адреса `/exec` залишаться тими самими. **Якщо попередню версію неможливо вибрати — зупинитися**, інакше відкат без копії ненадійний.
2. Звірити чинний `Code.gs` з відомим архівом `BUDOWA_GROUP_Apps_Script_v0_4.zip` від 17.11.2026. Архів може бути застарілим: це **не доказ ідентичності фактично розгорнутого коду**. Приватно перевірити точні два активні admin акаунти та `GOOGLE_OAUTH_CLIENT_ID`; не надсилати їх у чат і не комітити.
3. Під час налаштування Script Properties поставити `ENABLE_TEST_WRITES=false`; `READ_ONLY_ADMINS` — тільки підтверджені два адресати, `GOOGLE_OAUTH_CLIENT_ID` — тільки підтверджений OAuth Web Client ID. За відсутності цих даних **не виконувати розгортання**.
4. Після успішного GitHub backend CI змінити **поточний** `Code.gs` на `backend/Code.gs`, а поточний manifest — на `backend/appsscript.json` (потрібні `spreadsheets` і `script.external_request`). Нові дозволи необхідно авторизувати особисто власнику Google-акаунту.
5. Відредагувати **існуючий**, не новий deployment: **Deploy → Manage deployments → Edit → New version → Deploy**. Не вибирати **New deployment**, якщо хочемо зберегти стару адресу Android.
6. Повторно увійти в APK: сервер має відповідати `version=0.5`, `dataSource=BG TEST Android API`, `capabilities.write=false`, owner і два admin мають читати всі 9 вкладок; admin не можуть писати, сторонні не мають доступу. Якщо щось не працює — через **Manage deployments → Edit** повернути **попередню версію** цього самого deployment. Після відкату можуть знадобитися старі Script Properties і підтвердження OAuth.
7. **Тільки після успішної перевірки** можна змінити `ENABLE_TEST_WRITES=true` і перевірити контрольне додавання/редагування **виключно в TEST**. Для аварійного вимкнення одразу повернути `false`.

**Обмеження:** GitHub та Google Drive не дають у цьому чаті інструмента для редагування й розгортання Apps Script. Зміна файлів у репозиторії **не виконує** жоден із кроків 1–7 у live проєкті. Не заявляти, що запис у Sheets увімкнений, доки це не підтверджено E2E.

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

**Gate before deployment:** latest backend tests must pass; `READ_ONLY_ADMINS` and `GOOGLE_OAUTH_CLIENT_ID` must be configured and privately verified, `ENABLE_TEST_WRITES=false`, rollback copy confirmed.

Then replace the **single** existing `Code.gs` / `Kod.gs` body with the complete contents of `backend/Code.gs`. Do not add two `doPost` functions.

In **Project Settings**, enable *Show "appsscript.json" manifest file in editor* if necessary; copy the full `backend/appsscript.json` into the existing project's manifest. Verify the **read/write Sheets scope** and the external-request scope before deployment. Do **not** retain the old `spreadsheets.readonly`-only manifest. Because permissions are changing, the script owner must authorize the new scopes in Apps Script (approve only after verifying the project is TEST-only and the target IDs are correct). The broader OAuth scope is authorized for the project owner, **not** as a grant to arbitrary API callers; token and role gates in the source still apply. If authorization is not verified, stop; do not enable writes.

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

## 3a. Verify runtime permissions and unchanged deployment

1. Keep `ENABLE_TEST_WRITES=false` and verify `health` reports `version=0.5`, `dataSource=BG TEST Android API`, `capabilities.write=false`.
2. Confirm nine read endpoints and Android connectivity as owner and both admins; outsider requests must return `FORBIDDEN`.
3. Inspect Apps Script **Executions** for missing-scope, authorization, and `UrlFetchApp` errors; confirm Google authorization was granted in the editor by the owner.
4. Validate the TEST spreadsheet IDs match the intended workbook pair. Do not silently replace them with the later 20.11 TEST copies.
5. Preserve the existing deployment ID and `/exec` URL; if either changed, rebuild APK only after the Android secret configuration has been updated securely.

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

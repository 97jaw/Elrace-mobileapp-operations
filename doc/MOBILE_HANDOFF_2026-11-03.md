# El Race Mobile App — Development Handoff

**Date:** 3 November 2026
**Owner:** M Jawad (Odoo + mobile lead)
**Repo (mobile):** `97jaw/Elrace-mobileapp-operations` — local `/Users/mjawad/projects/mobileapp/Elrace-mobileapp-operations`
**Repo (Odoo):** `pandoratech-llc/odoo14-clients`, production branch `elrace-addons` (server pulls only this)
**Firebase project:** `elrace-new`
**App version in `pubspec.yaml`:** `1.0.35+103` (change is uncommitted, see §1)

---

## 1. Repository state — read this first

| Item | State | Action needed |
|---|---|---|
| `main` | Has notifications foundation, keyboard fix, Firebase permissions fix (PR #1), timesheet "Sign Timesheet" from PDF viewer (PR #2) | — |
| **Uncommitted changes on `main` working tree** (16 files + new files) | **Timesheet signing mode** (auto boxes, box owners, 2 signees, stay on page, Send always on) + `firestore.rules` changes + `pubspec.yaml` version bump | Move to a branch `feat/timesheet-mode` before anything else (`git switch -c feat/timesheet-mode`), commit, test, PR |
| `fix/quick-fixes-nov` | 7 commits (qf1–qf7), **not merged, not pushed** | Rebase on `main`, resolve conflicts with timesheet mode (same signature files), PR |
| `tools/notify_check/` | **Untracked** (never committed) | Commit to `main` (no secrets inside; credentials come from env vars) |
| `fix/notif-same-screen`, `fix/keyboard`, `feature/notifications-foundation`, `feat/timesheet-sign-from-viewer`, `fix/firebase-permissions` | Already merged into `main` | Can be deleted after release |
| Backups | `backup/main-2026-10-29-pre-notifications-foundation` (mobile), `backup/elrace-addons-preNotify-20261029` (Odoo) | Keep until after the release is stable |
| Stash | `stash@{0}` "wip notifications and hr" | Firebase part already shipped via PR #1. Check the remaining HR WIP before dropping |

Uncommitted file list on `main`:
`firestore.rules`, `firebase/rules-tests/fixtures/write_keys.json`, `firebase/rules-tests/tests/write_contract.test.js`, `test/firebase/firestore_write_contract_test.dart`, `lib/chat/models/message.dart`, `lib/chat/repositories/chat_repository.dart`, `lib/ui/chat/screens/sign_document_screen.dart`, `lib/ui/chat/screens/sign_zone_picker_screen.dart`, `lib/ui/presentation/my_actions/data/models/signature_document.dart`, `lib/ui/presentation/my_actions/data/repositories/signature_documents_repository.dart`, `lib/ui/presentation/my_actions/screens/signature/recipient_picker_screen.dart`, `lib/ui/presentation/my_actions/screens/signature/signature_documents_tab.dart`, `lib/ui/presentation/my_actions/screens/signatures_screen.dart`, `lib/ui/presentation/timesheet/widgets/tm_pdf_bytes_preview_screen.dart`, `pubspec.yaml`, new: `lib/core/timesheet/timesheet_acknowledgment_zones.dart`, `lib/ui/chat/stamp_signature_on_zone.dart`, `test/timesheet/timesheet_acknowledgment_zones_test.dart`, `tools/`.
Ignore/revert: `packages/face_liveness_detector/.../xcuserdata/...xcschememanagement.plist` (Xcode user file).

---

## 2. What was built

### 2.1 Notifications Foundation v2 (merged in `main`)

Plan and specs: `doc/notifications/foundation/` (`README.md`, `01_ARCHITECTURE.md`, `02_TRIGGER_MATRIX.md`, `03_ROLLOUT_AND_TESTING.md`, `tasks/BACKEND.md|MOBILE.md|FIREBASE.md`). Manager's target matrix: `doc/notifications/Elrace_Notifications_Inside_Outside_Updated.docx`.

Idea: one dispatcher in Odoo (`elrace_notify`). Each notification type is a config record (channel, title/body template, tap action, rules, active / shadow / takeover). The app is a generic router driven by server flags.

| Commit | What |
|---|---|
| M1 `1412a3c` | `lib/core/notifications/` — payload v1 parser (legacy fallback), `NotificationRouter`, route registry, config service (`GET /api/v2/notifications/config`, any error → all flags false). `markHomeReady()` after sign-in / UAE Pass (taps no longer ignored after login) |
| M2 `d66ea59`, `53f1bfa`, `bcc8928` | Tap opens records with existing screens. By-id loaders: document, note, signature, project (`v2/get_project`), employee (existing `EmployeesProfileScreen(initialEmployeeId)`). IT request → Notification Center (no screen) |
| M3 `d0f4e4c` | Device register on login/resume/token refresh, unregister before logout (normal, forced, UAE Pass) |
| M4 `40dc109`, fixed by `dd1cd8b` | Notification Center reads the server inbox when `app_inbox_v2` is on. **Same existing screen and design**; only the data source changes (the extra v2 screen was removed) |
| M5 `a1c8591`, `bf19b66` | Mute categories from server; mandatory categories show "Required". Mute stays on the existing settings screen |
| M6 `62f3053` | Push handling per channel; no local inbox writes when `app_inbox_v2` is on; `inbox.sync` refreshes badge only; chat never stored in the center |
| M7 `55e8324`, `7c58381` | Prayer wording behind `prayer_text_v2`. iOS `AppDelegate.willPresent`: remote pushes → Dart shows the banner; local notifications (prayer etc.) present normally |
| F1–F6 `aba9453`…`4f6aef3` | Cloud Functions call Odoo `POST /api/internal/notify/emit` (`functions/lib/odoo_notify.js`, `functions-assignment/lib/odoo_notify.js`); legacy send if Odoo answers `handled:false`. Chat payload keeps `type/category = chat_message`, adds `nv`, `action=open_chat`, `params` |

**Deployed Firebase functions:** only `onNewChatMessage` (rev `00007`, 1 Nov). All other function changes (tasks, tickets, notes, signature, deadlines) are **in code but not deployed**. Live task/comment pushes come from `onNewTaskAssigned` / `onNewTaskComment`, which are **not in this repo** — never deploy a whole functions codebase (it would delete them). Deploy function by function only: `firebase deploy --only functions:<codebase>:<name> --project elrace-new`.

Secret `ELRACE_NOTIFY_INGEST_TOKEN` is set in Firebase; the same value is in Odoo System Parameter `elrace_notify.ingest_token`. Local copy: `~/.elrace_notify_ingest_token` (do not commit). Firestore collection-group index `todos (is_completed, due_date)` is in `firestore.indexes.json`; deployment of the index is unverified.

### 2.2 Odoo side that the app depends on (`elrace-addons`, live)

| Commit | What |
|---|---|
| B1–B6 | Module `elrace_notify`: types, events, deliveries, dispatcher `emit()`, FCM outbox + retry cron, device registry, inbox v2 APIs, ingest endpoint |
| B4-gate | Device register/unregister obey `elrace_notify.device_lifecycle` |
| B7–B13 + fix | Business hooks (approvals, HR final result, LPO issued, petty cash paid, vendor bill, BioTime, projects, document expiry, circulars, IT request) with the switch: takeover → new path; else legacy + shadow event. Web bell kept on takeover. Web refuse wizard hooked |
| B15 | `POST /api/v2/get_project`, `POST /api/v2/get_it_hardware_request` |
| B16 | Shadow mode (`type.shadow`, `emit(dry_run=True)`), `elrace.notify.type.preview` |
| B17 | Bulk emit (circulars to all staff) via batched creates + cron sender; category `mandatory` bypasses mute |
| B18 `6e9f73fdc` | **Critical:** dispatcher recordset was falsy so no hook ever ran — fixed with `__bool__` |
| B19 `a19a9bf53` | Vendor bills also send `approval.waiting` to the pending reviewer |
| B20 | **Critical:** `elrace_notify` controller `_auth` overrode `PurchaseController._auth` (Odoo merges sibling controllers) → all `/api/purchase/*` failed. Helpers renamed with a unique prefix |
| `7429a5294` | Mobile employee requests always submit directly (never web Draft `status=new`); web Save as Draft / Submit unchanged |

Current production configuration (System Parameters):

| Key | Value |
|---|---|
| `elrace_notify.enabled` | True |
| `elrace_notify.device_lifecycle` | True |
| `elrace_notify.close_legacy_token_routes` | True |
| `elrace_notify.prayer_text_v2` | True |
| `elrace_notify.app_inbox_v2` | **False** (set back to True after the new app is released) |
| `elrace_notify.server_task_notifications` | False |
| `elrace_notify.inbox_silent_sync` | False |
| `elrace_notify.ingest_token` | set (secret) |

Types: 12 Odoo types are **Active + Shadow, Takeover off** (`approval.waiting`, `hr.request.approved`, `hr.request.rejected`, `hr.employee.assigned`, `purchase.lpo.issued`, `account.vendor_invoice`, `expense.petty_cash.paid`, `attendance.biotime_sync`, `project.manager.assigned`, `project.member.added`, `document.expiry`, `circular.published`), all Mandatory. 7 categories active + mandatory (`waiting`, `hr`, `purchase`, `petty_cash`, `project`, `document`, `circular`). Users still receive legacy notifications; the new system records shadow events only. Odoo menus: Settings → Technical → Notifications → Types / Events / Deliveries.

Check tool: `tools/notify_check` (read-only, env vars `ODOO_URL`, `ODOO_DB`, `ODOO_LOGIN`, `ODOO_API_KEY`): `check-config`, `check-render`, `check-events --since 24h --include-shadow`, `report`. Ignore events with model `res.users` (manual shell tests).

### 2.3 Keyboard fix (merged)
`31fddad`…`7919a80`: tap outside closes the keyboard (global, `main.dart` builder), iOS Done bar above number/phone keypads, focus cleared on navigation and app background, autofocus removed where not needed, long forms dismiss on drag.

### 2.4 Firebase permissions (merged, rules deployed manually from `main`)
- Membership accepted via `member_ids`, `members/{uid}` or `dm_pair` (same as Storage).
- New DM + member docs in one batch allowed (`existsAfter` / `getAfter`).
- Signable docs: `page_count`, `sign_expires_in_days` allowed (root cause of "permission denied while sending via chat").
- `created_at` accepted if equal to server time or within ±24 h (wrong phone clocks).
- RTDB: `typing/{chatId}` readable (typing indicator).
- Contract test: `test/firebase/firestore_write_contract_test.dart` + `firebase/rules-tests/tests/write_contract.test.js` + fixture `firebase/rules-tests/fixtures/write_keys.json`. Any key the app writes that rules do not allow fails CI.
- CI: `.github/workflows/firebase-rules*.yml` — PR contract check only. **Rules are deployed by hand, only from `main` after merge:**
  `firebase deploy --only firestore:rules,storage,database --project elrace-new` (see `RULES_DEPLOY.md`).
- Crashlytics keys on permission-denied: `firebase_step`, `firebase_path`, `firebase_uid`, `firebase_rule_area`.
- To do on GitHub: make "firebase rules contract" a required check on `main`.

### 2.5 Timesheet signing
- **Merged (PR #2, `b86ab31`):** timesheet PDF viewer (`tm_pdf_bytes_preview_screen.dart`) shows Share, Download and **Sign Timesheet** icons under the file name. Sign Timesheet opens the Signature module "+" flow with this PDF preselected.
- **Uncommitted (timesheet mode):** auto signature boxes in every labour's "Approval and Acknowledgment" table (Employee, Supervisor/Foreman, Site Engineer, Projects Manager) found with Syncfusion text extraction (`timesheet_acknowledgment_zones.dart`). Each box has an owner: Employee + Supervisor/Foreman = foreman (signed on his phone, labour draws the Employee box), Site Engineer = signee 1, Projects Manager = signee 2. No "Sign it myself" in this mode. Free placement disabled (tap snaps to a cell). Up to 2 signees. Stays on the same page after drawing. **Send is always enabled** (counter is information only). Message/doc carry `timesheet_mode`, each sign update carries `timesheet_signer_slot`; rules deny old builds from signing timesheet docs (`timesheetSignAcknowledged()` in `firestore.rules`, not deployed yet). Normal "+" flow unchanged.

### 2.6 Quick fixes (branch `fix/quick-fixes-nov`, not merged)
qf1 one signature + one stamp zone (normal mode) · qf2 single signee (normal mode) · qf3 "New request" on every HR request tab · qf4 Employee Profile: management (feature `hr.employees_profile`) searches everyone, others open their own profile · qf5 shared amount box on all waiting approval forms · qf6 approved/rejected record leaves the waiting list immediately and counters refresh · qf7 overflowing values scroll (marquee) on waiting forms.
Conflict risk with timesheet mode: `recipient_picker_screen.dart`, `sign_zone_picker_screen.dart`, signature tab. Timesheet mode must keep 2 signees and 4 boxes; normal mode keeps qf1/qf2 limits.

---

## 3. Incidents fixed (for reference)
| Date | Problem | Cause | Fix |
|---|---|---|---|
| 1–2 Nov | iPhone pushes stopped | Apple Program License Agreement not accepted | Account holder accepted it; APNs key `89V8WPN69Y` (Sandbox & Production) on all iOS apps in Firebase. Live iOS bundle `com.elRace.elRace`, team `Z9KA83YY82`; Android `ae.elrace.mobile` |
| 2 Nov | No shadow events | Dispatcher recordset falsy | B18 |
| 2 Nov | Purchase lists/counters empty | `_auth` name clash between controllers | B20 |
| 2 Nov | Signature send permission-denied | Missing keys + clock check in rules | §2.4 |

---

## 4. Next steps (in order)
1. Move uncommitted timesheet-mode work to `feat/timesheet-mode`; run `flutter analyze`, unit tests, rules emulator + contract tests; PR.
2. Rebase `fix/quick-fixes-nov` on `main`, resolve conflicts, PR. Push it (it has no upstream).
3. Commit `tools/notify_check`.
4. Merge PRs → deploy rules by hand from `main` (`timesheet_mode` rule).
5. Build and test the release (§5), bump version, set Odoo company `x_min_version` to the new version so Site Engineer / PM phones can sign timesheet docs.
6. After release: `elrace_notify.app_inbox_v2 = True`; run `check-events`; switch READY types to Takeover ✔ / Shadow ✗ one by one (start with `approval.waiting`); watch Deliveries.
7. Wave D later (tasks/tickets through Odoo): deploy functions one by one, `server_task_notifications = True`, keep `onNewTaskAssigned` / `onNewTaskComment` until replaced.

## 5. Release test checklist
- Login (normal, sign-in screen, UAE Pass), logout on one of two phones (that phone gets no pushes).
- Notification taps (killed / background / foreground) open: HR request, LPO/RFQ, petty cash, invoice, task, ticket, circular, chat, document, note, signature, project, employee.
- Notification Center = old design; with `app_inbox_v2` on it shows server data, Clear All hides.
- iOS foreground: one banner for remote pushes, prayer local notification visible.
- Keyboard: tap outside, iOS Done bar, back navigation while typing.
- Chat image, note with audio/image, signature to a new person and to an existing chat — no permission-denied; typing indicator.
- Timesheet: print 3 labours → Sign Timesheet → auto boxes on all sheets → foreman + labour sign → send to 2 signees → each signs only his box → final PDF in Signature documents.
- Quick fixes qf1–qf7, especially qf6 (approve/reject removes the record at once).
- Purchase dashboard counters and lists.

## 6. Rules for whoever continues
- Never commit to `main` directly; one branch per task, one commit per item, PR.
- Odoo: `elrace-addons` only; backup pointer branch + DB dump before deploy; `-u` only when XML/fields change, otherwise restart workers. Odoo merges controllers that share a base class — never define generic helper names (`_auth`, `_inbox`) in new controllers.
- New behaviour ships behind a flag, OFF. Secrets only in System Parameters / Firebase secrets.
- Firebase: rules from `main` by hand; functions one by one, never a whole codebase, never `--force`.
- Any new Firestore field → rules + contract fixture in the same PR.
- Reuse existing screens; no new UI without approval.

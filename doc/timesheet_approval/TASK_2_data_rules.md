# Task 2 — Data model, repository, flag and Firebase rules (no UI)

Read first: `doc/timesheet_approval/PLAN.md` (sections Data, Notifications, Feature
flag). Branch `feat/timesheet-approval`. No UI in this task. **Do not deploy.**

## 0. Small leftover from Task 1
Remove the now-unused optional params on the records tile (`accentColor`,
`statusLabel`) so analyze has no new infos.

## 1. Model `TimesheetApproval` (Dart)
Fields as in PLAN.md → `timesheet_approvals/{id}`:
`owner_uid, owner_name, file_name, project_id, project_name, page_count, pdf_path,
approvers {uid: {role, name, status, acted_at}}, approver_uids, pending_uids,
status, cells, created_at, updated_at`.
- `cells`: list of `{page, role, x, y, width, height}` (relative 0..1), role
  `site_engineer` | `projects_manager`, taken from
  `findTimesheetAcknowledgmentCells` (only those two roles are stored).
- `role`: first picked approver = `site_engineer`, second = `projects_manager`.
- Helpers: `isPendingFor(uid)`, `myRole(uid)`, and a status label:
  `Pending with SE` / `Pending with PM` / `Pending with SE & PM` / `Approved` /
  `Rejected`.

## 2. Repository
- `create(...)`: make the doc id first → upload the foreman-signed PDF to Storage
  `timesheet_approvals/{ownerUid}/{docId}/original.pdf` → create the doc
  (`status: pending`, `pending_uids == approver_uids`, every entry `pending`,
  server timestamps). Reuse the existing Firebase-auth refresh used by the
  signature repositories before writing.
- Streams: `watchMine(ownerUid)` (newest first), `watchPendingFor(uid)`
  (`pending_uids array-contains uid`, newest first), pending count for the badge.
- `getById(id)`, `downloadPdf(path)`.
- `act(id, approve|reject)`: Firestore **transaction**. Fail clearly if I'm no
  longer in `pending_uids`. Set only my entry (`status`, `acted_at`).
  Approve → remove me from `pending_uids`; `status = approved` when it becomes
  empty, else stays `pending`. Reject → `status = rejected`, `pending_uids = []`.
  `updated_at` = server time.

## 3. Feature flag
`config/features.timesheet_approval` (bool). Read once per app session with a
short cache; missing doc/field or any error → `false`. Expose as a provider/
service other tasks can watch.

## 4. Firestore rules (`firestore.rules`)
`match /timesheet_approvals/{id}`
- read: owner, or `uid() in resource.data.approver_uids`, or
  `uid() in resource.data.pending_uids`. (The last one lets the
  `pending_uids array-contains uid` list query pass the rules; queries are only
  allowed when the rule can be proven from the query filter.)
- create: `owner_uid == uid()`; keys allow-list (exact list above); `status ==
  'pending'`; 1–2 approvers; `approvers.keys()` equals `approver_uids` (same
  set), owner not an approver; every entry `status == 'pending'`, role is
  `site_engineer` or `projects_manager`; `pending_uids == approver_uids`.
- update (approver only): `uid() in resource.data.pending_uids`; changed keys only
  `approvers, pending_uids, status, updated_at`; inside `approvers` only my key
  changed; my `role`/`name` unchanged; my status `approved` or `rejected`;
  approve → `pending_uids == resource.data.pending_uids.removeAll([uid()])` and
  `status == (that list empty ? 'approved' : 'pending')`; reject →
  `pending_uids == []` and `status == 'rejected'`. Owner cannot update.
- delete: nobody.

`match /users/{userId}/app_notifications/{id}` (Task 5 writes these from a Cloud
Function): read and delete by owner; update by owner only the `read` key; create
denied for clients.

`match /config/{doc}`: read if signed in; write denied.

Keep every existing rule, including `timesheetSignAcknowledged()` (1.0.35 docs).

## 5. Storage rules (`storage.rules`)
`match /timesheet_approvals/{ownerUid}/{docId}/{fileName}`: write by `ownerUid`,
PDF only, size limit like the signature docs path; read by owner or by a user in
`approver_uids` of `timesheet_approvals/{docId}` (use `firestore.get` like the
existing signature doc helpers).

## 6. Contract + tests
- `firebase/rules-tests/fixtures/write_keys.json`: add `timesheet_approvals`
  (create keys and the approver update keys) and `app_notifications` update key.
- `test/firebase/firestore_write_contract_test.dart`: build a full
  `TimesheetApproval` and check its keys against the fixture (same style as the
  existing models).
- Emulator tests (new `firebase/rules-tests/tests/timesheet_approvals.test.js`):
  `watchMine` and `watchPendingFor` queries allowed (query-level test); owner create ok; non-owner / bad keys / owner-as-approver / status≠pending
  denied; approver read ok, stranger read denied; SE approves → still pending,
  PM approves → approved; SE cannot touch PM's entry; owner cannot approve;
  reject → rejected and the other approver can no longer act; no delete.
  Storage: owner upload ok, approver read ok, stranger read denied, non-PDF
  denied. `app_notifications`: owner read / mark read / delete ok, client create
  denied, other user denied. `config/features`: read ok, write denied.

Run:
```
flutter test test/firebase
firebase emulators:exec --project elrace-new --only firestore,database,storage \
  "npm --prefix firebase/rules-tests test"
```

## Done when
All existing + new tests pass; analyze has no new issues in touched files.

## Commits
1. `chore(approvals): drop unused records tile params`
2. `feat(timesheet-approval): model, repository and feature flag`
3. `feat(firebase): rules for timesheet approvals, app notifications and config`
4. `test(firebase): contract and emulator tests for timesheet approvals`

Push the branch (no PR). Report test output. Stop and wait for my ok.

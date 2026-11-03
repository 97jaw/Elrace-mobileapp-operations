# Timesheet approval (Sign Timesheet → sign + approval) — plan

Branch: `feat/timesheet-approval` (from `main` 631d2f5, version 1.0.36+104). One
branch, six tasks, user's "ok" after each. Backend: **Firebase only** (no Odoo).

## What changes for users

1. **Foreman** opens a printed timesheet → **Sign Timesheet** → only the
   **Employee** and **Supervisor/Foreman** boxes appear (auto-detected on every
   labour page). Labour signs Employee, foreman signs Supervisor, on the foreman's
   phone. No Site Engineer / Projects Manager boxes, no stamp, no free placement.
   No condition on Send.
2. Foreman picks **Site Engineer** and **Projects Manager** like today (recipient
   picker, max 2, order = SE then PM) → Send. Both get it **at the same time**.
3. After Send the foreman lands on the **Timesheet main screen (foreman dashboard)**.
   The old "Recent timesheets" section is replaced by **Timesheet documents**:
   same look as the document list in the Signature module, with status:
   `Pending with SE` / `Pending with PM` / `Pending with SE & PM` / `Approved` /
   `Rejected`.
4. **Waiting screen**: new **Sign Document (SD)** box, same as the other waiting
   boxes, brownish colour, with counter. Open → list like other waiting records →
   open → PDF + **Approve / Reject** (existing buttons). Decision covers the whole
   document (all pages).
5. **Approve** writes the text `Approved by <name> (Site Engineer)` /
   `Approved by <name> (Projects Manager)` into that person's cell on every labour
   page. Rejected = no text.
6. The **Delayed Requests** card and all its calls are removed. ROR tab stays.

## Data (Firestore + Storage)

`timesheet_approvals/{id}`
- `owner_uid`, `owner_name`, `file_name`, `project_id`, `project_name`,
  `page_count`, `pdf_path` (Storage, foreman-signed PDF, never changed later)
- `approvers`: map `uid → {role: 'site_engineer'|'projects_manager', name, status: 'pending'|'approved'|'rejected', acted_at}`
- `approver_uids` (list), `pending_uids` (list), `status`: `pending` | `approved` | `rejected`
- `cells`: per page, SE and PM cell rects (relative 0..1) from
  `findTimesheetAcknowledgmentCells`
- `created_at`, `updated_at`

Rules: owner creates (status `pending`, `pending_uids == approver_uids`, 1–2
approvers); owner and approvers read; an approver may change **only his own**
entry in `approvers`, remove himself from `pending_uids`, and set `status` /
`updated_at`; nobody edits `pdf_path`/`cells` after create. Any reject → `rejected`
and `pending_uids = []`. All approved → `approved`. Storage: owner writes, owner +
approvers read. Contract fixture + emulator tests in the same task.

"Approved by" text is **drawn by the app when the PDF is opened/shared**
(original PDF + `approvers` data, deterministic). No final PDF is stored, so two
approvers acting at the same time cannot overwrite each other.

## Notifications

One Cloud Function `onTimesheetApprovalWritten` (codebase `default`, copy the
pattern of `functions/notes_share_notify.js`: tokens from `users/{uid}/fcm_tokens`,
`nv` payload, model `firestore.timesheet_approval`, `res_id` = doc id).

| Trigger | To | Stored? |
|---|---|---|
| created | SE + PM | **No** (push only) |
| one approves / all approved | foreman | **Yes** |
| one rejects | foreman | **Yes** |

"Stored" = the function writes `users/{foremanUid}/app_notifications/{id}`
(title, body, category `timesheet_approval`, model, res_id, created_at,
read=false). The Notification Center merges these with its current source
(works with `app_inbox_v2` on or off). Swipe delete / Clear All delete the
Firestore docs; mark read sets `read: true`; unread counts in the badge. The app
never writes these locally (no duplicates). Client may read/update(read)/delete
own; create only by the function.

## Feature flag

Firestore `config/features` → `timesheet_approval: false` by default (read-only
for clients; missing doc/field or any error = false). When false: no SD box and
no Sign Timesheet icon in the PDF viewer. The user turns it on after release.

## Keep for 1.0.35 docs (do not delete)

1.0.35 can create old-style timesheet signing docs (chat `timesheet_mode`). Keep
the **signee side**: `Message.timesheetMode`, `SignZone.signerSlot/cellRole`,
slot filtering in `sign_document_screen.dart`, `timesheet_signer_slot` in
`chat_repository.dart`, and the `timesheetSignAcknowledged()` rules. Remove only
the **foreman/creation side** of that old flow (Task 3).

## Reuse

`timesheet_acknowledgment_zones.dart`, `stamp_signature_on_zone.dart` (add a small
text-stamp function next to it), zone picker timesheet mode, recipient picker
(max 2), `StatCounterCard`, `ApprovalOverviewRecordsSheet`,
`approval_action_buttons.dart`, PDF viewer (`TmPdfFileViewer`/`PDFView`),
signature document list card/theme. No new packages.

## Tasks

1. Cleanup: remove Delayed Requests (keep ROR) and Recent timesheets.
2. Data + rules: collection, Storage path, rules, fixture, emulator tests.
3. Foreman flow: Sign Timesheet → Employee/Supervisor only → pick SE/PM → Send →
   back to dashboard; Timesheet documents list; remove old creation-side code.
4. Approver flow: SD box (5-card grid, brown), list, PDF with texts, Approve/Reject,
   home badge count.
5. Notifications: Cloud Function, Firestore notification store + Notification
   Center merge/delete, router `firestore.timesheet_approval`, no local store.
6. End-to-end test on two phones.

## Rules of work

Follow `.cursor/rules/branching-from-main.mdc`. One commit per item. Run
`flutter analyze` (no new issues in touched files) and `flutter test` before
"done". Never push/merge to `main`, never deploy (rules/functions are deployed by
the user by hand after merge, function by function). Reuse existing screens.

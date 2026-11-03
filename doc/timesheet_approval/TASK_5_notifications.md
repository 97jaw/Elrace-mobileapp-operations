# Task 5 — Notifications: push on every step, Firestore store for results

Read first: `doc/timesheet_approval/PLAN.md` (Notifications). Branch
`feat/timesheet-approval`. **Do not deploy** (the user deploys the function by
hand: `firebase deploy --only functions:default:onTimesheetApprovalWritten --project elrace-new`).
Never deploy a whole functions codebase.

## 0. Task 4 review fix (do first)
`ApprovalCountService._isTimesheetApprovalEnabled` creates a new
`TimesheetApprovalFeature()` on every badge refresh, so every refresh reads
`config/features` again. Use one shared instance (the same cache the provider
uses), refreshed only on resume / sign-in like the provider.

## A. Cloud Function `onTimesheetApprovalWritten`
New file in `functions/` (codebase `default`), exported from `functions/index.js`,
same region and style as `notes_share_notify.js` (tokens from
`users/{uid}/fcm_tokens`, remove invalid tokens like `onNewChatMessage`).
Trigger: `onDocumentWritten("timesheet_approvals/{id}")`.

| Change | To | Title / body | Stored |
|---|---|---|---|
| created | every `approver_uids` | `Timesheet waiting for your approval` / `<owner_name> sent <file_name>` (+ ` · <project_name>` if set) | **No** |
| an approver → `approved`, doc still `pending` | owner | `Approved by <name> (<Site Engineer/Projects Manager>)` / `<file_name> — waiting for <other name>` | Yes |
| doc → `approved` | owner | `Timesheet approved` / `<file_name> approved by <names>` | Yes |
| an approver → `rejected` | owner | `Timesheet rejected` / `<name> (<role>) rejected <file_name>` | Yes |

- Only the last matching row per write (e.g. the second approval sends only
  "Timesheet approved", not both).
- Payload `data` (strings): `nv: "1"`, `type` (`timesheet_approval.waiting` /
  `timesheet_approval.approved` / `timesheet_approval.rejected`),
  `category` (`timesheet_approval_waiting` for waiting, `timesheet_approval` for
  results), `action: "open_record"`, `model: "firestore.timesheet_approval"`,
  `res_id: <doc id>`, `click_action: "FLUTTER_NOTIFICATION_CLICK"`; plus
  `notification {title, body}`, Android high priority, APNs alert headers (copy
  from `notes_share_notify.js`).
- "Stored" = write `users/{owner_uid}/app_notifications/{eventId}` before the
  push: `{title, body, type, category, model, res_id, read: false,
  created_at: serverTimestamp}`. Use the event id as doc id so a retried event
  does not create duplicates. Add `fs_notification_id` to the push data.
- Not muteable (category not in the mute list).
- Keep the message building in a pure function and unit-test it (all four rows,
  single and two approvers, retry-safe id) with the test setup `functions/` has;
  if there is none, use `node --test` without new dependencies.

## B. App: tap routing and no local storage
- `route_registry.dart`: `firestore.timesheet_approval` →
  `TimesheetApprovalByIdLoader(resId)` (Task 4). It already decides pending →
  Approve/Reject, otherwise read-only; for the owner it opens the stamped PDF
  viewer (same as the Timesheet documents row).
- Do **not** save these pushes in the local Notification Center storage:
  skip categories `timesheet_approval` and `timesheet_approval_waiting` in
  `_saveNotificationToStorage` (`firebase_service.dart`: foreground, background
  tap, initial message) and in the background handler in `main.dart`. Results
  are already in Firestore; waiting is push-only.
- Foreground: show the banner as for other pushes; tap goes through the router.

## C. Notification Center reads Firestore results
`lib/ui/presentation/Notification/notification_screen.dart` (flag ON only):
- Load `users/{uid}/app_notifications` (newest first, limit 50) and merge them
  with the current source (local storage when `app_inbox_v2` is off, server inbox
  when on), sorted by date. Same row design. Mark them internally (e.g. id prefix)
  so actions go to Firestore.
- Tap → router (`model` + `res_id`).
- Swipe delete → delete the Firestore doc.
- **Clear All** → also delete all of the user's `app_notifications` (batched).
- Mark all read / open → set `read: true` on unread ones.
- Bell / app badge unread count adds the Firestore unread count
  (`count()` on `read == false`), refreshed with the existing badge refresh.
- Errors from Firestore never break the existing list (show the rest).

## Done when
- `flutter analyze`: no new issues in touched files; `flutter test`: all pass
  (add tests for merge/sort and for routing delete/clear to Firestore vs the
  existing source).
- Function unit tests pass. Rules emulator tests still pass (the
  `app_notifications` rules from Task 2 already cover read/update/delete).

## Commits
1. `docs(timesheet-approval): task 5`
2. `fix(approvals): one shared timesheet flag for the badge`
3. `feat(functions): notify on timesheet approval steps`
4. `feat(notifications): open timesheet approvals from a push, never store them locally`
5. `feat(notifications): show and delete Firestore results in the Notification Center`

Push the branch (no PR). Report results, including the exact deploy command for
the function. Stop and wait for my ok.

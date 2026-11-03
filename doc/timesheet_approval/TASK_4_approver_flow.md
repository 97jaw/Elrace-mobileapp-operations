# Task 4 — Approver flow: Sign Document box, list, PDF, Approve / Reject

Read first: `doc/timesheet_approval/PLAN.md`. Branch `feat/timesheet-approval`.
Uses Task 2/3 model, repository, flag and `stampTimesheetApprovalTexts`.
**Do not deploy.** Reuse existing screens/widgets; no new packages.

## 0. Task 3 review fixes (do first)
1. **Recipient picker for SE/PM:** `tm_pdf_bytes_preview_screen.dart` opens
   `RecipientPickerScreen(stampNeeded: true, ...)`. That shows only
   stamp-authorized users. Use the normal search (`stampNeeded: false`), as the
   old Sign Timesheet did when no stamp zone was placed.
2. **Timesheet documents stream:** `tm_timesheet_documents_section.dart` calls
   `watchMine(uid)` inside `build`, so every `setState` (e.g. `_opening`)
   re-subscribes to Firestore. Create the stream once (state field) and reuse it.
   Same rule for every stream added in this task.
3. **Messages:** do not show raw exceptions (`'Could not send: $e'`,
   `'Could not open: $e'`). Show a short friendly text, keep `debugPrint` for
   the detail.
4. **Flag refresh:** `timesheetApprovalEnabledProvider` keeps its first value for
   the whole session, so one failed early read hides the feature until restart.
   Refresh it when the app resumes and after sign-in (or make it auto-dispose).
5. **Heavy PDF work off the UI thread:** run `stampTimesheetApprovalTexts` (and
   the zone detection if it is not already) through `compute` so a big
   multi-labour PDF does not freeze the screen.

## A. Sign Document box (flag ON only)
- In `all_approvals_overview.dart` `_waitingCards()` add **Sign Document** after
  IT Request, **brownish** colour (theme colour + short label next to the
  others). 6 cards = 3 rows of 2. Flag OFF → no card (5 cards).
- Value = live count from `watchPendingFor(myUid)` (stream created once).
  Loading/error states like the other cards.

## B. List
- Tap the card → the same records bottom sheet the other boxes use
  (`ApprovalOverviewRecordsSheet`), filled from `watchPendingFor(myUid)`, newest
  first, live (a record disappears as soon as it is no longer pending for me).
- Row: file name, foreman name, project, date, and my role (Site Engineer /
  Projects Manager). Same row style as the other categories.

## C. Document screen
- Tap a row → download the PDF, apply `stampTimesheetApprovalTexts` (shows what
  is already approved), show it with the existing PDF viewer.
- Bottom: **Approve** / **Reject**, same look and confirm dialogs as the other
  waiting detail screens. `ApprovalActionButtons` is wired to the Odoo endpoints;
  reuse its visual part (add an override callback or extract the presentational
  piece) instead of copying it. No reject reason.
- Action → `TimesheetApprovalRepository.act(...)`, blocking progress, then:
  success snackbar (`Approved` / `Rejected`), pop back to the list; list and
  counter update by themselves (stream). If the transaction fails because I am
  no longer pending (other approver rejected, already acted) → friendly message
  and close.
- Opened when I am no longer pending (e.g. later from a notification in Task 5):
  read-only with the status label, no buttons.
- This screen must be reachable by doc id (Task 5 notification tap uses it):
  provide a small loader `TimesheetApprovalByIdLoader(id)` that fetches the doc
  and opens the right mode (approver pending → buttons; otherwise read-only).

## D. Home badge
`ApprovalCountService.getTotalApprovalCount` sums the Odoo categories. When the
flag is ON add my pending Sign Document count (Firestore `count()` on
`pending_uids array-contains uid`). After Approve/Reject call
`ApprovalCountService.invalidateCache()` + `notifyListeners()` so the home badge
and Waiting header refresh. Errors → count 0 for SD, never break the total.

## Done when
`flutter analyze`: no new issues in touched files. `flutter test`: all pass
(add tests for the badge sum and for the read-only / pending mode decision).
Rules emulator tests still pass.

## Commits
1. `docs(timesheet-approval): task 4`
2. `fix(timesheet-approval): normal signee search, one stream, friendly errors, flag refresh, PDF work off the UI thread`
3. `feat(approvals): Sign Document box with live count`
4. `feat(timesheet-approval): approver list and document screen with Approve/Reject`
5. `feat(approvals): include Sign Document in the home badge`

Push the branch (no PR). Report results. Stop and wait for my ok.

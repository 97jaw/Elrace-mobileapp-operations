# Task 3 — IT Request box + foreman flow (send for approval, Timesheet documents)

Read first: `doc/timesheet_approval/PLAN.md`. Branch `feat/timesheet-approval`.
Uses Task 2's `TimesheetApproval` model, repository and feature flag. **Do not
deploy.** Reuse existing screens/widgets; no new packages.

## 0. Task 2 review fixes (do first)
1. **Storage: PDF cannot be replaced after sending.** In `storage.rules`, the
   owner may write `timesheet_approvals/{ownerUid}/{docId}/...` only while
   `timesheet_approvals/{docId}` does **not** exist yet
   (`!firestore.exists(timesheetApprovalPath(docId))`). Otherwise a foreman could
   swap the PDF after SE/PM approved it. Add emulator tests: upload before create
   ok; overwrite and delete after create denied.
2. **`act()` writes only my entry.** In `TimesheetApprovalRepository.act`, update
   `FieldPath(['approvers', uid])` (+ `pending_uids`, `status`, `updated_at`)
   instead of rewriting the whole `approvers` map. Re-writing the other
   approver's entry can change its `acted_at` precision and the rules
   (`affectedKeys().hasOnly([uid()])`) would then deny the second approval.
3. **Feature flag:** cache only a successful read. On error return `false` but
   do not cache it (next call tries again; e.g. a read before Firebase sign-in).

## A. Waiting screen: IT Request box (UI only, data later)
- `StatCounterGrid` (`Email Approval/widgets/stat_counter_card.dart`) asserts
  exactly 4 cards. Make it a 2-column grid for any number of cards (same card
  size; an odd last card spans full width).
- Add a card **IT Request** in `all_approvals_overview.dart` `_waitingCards()`,
  after Employee Request, **purplish** colour (add colour + short label next to
  the others in `ApprovalsOverviewTheme`).
- No data yet: value `0`, not loading, no error. Tap opens the same records sheet
  with an empty list (existing empty state). No API call, no new screen.
- Task 4 adds the Sign Document (brown) card → 6 cards.

## B. Text stamp for approvals
Next to `stampSignatureOntoZone` (`lib/ui/chat/stamp_signature_on_zone.dart`) add
a function that takes the original PDF bytes, `cells` and `approvers`, and for
every approver with status `approved` draws
`Approved by <name> (Site Engineer)` / `Approved by <name> (Projects Manager)`
inside every cell of that role on every page (standard font, shrink to fit the
cell, centred, never outside the cell). Returns new bytes; original untouched.
Unit test: text found on each page in the right cell (use `PdfTextExtractor`),
nothing drawn for pending/rejected approvers.

## C. Foreman send flow (flag ON only)
Entry: **Sign Timesheet** icon in `tm_pdf_bytes_preview_screen.dart`.
- Flag OFF → hide the icon.
- Flag ON → open `SignZonePickerScreen` in timesheet mode **directly** (no longer
  through `SignaturesScreen` / Signature tab).

Zone picker, timesheet mode:
- Show only **Employee** and **Supervisor/Foreman** cells as boxes. Site Engineer
  and Projects Manager cells are not boxes (keep them only as data).
- No stamp tool, no tool chips, no drag; tap snaps to an Employee/Supervisor cell;
  labour/foreman draw as today; stays on the same page after drawing.
- Send always enabled (no condition). Returns the signed PDF bytes and the SE/PM
  cells from `findTimesheetAcknowledgmentCells`.

Then `RecipientPickerScreen` (max 2; first = Site Engineer, second = Projects
Manager; existing message). The foreman cannot pick himself in this mode (rules
deny owner as approver) — show a short snackbar. Remove `requireProjectsManager`
and `timesheetOneSigneeBlock` (and its tests): not used any more.

Then `TimesheetApprovalRepository.create(...)` with the signed PDF, file name,
project id/name (from the viewer, may be empty), page count, SE/PM cells and the
1–2 approvers. Show a blocking progress while uploading; on error show a snackbar
and stay. On success:
- go straight back to the **Timesheet main screen** (the screen that hosts
  `Fm1ForemanDashboard`, `timesheet_module_home_screen.dart`) with `popUntil`
  (give that route a name if it has none);
- snackbar `Sent to <SE name> & <PM name>`;
- the new doc is already in the list (stream), status `Pending with SE & PM`.

## D. Timesheet documents on the foreman dashboard (flag ON only)
In `fm1_foreman_dashboard.dart`, where Recent timesheets was:
- Section **Timesheet documents**, `watchMine(uid)` stream, newest first, 20 at a
  time with "Load more".
- Rows look like the document list in the Signature module
  (`signature_documents_tab.dart`): reuse its row widget/theme; if it is private,
  move it to a shared widget instead of copying.
- Each row: file name, project, date, status chip from the model label
  (`Pending with SE` / `Pending with PM` / `Pending with SE & PM` / `Approved` /
  `Rejected`). Empty and error states like the rest of the dashboard.
- Tap → download the original PDF, apply the B text stamp, open the existing
  viewer (`TmPdfBytesPreviewScreen` or its inner viewer) with Share/Download and
  **without** the Sign Timesheet icon.

## E. Remove the old timesheet creation path (keep the signee side)
Old 1.0.35 flow sent timesheets through the Signature module. Remove only what
created those docs:
- `SignaturesScreen.timesheetMode` and passing it on;
  `SignatureDocumentsTab.startUploadWithFile(... timesheetMode)` and the timesheet
  branch in `_showZonePickerThenChoose` / `_requestSignature`;
- `SignatureDocumentsRepository` `timesheetMode` param and
  `SignatureDocument.timesheetMode` if nothing else reads it (update the fixture
  + contract test);
- SE/PM zones and stamp logic in the zone picker's timesheet mode.

**Keep** (1.0.35 docs still in flight): `Message.timesheetMode`,
`SignZone.signerSlot/cellRole`, slot filtering in `sign_document_screen.dart`,
`timesheet_signer_slot` + the `timesheetMode` re-send in `chat_repository.dart`,
and all `firestore.rules`. Normal "+" flow unchanged (1 signature + 1 stamp, one
signee).

## Testing note
Live Firebase rules do not have Task 2's rules yet, so on a real phone the
create/stream calls will be denied until the rules are deployed. Test with unit
tests and the emulator here; phone testing is Task 6 (the user decides how rules
go live for testing).

## Done when
`flutter analyze`: no new issues in touched files. `flutter test`: all pass
(incl. new stamp test, updated contract test). Rules emulator tests still pass.

## Commits
1. `docs(timesheet-approval): task 3`
2. `fix(timesheet-approval): lock the PDF after sending, write only my approval, retry the flag`
3. `feat(approvals): IT Request box and a waiting grid for any number of cards`
4. `feat(timesheet): draw approval text into the Site Engineer and PM cells`
5. `feat(timesheet-approval): foreman sends a timesheet for approval`
6. `feat(timesheet): Timesheet documents list on the foreman dashboard`
7. `refactor(signatures): remove the old timesheet creation path`

Push the branch (no PR). Report results. Stop and wait for my ok.

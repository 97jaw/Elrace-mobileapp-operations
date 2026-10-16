# TASK 04 — App: labor picker + auto-advance on the project camera

Side: App (Flutter)
Depends on: TASK 03 (ship 03 + 04 together)
Read first: `doc/face_capture_1to1/00_TECHNICAL_APPROACH.md` §4

## Context
With 1:1 verification the camera needs a selected labor. The labor camera (opened from the foreman dashboard, `fm1_foreman_dashboard.dart` → `FmTimesheetCaptureSubmitScreen(expectedEmployeeId: member.employeeId)`) already has one. The project camera (opened from `fm_day_hub_screen.dart` and `fm_project_dates_screen.dart` with no `expectedEmployeeId`) does not. Add a labor picker to the capture screen and auto-advance after each verified capture so the morning gate stays fast.

## Files
- Host: `lib/ui/presentation/timesheet/foreman/fm_timesheet_capture_submit_screen.dart` (owns `_employees`, `_captures`, `_capturedEmployeeIds`, Your Team via `timesheetForemanLaborsProvider`, layout incl. tablet `chromeInset`)
- Panel: `lib/ui/presentation/timesheet/foreman/attendance/timesheet_capture_camera_panel.dart` (target handling from Task 03)
- Template state: `ProfilePhotoFaceDb.instance.states` (`ValueNotifier<Map<int, ProfileTemplateState>>`), `prioritize(employeeId)`

## Change
1. **Picker strip** on the capture screen, shown when the screen was opened **without** `expectedEmployeeId`:
   - Horizontal scrollable list of **Your Team** labors on this project (PM login with no team: all project labor, same fallback as today).
   - Each chip: small photo, short name, file id, template state icon (ready / building / failed) from `ProfilePhotoFaceDb.states`.
   - Order: not yet captured first (keep labor list order), captured last and shown as done (check mark, disabled).
   - Selected chip highlighted; tap selects it as the camera target. Selecting a labor whose template is still building calls `ProfilePhotoFaceDb.instance.prioritize(id)`.
   - Must fit portrait phones and tablets/iPad without covering the face oval or the shutter. Follow the existing `tablet` / `chromeInset` layout and safe-area handling on the screen. No horizontal page overflow.
2. **Initial selection:** first not-yet-captured labor with a ready template; if none ready yet, the first not-captured labor (camera shows "Verifying…" until its template is ready).
3. **Auto-advance:** after a verified, newly added capture, select the next not-captured labor (in strip order, wrapping once) after the existing green card display time. If all are captured, clear the target and show "All labors captured" with the existing submit action.
4. **Held card actions** (Task 03 "Doesn't match {target}"):
   - **Try again** → same target, resume.
   - **Pick another labor** → dismiss, scroll the strip to the current target, do not change target automatically.
5. **Labor camera mode** (opened with `expectedEmployeeId`): no strip; behaviour as Task 03. "Pick another labor" is hidden there.
6. Persisted session restore (`TimesheetCaptureSessionStore`) must mark restored captures as done in the strip.
7. Target switching must not restart the camera controller (Task 03 `didUpdateWidget` handling).

## Do not
- Change the dashboard / day hub navigation or route args.
- Change anti-spoof or verification logic.

## Verify
1. Project camera with 5 labors: first uncaptured selected; verify A → auto-advances to B; B → C …; captured chips show done and can't be selected.
2. Tap D while C is selected → target switches instantly, camera does not flicker/re-init, badge resets.
3. Labor with template building → chip shows building; selecting it moves it to the front of the build queue (log `ProfilePhotoMatch: emp=… moved to front`).
4. "Doesn't match" → Pick another labor → strip visible, target unchanged until tapped.
5. Reopen the screen after capturing some labors (session restore) → those chips are done.
6. Layout: iPhone SE-size, large iPhone, iPad portrait, Android tablet — strip, oval and shutter don't overlap; no overflow warnings.
7. Labor camera from dashboard: no strip, Task 03 behaviour.

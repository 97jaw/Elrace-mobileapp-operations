# TASK 03 — App: camera capture flow → 1:1 verification

Side: App (Flutter)
Depends on: TASK 02
Read first: `doc/face_capture_1to1/00_TECHNICAL_APPROACH.md` §2 and §4, `doc/FACE_CAPTURE_TECHNICAL_ANALYSIS.md` §2.7–2.9

## Context
The camera panel currently identifies the best match among the team and then decides green / red (wrong person, with that person's name) / yellow (not in team) / no match. Switch every decision in the capture camera to the 1:1 verifier from Task 02 against the **selected labor**. No other person's name may ever appear.

**Release note:** Tasks 03 and 04 ship together. After this task the project camera (no pre-selected labor) shows "Select a labor"; Task 04 adds the picker.

## Files
- Camera panel: `lib/ui/presentation/timesheet/foreman/attendance/timesheet_capture_camera_panel.dart` (`TimesheetCaptureCameraPanelState`)
  - `_isUnexpectedEmployee`, `_judgeUnexpected`, `_ExpectedLaborVerdict`, `_enterMismatchPreview`, `_showUnsureStillMessage`, `_ensureExpectedTemplates`
  - live preview matching (calls to `phaseB.matchImage(... focusEmployeeId: widget.expectedEmployeeId)`, stable-identity lock, badge)
  - `_capture()` still-photo decision block (`matchCapturePhoto`, yellow path, `clearInTeamWinner`, `softAccept`, `onRosterEmployeeMatched`, `onNoEmbeddingMatch`) and the legacy `cropBytes` + `rosterEmployees` fallback path right after it
- Host: `lib/ui/presentation/timesheet/foreman/fm_timesheet_capture_submit_screen.dart`
  - `_onUnexpectedEmployee`, `_onRosterMatched`, `_onOutOfTeamRecognized`, `_onAlreadyAttended`, no-match notice state (`_noMatchClosestName`, `_noMatchBestScore`), held-card action labels (`'Try again'` / `'Next labor'`)
- Cards: `lib/ui/presentation/timesheet/widgets/face_recognition/tm_face_capture_notice_tile.dart`, `tm_face_no_match_notice.dart`, `tm_face_out_of_team_warning.dart`
- Config: `lib/core/site_management/face_recognition/face_recognition_config.dart` (`FaceExpectedLaborMatch`)

## Change

### 1. Target
- The panel verifies against one **target labor**. Use the existing `expectedEmployeeId` / `expectedEmployeeName` as the target (rename if it reads better, e.g. `targetEmployeeId`).
- The target must be changeable while the camera is open (Task 04 will change it). Handle it in `didUpdateWidget`: when the target changes, clear badge, stable-identity lock, held state, preview timers and auto-capture arming, then resume live detection for the new target. Do not re-initialise the camera controller.
- If the target is `null`: no verification runs, no auto-capture; overlay hint "Select a labor to verify". Quality gates and preview still run.

### 2. Live preview
- Replace preview `matchImage` + best-match badge with the Task 02 verifier for the target.
- Badge:
  - verified on 3 stable hits within the existing window → green, **target name** only.
  - anything else → neutral "Verifying {target}…" (no red badge, no other name, no alarm on the stream).
- Keep the existing preview anti-spoof gating (name hidden on spoof; low-end devices never show a name before capture).
- Keep intervals / throttles as they are.

### 3. Still capture decision (replace the whole decision block after `matchCapturePhoto`)
Run burst + shutter anti-spoof exactly as today, then call the verifier on the still, then:

| Verifier outcome | Action |
|---|---|
| `verified`, target already captured | existing blue "already attended" path, **including** the existing replay check (`_isLikelyReplayFrame` → `_blockReplayAttempt`) |
| `verified`, not yet captured | existing green path: enqueue draft, `_markJustCaptured`, callback to host with the score (see §5) |
| `lowScore` / `notDistinct` | held card **"Doesn't match {target}"**, actions **Try again** and **Pick another labor** (the second action only when the host supports switching — Task 04; until then only Try again). Soft alarm allowed, keyed by target id. |
| `noTemplate` | card "{target}'s photo isn't available for face match" with the existing manual-add option; do not auto-retry in a loop (reuse the existing template refresh with its attempt limit/cooldown) |
| `faceTooSmall` | snackbar "Come closer to the camera" and re-arm; no card |
| `error` | existing generic failure handling |

- Remove: `clearInTeamWinner`, `softAccept`, the yellow `onOutOfTeamRecognized` path, the `_judgeUnexpected` mismatch/unsure logic, and any call that passes another employee to `onUnexpectedEmployee`.
- Remove the legacy `cropBytes` + `rosterEmployees` 1:N fallback branch from the capture flow if it is only reachable from this camera; if another screen still uses it, leave it for that screen and make sure this panel never enters it.
- Delete the photo file in every non-accepted branch, as today.

### 4. Cards and notices
- Notice tile mismatch kind: show the **target's** photo and name with text "Doesn't match {target}". It must not render any other employee. Change the host's `_onUnexpectedEmployee` accordingly (or replace it with a `onTargetNotVerified(reason)` callback).
- `TmFaceNoMatchNotice`: remove `suspectedName` / closest name. Keep the score only in debug builds.
- `tm_face_out_of_team_warning.dart` and `onOutOfTeamRecognized`: remove usage from this flow (delete the widget if nothing else uses it).

### 5. Host callbacks
- Matched callback carries the verify result (target score, lead, cohort size) instead of best/second scores; keep storing `matchScore` in the session entry as today, plus the new fields (Task 07 sends them to Odoo).
- `_onRosterMatched`: the "matched someone else but camera is for X" branch is no longer reachable; remove it.
- `faceMatchSessionProvider` records: record the verify outcome and scores (no other employee id).

### 6. Config cleanup
- Remove `FaceExpectedLaborMatch.mismatchMinScore` and `mismatchMinLead` and anything only they used. Keep template-refresh constants if still used.

## Do not
- Change anti-spoof (burst, shutter PAD, preview PAD, temporal checks), camera init, orientation lock, resolution, throttles.
- Change submit rules or the Hive queue format beyond adding fields.
- Show any employee name other than the target anywhere in the capture screen.

## Verify (device: one iPhone, one Android, one tablet)
1. Labor camera for labor A, A in front → green "A ✓", added.
2. Labor camera for A, labor B in front → "Doesn't match A", B's name never appears; Try again works.
3. Labor camera for A, a person not in HR in front → "Doesn't match A".
4. A already captured, A in front → blue "already attended"; photo-of-photo of A → replay blocked as today.
5. Labor whose profile photo is missing → "photo isn't available" + manual add.
6. Team of one: stranger in front → rejected (log shows `usedNoCohortBar=true` only if cohort < `minCohort`).
7. Change `elrace.face_verify_min_score` in Odoo to 0.90 → after config refresh, A is rejected; set back → accepted.
8. Front and back camera both work; no regression in anti-spoof logs (`AntiSpoof L1:`, `BurstVerification:`).
9. Project camera opened without a labor → "Select a labor to verify", no capture fires.
10. `flutter analyze` clean; update/replace tests that referenced the removed paths (e.g. `test/timesheet_acting_as_foreman_test.dart` if affected).

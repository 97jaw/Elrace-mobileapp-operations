# TASK M10 — Attendance check-in / check-out face verification (1:1)

Repos
- Odoo: ~/projects/elrace/odoo14-clients/.worktrees/elrace-addons (branch elrace-addons)
  modules: elrace_backend_apis, emp_mobile_conf
- Mobile: ~/projects/mobileapp/Elrace-mobileapp-operations (branch feat/checkin-attendance-v2)

Author for every commit: M Jawad <jawad@elrace.com>. NO Co-authored-by / Cursor trailer.

## 0. Scope (read first)
- ONLY mobile attendance check-in / check-out (attendance_service + lib/ui/presentation/attendance_checkin).
- Do NOT change timesheet: no edits to timesheet_capture_camera_panel.dart, fm_timesheet_* screens,
  timesheet face settings, their APIs or behaviour. Timesheet must behave exactly as today.
- Reuse the SAME model, configuration and scoring as timesheet. No new package, no new model file.
  App size must not grow.
- Only allowed change in shared core (lib/core/site_management/face_recognition): additive, see 3.2.

## 1. Decisions (fixed)
1. Face is checked on BOTH check-in and check-out.
2. The template comes from the employee's Odoo PROFILE photo (hr.employee image), same as timesheet
   profile-photo mode. The success screen shows the PROFILE photo, not the captured frame.
3. No usable profile photo (missing, or no face found in it) → blocked:
   "Your profile photo can't be used for face check. Please contact HR."
4. Capture is AUTO: as soon as quality + liveness + match pass. A shutter button stays as a fallback
   (same pipeline, no bypass).
5. 3 failed match attempts → stop: "Face not matched. Please try again or contact HR." Back to the sheet.
6. A low-end phone that fails face_min_device_check → blocked:
   "This phone can't run face verification. Please contact your admin." (The admin can remove the role
   feature for that user.)

## 2. Switches (both must be ON for face to be required)
1. ir.config_parameter elrace.checkin_face_required: elrace_backend_apis/data/params.xml, noupdate,
   default 'True'. Read live per request. OFF = no face step for anyone.
2. New mobile.feature in emp_mobile_conf/data/mobile_features.xml:
     code hr.attendance.face_verify, name "Attendance: Face verification (1:1)",
     category human_resource, module hr, kind action, sequence 75, is_default False.
   It then shows as a checkbox in Role Templates (Employee Configuration) and in role-user add/remove
   like the other features. Do not change the feature engine.
Server helper: _face_required(emp) = param ON and
FeatureAccessService(env).allows(emp.user_id, 'hr.attendance.face_verify').
Check how allows() behaves when feature enforcement is OFF (enforce_enabled), and make face_required
follow the role feature regardless. Report the behaviour.
Remote employees (checkin_remote) follow the same face rule (only location is skipped for them).

## 3. Mobile

### 3.1 Flow
```
Check-in screen opens → context fetch (face_required, profile_photo_url) →
  if face_required: warm the self template in the background
Tap Check In / Check Out
  → existing gates and dialogs (location, checkout_mode dialog / confirm)
  → face_required ? SelfFaceVerifyScreen : skip
  → API check_in / check_out (+ face payload)
  → CheckinSuccessScreen → Done → pop to Home (root)
```

### 3.2 Template (core, additive only)
- ProfilePhotoFaceDb is a singleton holding the foreman labour roster. Self check-in must NOT reset or
  overwrite it.
- Add a second, separate instance for self check-in with its own cache file, e.g.
  ProfilePhotoFaceDb.self (cache 'self_checkin_template.json'). Parameterise the cache file name.
  `instance` keeps its current name, behaviour and cache.
- Same embed pipeline, pipelineVersion, alignment, 7-day refresh as the existing one.
- One member only (the logged-in employee), target=true, no cohort.
- New service lib/ui/presentation/attendance_checkin/face/self_face_template_service.dart:
  warm(), status (pending/ready/failed + reason), template().

### 3.3 Verify screen: lib/ui/presentation/attendance_checkin/face/self_face_verify_screen.dart
- Design (left screenshot): white top bar with X + title "Check In" / "Check Out"; full camera
  (front cam) with white corner frame; pill "Hold still…" / guidance text; shutter circle at the bottom.
- Pipeline (reuse, new instances, same config):
  FaceCaptureService quality checks → TimesheetLivenessGate + BurstVerificationPipeline (MiniFASNet) →
  FaceRecognitionService.verifyImage(targetEmployeeId: self) using the self template.
  With no cohort the existing bar FaceVerifyTuning.minScoreNoCohort applies. Do not change thresholds.
- Load the interpreter when the screen opens and dispose it on close.
- Result returned to the caller: {verified, score, livenessOk}.
- Guidance strings come from the existing quality/liveness messages.

### 3.4 Success screen: lib/ui/presentation/attendance_checkin/face/checkin_success_screen.dart
- Design (right screenshot): big green tick circle; title "Checked In" / "Checked Out";
  "Today, 25 Oct 2026"; time in large green text (server time from the API response);
  card with the PROFILE photo (profile_photo_url, cached) + pin icon + location name
  (selected project name / "Company Office" / "Remote") + sub line (project ref or address if available).
- Bottom pill "Check In Successful" / "Check Out Successful" with tick.
- Add a "Done" button (bottle green, full width) → Navigator.popUntil(root) → Home.
- System back = Done.

### 3.5 Other
- Pass the face payload to the API: face_verified, face_score, liveness_ok.
- If the API errors after a face pass, show the error dialog and refresh context (no success screen).
- No timesheet imports from fm_* / panel files. Import only core classes.

## 4. Backend (elrace_backend_apis)
- get_checkin_context: add face_required (bool) and profile_photo_url (same URL style timesheet uses for
  profile photos).
- check_in / check_out: accept face_verified, face_score, liveness_ok.
  If _face_required(emp) and not (face_verified and liveness_ok) → _err("Face verification required.").
  Order in check_out: gate → exists → owner → today → location → time window → face → later-wins.
- hr.attendance new fields (in elrace_backend_apis or the module that owns the attendance extensions):
  x_face_score = Float, x_face_verified = Boolean. Columns are pre-created with SQL as nullable, so the
  upgrade adds no table rewrite. Write them on check-in. On check-out, write them only when check_out is
  actually written.
- Ledger mobile punch: store face_score in the punch raw payload if the ledger has a raw/json field.

## 5. Tests
- Backend: param OFF → no face needed; param ON + feature ON + no face → error; feature OFF → no face;
  remote + face required → still required.
- Mobile: unit tests for the flow decision (face_required true/false), the self template instance not
  touching ProfilePhotoFaceDb.instance, and success → Done pops to root. flutter analyze clean.

## 6. Deploy notes (for the report)
SQL before the upgrade:
  SET lock_timeout = '5s';
  ALTER TABLE hr_attendance ADD COLUMN IF NOT EXISTS x_face_score double precision;
  ALTER TABLE hr_attendance ADD COLUMN IF NOT EXISTS x_face_verified boolean;
Upgrade: -u emp_mobile_conf,elrace_backend_apis

## 7. Commits
- elrace-addons: "checkin: face verification switch, role feature, face fields"
- mobile: "checkin: 1:1 face verify + success screen (reuses timesheet model, no timesheet changes)"
Report: diffs, the allows()/enforcement finding, test results, hashes, and the APK size before/after.

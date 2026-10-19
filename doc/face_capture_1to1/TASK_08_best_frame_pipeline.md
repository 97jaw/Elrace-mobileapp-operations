# TASK 08 — Best-frame evidence pipeline (continuous anti-spoof + identity)

Side: App (Flutter) + one key in backend `/api/app/config`
Depends on: current 1:1 capture (Tasks 01–07 + fast-path work) merged and stable
Read first: `doc/face_capture_1to1/10_BEST_FRAME_APPROACH.md` (all of it)

## Context
Today the capture camera relies on quality gates and a 4-frame anti-spoof ring buffer collected around the tap. Users must adjust framing ("Move back", etc.) mainly because of anti-spoof constraints. Replace this, in 1:1 verify mode only, with continuous per-frame evidence and a window-based accept rule. Do not change any model, threshold, verification bar or cohort logic.

## Files (starting points — confirm in code)
- `lib/ui/presentation/timesheet/foreman/attendance/timesheet_capture_camera_panel.dart` (stream handling, ring buffer `ringMinInterval`, `_lowEndDeviceMode`, preview intervals `_previewMatchInterval`, fast-path / slow-path capture, `_faceTooLargeForPad`)
- `lib/core/timesheet/services/face_capture_service.dart` (`_evaluateQuality`, `minFaceWidthFractionStream`, eye/yaw limits)
- `lib/core/site_management/face_recognition/antispoof/*` (`AntispoofConfig`, `BurstVerificationPipeline`, temporal heuristics)
- `lib/core/site_management/face_recognition/face_recognition_service.dart` (1:1 verify)
- `lib/core/services/app_config_service.dart`
- Backend: `elrace_backend_apis/controllers/auth_controller.py` → `get_app_config`

## Part A — Backend (tiny)
1. Add `face_best_frame_enabled` to `/api/app/config`, read from `ir.config_parameter` `elrace.face_best_frame_enabled`. Values `"0"`/`"false"` → `false`; `"1"`/`"true"` → `true`; missing/other → `null`.
2. Bump module version.

## Part B — App

### 1. Switch
- `AppConfigService` parses `face_best_frame_enabled`, caches it; `null` → **true**. Plus a const kill switch in code.
- Off → today's fast/slow capture path unchanged. On → this task's pipeline. Applies only to the 1:1 capture panel (`verifyTarget: true`); AT2 legacy untouched.

### 2. FrameEvidence
Per processed stream frame store: timestamp, face box, upright frame reference (for the best frame only keep pixels; release others), quality score, identity result (target score, lead, cohort size, verified) or `notEligible`, PAD result (live / spoof / uncertain + probs) or `notEligible`.

### 3. Processing loop
- Largest face only.
- Throttle: one frame every ~200 ms normal, ~400 ms in `_lowEndDeviceMode`. Drop frames while busy; never queue.
- Eligibility, all **frame-relative** (% of upright frame short side), as in approach §3:
  - Identity: face width ≥ 8 %, yaw ≤ 35°, roll ≤ 30°, 5 landmarks.
  - PAD: face width 10–55 % (reuse `AntispoofConfig.maxFaceWidthFraction`), yaw ≤ 30°, box fully inside frame, sharpness ≥ current still threshold.
- Run 1:1 verify and PAD (same MiniFASNet dual-model call used by the burst today) on eligible frames. Reuse interpreters; no new models.
- Quality score 0..1: size closeness to ~35 %, frontalness, sharpness, eyes open, brightness. Used only to pick the best frame.
- Rolling window: keep evidence from the last 1.2 s.

### 4. Accept rule (exactly)
Within the window:
1. ≥ 3 frames with PAD = live (current thresholds) AND identity verified (current bars/cohort).
2. Zero PAD = spoof frames. On any spoof frame: reject, clear window, 1.5 s cooldown, existing presentation-attack message/alarm.
3. Accepted frames span ≥ 400 ms and pass the existing temporal (frozen box / motion) check.
4. Best frame (max quality among accepted frames) is verified and live.
5. Uncertain PAD frames: not counted, not blocking.
Never accept on a single frame.

### 5. Triggers
- Auto-capture: fires the moment the accept rule holds (instant auto-capture in verify mode).
- Manual shutter: rule holds → accept now; else wait up to 1.5 s for it, then snackbar "Hold still".
- Accept → existing green-card flow: card + haptic/spoken name immediately, best frame saved as the capture photo + Hive write in background, audit fields from the best frame. Already-attended → existing blue card with replay check on the best frame.
- After accept / target change / Try again: clear window.

### 6. Blocking gates removed (verify mode, switch on)
- "Move back" / too-close and other quality failures no longer block or show instantly. They only make frames ineligible. (Hint display is Task 09.)
- Expose a `noUsableFrameSince` timestamp + the dominant reason (too far / too close / angle / blur / dark) for Task 09.

### 7. Marker state (for Task 09)
Expose `markerState`: `none` | `verified(employeeId, faceBox)`. Verified when the target is verified on ≥ 2 of the last 3 identity-eligible frames AND no spoof frame in the window. Drops to `none` when that stops holding (no 400 ms stale clear; 1.8 s safety stale clear as today).

### 8. Logs
- Per attempt summary: `BestFrame: accept ms_from_first_face=… window=n frames live=a verified=b spoof=0 best_q=… t=… lead=…`
- `BestFrame: reject reason=spoof|…`
- Every 2 s while not accepted: `BestFrame: waiting eligible_id=… eligible_pad=… dominant=too_close|…`

### 9. Remove when switch on
Ring-buffer burst at tap, fast/slow path selection, `preview_stale`, still `takePicture` path. Keep the code for switch-off mode.

## Do not
- Change models, PAD thresholds, temporal heuristic thresholds, verification bars, cohort.
- Touch AT2, enrollment, submit, backend other than the one config key.
- Show any name on the marker (Task 09 does the UI).

## Verify (profile build; iPhone, Android phone, iPad or Android tablet)
1. Labor enters frame naturally → `BestFrame: accept` with `ms_from_first_face` < ~1000 on mid/high devices.
2. Labor too close (face > 55 %) then natural → accepted once usable frames appear; no block.
3. Printed photo / phone screen / video → never accepted; `reject reason=spoof`.
4. Photo of target until marker verified, then swap to a live different person → not accepted.
5. Live target, then photo swapped in → spoof reject.
6. Wrong person → never accepted.
7. Switch `elrace.face_best_frame_enabled = 0` → after config refresh, old path logs (`fast accept` / `slow path`) return.
8. Low-end Android: no UI freeze, accept within ~2 s.
9. `flutter analyze` clean, existing tests pass; add unit tests for the accept rule (pure function over a list of FrameEvidence).

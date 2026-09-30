# Timesheet Camera (Face Attendance) — Android Technical Summary

**Period:** Monday 22 September – Sunday 28 September 2026 (today, 29 September, excluded)  
**Module:** Foreman timesheet capture — face detection, liveness (anti-spoof), and face match  
**Shipped in:** release `1.0.28+96` (bumped 23 September, from `main`)

---

## 1. Summary

All camera work in this period landed on **22 September** in two commits. The goal was to make face attendance stable and fast on mid- and low-end Android phones, which were crashing, stalling, or failing to match genuine workers.

| Commit | Title | Scope |
|---|---|---|
| `4c72cc7` | perf(timesheet): use high camera preset for Android attendance | 1 file |
| `637995e` | feat(timesheet): harden Android face-match path and fix recent records listing | 20 files, +1,322 / −569 |

No camera commits were made between 23 and 28 September. The rest of that week was projects, UAE PASS, and release work. Camera edits made today (29 September) are uncommitted and not part of this report.

---

## 2. Problems we were fixing

1. **Native crashes on MediaTek and Samsung XCover devices.** The TensorFlow Lite XNNPACK delegate crashed inside native code (`TfLiteXNNPackDelegateCreateWithThreadpool`). Dart cannot catch that crash, so the app closed.
2. **Stalls during capture.** The models were being rebuilt mid-session. Every inference passed nested Dart lists to `Interpreter.run`, which resized the input tensor, re-allocated it, and re-applied XNNPACK each time.
3. **Heavy per-frame work.** Android ran the camera at `ResolutionPreset.max`. Each live frame was encoded to a JPEG, written to disk, then read back for liveness and matching.
4. **Genuine workers not matched.** The match bar was 22%. Weak stills from site conditions showed "No Face". The matcher could also count a second template of the **same** person as the runner-up, which made the winner margin look like zero.
5. **Recent timesheets list empty.** Rows only appeared when the task-list lookup matched, which often missed lines submitted on site.

---

## 3. What we changed

### 3.1 Camera resolution (`4c72cc7`)

- Android attendance camera moved from `ResolutionPreset.max` to `ResolutionPreset.high` (about 720p), matching iOS.
- Stream format stays `yuv420` on Android.
- Enrolment camera unchanged.
- We tested `medium` and rejected it: still-match scores dropped to 0.20–0.27.

### 3.2 Safe TensorFlow Lite interpreter factory (new file `tflite_interpreter_factory.dart`, 220 lines)

All models (FaceNet embedder and both MiniFASNet liveness models) are now created through one factory:

- **CPU is the default and fallback.** XNNPACK is optional.
- **Crash-loop guard.** A flag `tflite_xnnpack_init_attempted` is saved **before** the native XNNPACK create and cleared only after it succeeds. If the app crashed during create, the flag is still set on the next launch, and XNNPACK is permanently disabled for that install (`tflite_xnnpack_disabled`).
- **Chipset denylist.** XNNPACK is skipped when device info contains `mt6`, `mt8`, `mediatek`, `helio`, `dimensity`, or `xcover`.
- **Fixed thread count.** Uses `min(2, cores − 1)` threads and never relies on automatic thread-pool sizing.
- **Serialized creates.** Models load one at a time, so parallel loads cannot clear the crash flag while another create is still running.
- **Input shape pinned once.** The tensor is resized and allocated once at load and never again.
- **MiniFASNet always runs on CPU** (`preferXnnpack: false`). XNNPACK on those graphs kept re-logging "Replacing 65 nodes" and cost time mid-session.

### 3.3 Interpreters load once per app process

- `FaceEmbedder` and `MinifasnetFusionEngine` now load a single time. A second load is refused and logged. `dispose()` no longer closes them, because closing mid-session re-applied XNNPACK.
- Inference writes raw bytes directly into the input tensor, calls `invoke()`, and reads the output buffer. This replaces `Interpreter.run` with nested lists and removes the resize and re-allocate on every frame.
- The embedding output buffer is reused. L2 normalisation runs on a `Float32List`.
- Debug logs show `load#` (must stay 1) and the inference count every 50 frames, so QA can confirm there is no reload.

### 3.4 No JPEG on the live path

- Added `TimesheetFaceCaptureService.decodeCameraImage`, which converts YUV or BGRA frames to RGB in memory.
- The old `saveStreamFrameJpeg` is deprecated and logs a warning if called.
- New in-memory entry points:
  - `FacePreprocessor.buildInputTensorFromImage`
  - `FaceRecognitionService.matchImage`
  - `OnDevicePadEvaluator.evaluateFrameSample` / `evaluateImage`
  - `HybridLivenessGate.evaluateStreamFrameSample`
  - `BurstFrameSample` accepts `rgbFrame` or `imagePath`
- The still photo taken at shutter still uses the file path.

### 3.5 Liveness runs at capture time, not on the stream

- MiniFASNet (anti-spoof) no longer runs on live preview frames, on Android or iOS.
- The camera keeps a short in-memory ring of recent frames. At shutter, `_runCaptureTimePadBurst` runs the liveness burst once on that ring.
- Live frames now run only face detection, a quality gate, and one embedding for the name badge.

### 3.6 Face-match rules

| Setting | Before | After |
|---|---|---|
| Match bar (`pilotThreshold`) | 0.22 | **0.15** |
| Soft still accept (when live preview already locked the same employee) | — | 0.15 |
| Minimum live score before auto-shutter | — | 0.15 |
| Name badge bar (`pilotDisplayThreshold`) | — | 0.15 |
| Minimum winner margin (best vs second **employee**) | — | **0.02** |
| Minimum margin to show a name on preview | — | 0.02 |
| "Close second" hint delta | 0.03 | 0.05 |

- The matcher now ranks **unique employees** by their best template score. The runner-up is always a different person.
- `isMatch` now requires the score bar **and** the margin **and** a found employee row.
- `FaceMatchResult` gained `passesDisplayThreshold`, `winnerMargin`, and `hasClearWinnerMargin`.
- `FaceMatchLogger` now logs margin, display pass, and margin pass for every attempt.
- Badge colours: green means matched and on this project's labor list (can be added). Yellow means recognised but **not** on this project's labor list (name only, cannot be added).

### 3.7 Device support and low-end mode (camera panel, `timesheet_capture_camera_panel.dart`)

- **Unsupported device gate.** If the phone has under 4.5 GB RAM or fewer than 6 CPU cores, the camera shows a message with the device model, RAM, and core count, and asks the user to use a newer device.
- **Low-end mode.** Phones with 6.5 GB RAM or less, or 8 cores or fewer, get slower timings to reduce load:

| Timing | Normal | Low-end |
|---|---|---|
| Detect interval once face is steady | 180 ms | 260 ms |
| Detect interval before steady | 280 ms | 380 ms |
| Preview match cooldown (locked person) | 900 ms | 1,100 ms |
| Preview match cooldown (searching) | 550 ms | 800 ms |
| Auto-shutter hold, no auto-capture lock | 420 ms | 520 ms |
| Auto-shutter hold, score under 0.22 | 580 ms | 700 ms |
| Auto-shutter hold, score 0.22–0.28 | 450 ms | 520 ms |
| Auto-shutter hold, strong score | 220 ms | 320 ms |

- Lower scores wait a little longer before the shutter so the still is cleaner.
- **Stale badge.** The name clears after 400 ms with no qualifying match, and clears at once when no face is found or the camera flips.
- The camera is no longer re-initialised mid-session, which had caused visible stalls.

### 3.8 Recent timesheets list (same commit)

- The app now loads Recent and "Show all" timesheets by `project_id` through a new backend route, `POST /api/project/timesheets/list` (Odoo commit `eb1298afd`, 22 September), instead of depending on task-list matching.
- Odoo ids such as `"123.0"` are now parsed as `123` (`TimesheetDefaults.tryParseOdooInt`).
- Backend commit `dcfa6113e` (22 September) restored home-widget hours using the foreman's `x_labor_ids`.

---

## 4. Files changed

**Face recognition core** (`lib/core/site_management/face_recognition/`)

- `tflite_interpreter_factory.dart` (new)
- `domain/face_embedder.dart`, `domain/face_matcher.dart`, `domain/face_preprocessor.dart`
- `face_recognition_service.dart`, `face_recognition_config.dart`, `face_match_logger.dart`
- `data/models/face_match_result.dart`
- `antispoof/minifasnet_fusion_engine.dart`, `antispoof/on_device_pad_evaluator.dart`, `antispoof/hybrid_liveness_gate.dart`, `antispoof/burst_verification_pipeline.dart`

**Timesheet**

- `lib/core/timesheet/services/face_capture_service.dart`
- `lib/core/timesheet/timesheet_defaults.dart`
- `lib/core/timesheet/network/timesheet_api_client.dart`, `timesheet_odoo_api_catalog.dart`
- `lib/core/timesheet/models/timesheet_model_parsers.dart`
- `lib/core/timesheet/providers/timesheet_data_providers.dart`
- `lib/ui/presentation/timesheet/foreman/attendance/timesheet_capture_camera_panel.dart` (+842 / −569 lines changed)
- `lib/ui/presentation/timesheet/foreman/fm_timesheet_submitted_list_screen.dart`

---

## 5. How to verify on a device

1. Open Timesheet capture on a MediaTek or XCover phone. The app must not crash. Logs show `TfliteInterpreterFactory: XNNPACK skipped (chipset denylist)` or `CPU interpreter`.
2. Capture 20 or more workers in one session. Logs for `FaceEmbedder` and `MinifasnetFusionEngine` must stay at `load#1`.
3. No `ts_stream_*.jpg` files are written during live preview.
4. A worker on the project labor list shows a green badge and can be added. A recognised worker who is not on the list shows yellow and cannot be added.
5. On a phone under 4.5 GB RAM or with fewer than 6 cores, the unsupported-device message appears.
6. Recent timesheets on the capture screen list lines submitted on site for that project.

---

## 6. Open points

- **Lower match bar.** Dropping from 0.22 to 0.15 reduces "No Face" for genuine workers but raises the false-match risk. The 0.02 winner margin and the labor-list check are the only guards. Review field logs (`FaceMatchLog`) before tightening or loosening.
- **XNNPACK disabled permanently after one crash.** The only way to re-enable it for an install is to clear app data.
- **`/api/project/timesheets/list` has no auth or project-scope check.** It is listed as critical in the access-rights brief (`doc/SYSTEM_ACCESS-RIGHTS_ANALYSIS_AND_WIDGETS.md`, section 0).

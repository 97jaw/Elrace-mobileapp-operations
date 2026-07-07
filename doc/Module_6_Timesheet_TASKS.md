# Module 6 — Project Site Timesheet | Cursor Task File

> **How to use this file:** Read it top to bottom before touching any code. Then read the companion SRD: `Module_6_Timesheet_SRD.md`. Then start at Task F.0 and work top to bottom. Update task status in §9 as you go. Never skip ahead.

---

## 0. About This Module

You are extending the existing Flutter mobile application `el_race` (Pandora HR Management). The app already has authentication, navigation shell, notifications, attachment handling, a chat module (Firebase-based), HR modules 1-5, and a partial `lib/core/face/face_sdk_service.dart` stub. You are **NOT** building from scratch.

You are adding **Module 6: Project Site Timesheet** as a tile accessible from the existing **HR Management** menu page. This task file covers Module 6 only.

### What this module does

Foremen capture site attendance for laborers using **face recognition** (individual or group photo), tied to a **project task**, GPS-stamped, geofence-checked, offline-capable. Project Managers oversee, review, and approve. Module also exposes per-project chat (reuse existing chat module), site photos, daily site reports, a Gantt view (read-only on mobile in Phase 1), and role-specific dashboards.

### Stack reuse

- **Framework:** Flutter (existing app, version 1.0.16+).
- **Backend (HR / Project):** Odoo 14 ERP via REST APIs (extend `site_report_apis.py`).
- **Backend (Face Recognition):** Firebase Cloud Functions wrapping **AWS Rekognition** (region: `me-central-1`).
- **State Management:** Riverpod (use this — do not introduce other state libraries).
- **HTTP:** Dio.
- **On-device face detection:** `google_mlkit_face_detection` (new dep — add to pubspec).
- **Camera:** `camera` package (already in pubspec).
- **Maps:** `flutter_map` + `latlong2` (already in pubspec).
- **Offline queue:** `hive` + `workmanager` (already in pubspec).
- **Location:** `geolocator` + `geocoding` (already in pubspec).
- **Charts / Gantt:** `fl_chart` + `syncfusion_flutter_gantt` (add to pubspec on demand).
- **PDF:** `pdf` + `syncfusion_flutter_pdf` + `printing` (already in pubspec).
- **Theme:** **NEW** Timesheet palette (lavender + teal). Do NOT use `HrModule*` tokens — they are navy. See SRD §10.
- **Language:** English only (Phase 1).

---

## 1. Critical Rules (NEVER violate these)

| Rule | Reason |
|------|--------|
| **Read the SRD section before coding** | The SRD is the source of truth. Reference section numbers in commits and comments. |
| **Never invent fields** | If a field is not in the SRD, it does not exist. Ask before adding. |
| **Never hardcode colors / strings / spacing** | Use design tokens in `TimesheetModule*`. |
| **Never call AWS Rekognition directly from the app** | All AWS calls go through Firebase Cloud Functions. AWS keys NEVER reach the device. |
| **Reuse shared widgets** | Check `/lib/core/widgets/` and `/lib/core/widgets/timesheet/` BEFORE creating any new widget. |
| **Reuse existing chat module** | Do not rebuild chat — render the existing chat with `roomId = project_<projectId>`. |
| **No `!` (bang) operator** without a justification comment. |
| **Never read raw Odoo state strings** | Always read the normalized `ui_status` / `day_status` fields from API responses. |
| **One task = one commit** | Format: `feat(timesheet): <TASK_ID> <description> — SRD §<section>` |
| **Empty / Loading / Error states are mandatory** on every list, detail, and dashboard screen. |
| **Mock first, integrate later** | Mock all Odoo endpoints and Cloud Functions for Phase 1. Tag with `// TODO(backend)`. |
| **Camera permissions before camera open** | Always request `Permission.camera` + `Permission.location` before opening a capture screen, with friendly explanatory dialog. |
| **Face crops must pass quality gate** before queueing for match. Reject and prompt foreman to retake otherwise. |

---

## 2. Roles & View Selection

The login API response provides booleans:

| Boolean Flag | View | Scope |
|------|------|-------|
| `is_pm` | Project Manager | All owned projects |
| `is_hr_manager` | PM (read-only company-wide) | All projects |
| `is_foreman` (NEW) | Foreman | Projects/tasks assigned to self |
| none | Foreman by default if assigned, else PM read-only | — |

If both `is_pm` and `is_foreman` are true → **`is_pm` takes precedence** (and `is_hr_manager` over both for PM-wide scope). See SRD §1.3.

---

## 3. ⚠️ DEVELOPMENT-ONLY: Role Toggle Requirement

> **READ THIS CAREFULLY — this saves the architect's testing time.**

**Product decision:** Login will eventually expose **`is_foreman`**, **`is_pm`**, **`is_hr_manager`** (and any other flags Odoo already sends). **Until release**, you need **full access to every Timesheet role** without re-login or waiting on backend.

On the **Timesheet widget entry point**, place **temporary toggle icons** (in `kDebugMode` only):

- 👷 **Foreman** → forces Foreman shell (FM1 home).
- 🧑‍💼 **PM** → forces Project Manager shell (PM1 home, project-scoped mock data).
- 💼 **HR Manager** *(recommended)* → same PM shell but sets a **`tmDevHrWideScopeProvider = true`** (or equivalent) so lists/mock APIs return **company-wide** data (mirrors `is_hr_manager` behaviour in SRD §1.3).
- ↻ **Reset** → clears all overrides; effective role falls back to **login booleans** (dynamic condition — what ships in production).

**Behaviour:**
- Icons appear **only in `kDebugMode`**.
- Overrides persist for the **current session** only (or until Reset).
- Place icons top-right on the Timesheet entry / root scaffold.
- Style: small circular icons, subtle background.

**Final release behaviour:** Remove the toggle bar entirely. Effective role = **only** `is_hr_manager` / `is_pm` / `is_foreman` from login (precedence per SRD §1.3). Add removal TODO:

```dart
// TODO(release): Remove dev role toggle. Replace with dynamic role
// detection from login API booleans (is_hr_manager, is_pm, is_foreman).
// Reference: Module 6 TASKS.md §3.
```

This toggle is mandatory. Implement it as part of Task **F.5** below.

---

## 4. Design System (use these tokens — never hardcode)

Tokens live in `/lib/core/theme/timesheet_module_*.dart`. Naming prefix: `TimesheetModule*`. **Never mix with `HrModule*` (which is navy `#1F3A5F` for Modules 1-5).** Module 6 uses a NEW palette per SRD §10.

### 4.1 Colors — `timesheet_module_colors.dart`

| Token | Hex | Usage |
|-------|-----|-------|
| primary | `#0FB5A6` | CTA, active chip, FAB, progress fill |
| primaryGradientStart | `#16C0A8` | Gradient top |
| primaryGradientEnd | `#0A8F84` | Gradient bottom |
| primaryTint | `#E6F7F4` | Icon tile bg, progress bar bg |
| bgGradientStart | `#F2EEF7` | App bg top (lavender) |
| bgGradientEnd | `#EFF1F8` | App bg bottom |
| surface | `#FFFFFF` | Card surface |
| text | `#13192B` | Body / titles |
| mutedText | `#7A8194` | Captions, hints |
| divider | `#ECEEF3` | Outlines, dividers |
| success | `#22C29A` | Checked-in, on-track |
| warning | `#F5B544` | Late, needs review |
| danger | `#EF5C5C` | Absent, rejected |
| info | `#5B8DEF` | Info banners |

### 4.2 Attendance status colors — `timesheet_attendance_status_colors.dart`

| Status | Bg | Text/Icon |
|--------|----|-----------|
| CHECKED_IN | `#DFF6EF` | `#22C29A` |
| CHECKED_OUT | `#E6F7F4` | `#0FB5A6` |
| LATE | `#FFF1D6` | `#F5B544` |
| ABSENT | `#FBE2E2` | `#EF5C5C` |
| MANUAL | `#E4E8FA` | `#5B8DEF` |
| OUTSIDE_GEOFENCE | `#FBE2E2` | `#EF5C5C` |
| PENDING_SYNC | `#ECEEF3` | `#7A8194` |

Mobile reads `ui_status` from the API response. Mobile NEVER computes status.

### 4.3 Typography — `timesheet_module_typography.dart`

Font: **Inter** via `google_fonts` (already in pubspec).

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| display | 22 sp | w700 | Greeting, screen titles |
| h1 | 20 sp | w700 | Hero card titles |
| h2 | 16 sp | w600 | Section headers |
| cardTitle | 15 sp | w600 | Task / project names |
| body | 14 sp | w500 | Default body |
| caption | 12 sp | w500 | Timestamps, metadata |
| statValue | 22 sp | w700 | KPI tile numbers |
| statLabel | 12 sp | w500 | KPI tile labels |
| button | 15 sp | w600 | Buttons |

### 4.4 Spacing & layout — `timesheet_module_layout.dart`

| Token | Value |
|-------|-------|
| screenPaddingH | 20 dp |
| cardPadding | 16 dp |
| sectionGap | 24 dp |
| cardSpacing | 12 dp |
| cardRadiusLg | 20 dp |
| cardRadiusMd | 16 dp |
| cardRadiusSm | 12 dp |
| chipHeight | 36 dp |
| buttonHeight | 56 dp |
| progressBarHeight | 6 dp |
| iconTileSize | 32 dp |
| avatarSize | 28 dp / 44 dp |

### 4.5 Shadows — `timesheet_module_shadows.dart`

| Token | Spec |
|-------|------|
| cardShadow | `BoxShadow(color: Color(0x0F14182F), offset: Offset(0,8), blurRadius: 24)` |
| fabShadow | `BoxShadow(color: Color(0x590FB5A6), offset: Offset(0,12), blurRadius: 24)` |

### 4.6 Iconography

`phosphor_flutter` (already in pubspec). 1.5-1.75 px stroke. Tinted icon tile = `primary` on `primaryTint` background.

### 4.7 Bottom nav

White surface, top-corner radius 16 dp, top shadow, 5 slots, center FAB (teal gradient, raised 16 dp). Active slot icon+label in `primary`, inactive in `mutedText`.

---

## 5. Folder Structure

Follow the convention used by HR Module 1. Naming prefix: `Tm` for widgets, `Timesheet` for everything else.

```
lib/
  core/
    theme/
      timesheet_module_colors.dart
      timesheet_module_typography.dart
      timesheet_module_layout.dart
      timesheet_module_shadows.dart
      timesheet_attendance_status_colors.dart
      timesheet_module_theme.dart            ← barrel
    timesheet/
      models/
        project.dart
        task.dart
        worker.dart
        attendance_record.dart
        site_photo.dart
        site_report.dart
      network/
        timesheet_api_envelope.dart
        timesheet_api_client.dart            ← Odoo bridge (mocked Phase 1)
        timesheet_functions_client.dart      ← Firebase callables
      providers/
        timesheet_role_provider.dart
        projects_provider.dart
        tasks_provider.dart
        attendance_provider.dart
        capture_queue_provider.dart
        live_location_provider.dart
      services/
        face_capture_service.dart            ← wraps ML Kit + camera
        capture_queue_service.dart           ← Hive queue + workmanager
        geofence_service.dart
      routing/
        timesheet_route_names.dart
    widgets/
      timesheet/
        tm_scaffold.dart
        tm_greeting_header.dart
        tm_search_field.dart
        tm_filter_chip_row.dart
        tm_stat_tile.dart
        tm_project_card.dart
        tm_task_row.dart
        tm_progress_bar.dart
        tm_section_header.dart
        tm_primary_button.dart
        tm_secondary_button.dart
        tm_bottom_nav_bar.dart
        tm_avatar_stack.dart
        timesheet_widgets.dart               ← barrel
  ui/
    presentation/
      timesheet/
        foreman/
          fm1_foreman_dashboard.dart
          fm_projects_list.dart
          fm2_project_detail.dart
          fm3_task_detail.dart
          attendance/
            at1_capture_mode_sheet.dart
            at2_individual_camera.dart
            at3_group_camera.dart
            at4_capture_summary.dart
          site_photos_gallery.dart
          site_photo_viewer.dart
          daily_site_report_form.dart
        pm/
          pm1_dashboard.dart
          pm2_project_detail.dart
          pm_worker_enrol.dart
          pm_attendance_review.dart
          pm_gantt_view.dart
        timesheet_menu_tile.dart             ← entry tile on HR Management menu
        timesheet_dev_role_toggle_bar.dart   ← kDebugMode only

functions/
  index.js                                    ← add: enrollWorkerFace,
                                                       matchAttendance,
                                                       deleteWorkerFace,
                                                       (post-system-message: Phase 2)
```

---

## 6. Module Roadmap

### Build order (do NOT skip ahead)

| Phase | Tasks | Why this order |
|-------|-------|----------------|
| **Foundation (F)** | F.0 → F.10 | Tokens, widgets, role provider, routing, camera service, Cloud Functions skeleton |
| **Foreman (FM)** | FM1 → FM-PL → FM2 → FM3 | Dashboard → list → detail → task entry to attendance |
| **Attendance (AT)** | AT1 → AT2 → AT3 → AT4 | Capture-mode sheet → individual → group → summary |
| **Enrolment (EN)** | EN1 | Worker enrolment with face capture |
| **PM Screens (PM)** | PM1 → PM2 → PM-AR | PM dashboard → project detail (ext) → attendance review |
| **Module extras (X)** | X-Photos → X-Report → X-Gantt → X-Live | Site photos, daily report, Gantt, live tracking |
| **Polish (P)** | P1 → P3 | Offline polish, accessibility, sign-off |

### Module screens summary (from SRD)

| ID | Screen | SRD Section | Audience |
|----|--------|-------------|----------|
| FM1 | Foreman Dashboard | §2.1 | Foreman |
| FM-PL | Projects List | §2.2 | Foreman |
| FM2 | Project Detail | §2.3 | Foreman |
| FM3 | Task Detail (entry to Attendance) | §2.4 | Foreman |
| AT1 | Capture Mode Bottom Sheet | §3.1 | Foreman |
| AT2 | Camera (Individual) | §3.2 | Foreman |
| AT3 | Camera (Group) | §3.3 | Foreman |
| AT4 | Capture Result Summary | §3.4 | Foreman |
| EN1 | Worker Enrolment | §12.3 | Foreman / PM |
| PM1 | PM Dashboard | §12.1 | PM |
| PM2 | Project Detail (PM extended) | §12.2 | PM |
| PM-AR | Attendance Review | §12.2 | PM |
| X-Photos | Site Photos gallery | §7 | Foreman / PM |
| X-Report | Daily Site Report | §8 | Foreman / PM |
| X-Gantt | Gantt View | §9 | Foreman (read) / PM |
| X-Live | Live Location toggle + map | §5.3 | Foreman / PM |

---

## 7. Functional Knowledge

### 7.1 Threshold logic (SRD §4.2)

| Similarity | App action |
|-----------|------------|
| ≥ 95 % | Auto-mark present. Toast confirms. |
| 90-94.99 % | Inline modal: "Confirm Yes/No". |
| < 90 % | Modal: "Retry / Manual select / Skip". |

### 7.2 Task-scoped matching (SRD §4.4)

After Rekognition returns `worker_id`, the Cloud Function checks
membership against the task's `worker_ids[]`:

- In list → write attendance.
- Not in list → return `task_membership: false`. App shows modal:
  Mark anyway / Add to task (PM only) / Reject.

### 7.3 Event determination (checkIn vs checkOut)

Computed by the app at capture time based on existing attendance records
for the worker × task × date:

| Existing today | Next event |
|----------------|-----------|
| 0 records | checkIn |
| checkIn only | checkOut |
| checkIn + checkOut | checkIn (shift_index = 2) |
| checkIn + checkOut + checkIn | checkOut (shift_index = 2) |

### 7.4 Geofence check

- Project geofence = circle (center_lat, center_lon, radius_m).
- Cloud Function computes haversine distance; sets
  `outside_geofence = true` if outside.
- App does NOT compute this itself — it only displays the flag.

### 7.5 Counter logic (FM1 dashboard)

| Counter | Logic |
|---------|-------|
| Projects | Distinct projects with `assigned_foreman = self`. |
| Tasks | Today's tasks (`planned_start ≤ today ≤ planned_end`) for self. |
| Teams | Distinct workers across all assigned tasks today. |

### 7.6 Today's Tasks (FM1)

Sorted by `planned_start ASC`. Status pill: PLANNED (grey) / IN_PROGRESS (teal) / BLOCKED (warning) / DONE (success outline).

### 7.7 PM alerts (PM1)

Surface as a stack of cards, dismissible per-session:

- Records with `outside_geofence = true` (last 24 h).
- Records with `manual_override = true` (last 24 h).
- Foremen with unsubmitted daily site report (project where attendance was captured today but no report exists).
- Worker matches < 92 % for 3 consecutive captures (re-enrol suggested).

---

## 8. API Conventions

### 8.1 Odoo bridge (extend `site_report_apis.py`)

All endpoints follow the existing envelope:

```json
{ "success": true, "data": { ... }, "error": null, "ui_status": "OK" }
```

Endpoints used by mobile (mocked in Phase 1):

- `GET /api/timesheet/projects?role=foreman` → list.
- `GET /api/timesheet/projects/{id}` → detail + geofence.
- `GET /api/timesheet/projects/{id}/tasks?foreman_id=…` → tasks.
- `GET /api/timesheet/tasks/{id}` → task + worker list.
- `POST /api/timesheet/workers` → create worker (PM).
- `GET /api/timesheet/attendance?project_id=…&date=…` → PM review list.
- `POST /api/timesheet/reports` → daily site report.

Endpoints called only from Cloud Function (server-to-server):

- `POST /api/timesheet/attendance` → write attendance record.
- `POST /api/timesheet/workers/{id}/face` → store `face_id` after enrolment.

### 8.2 Firebase callable functions (mobile → Cloud Function)

- `enrollWorkerFace({ worker_id, project_id, photo_urls[] })` → `{ success, face_id }`.
- `matchAttendance({ project_id, task_id, crop_url, lat, lon, event })` →
  `{ result: 'matched' | 'needs_confirmation' | 'no_match', similarity, worker_id?, attendance_id?, outside_geofence, task_membership? }`.
- `deleteWorkerFace({ worker_id, project_id })` → PM only.

### 8.3 Mock-first

Wire `TimesheetApiClient` and `TimesheetFunctionsClient` with deterministic mock responses for all endpoints. Mark each call site:

```dart
// TODO(backend): Replace mock with actual call.
// Endpoint TBD. See Module 6 SRD §14.x.
```

### 8.4 Error handling

- 401 → existing app auth flow re-login.
- 4xx → toast `response.error`.
- 5xx → "Something went wrong" + retry.
- Cloud Function exceptions → standard `FirebaseFunctionsException` handling.

---

## 9. Tasks (work top to bottom)

> **Status legend:** `[TODO]` `[IN_PROGRESS]` `[DONE]` `[BLOCKED]` `[NEEDS_REVIEW]`
>
> Update this section as you complete each task.

---

### Phase 0 — Foundation

#### `[DONE]` F.0 — Verify project setup & add new deps
- Confirm `pubspec.yaml` already has: `flutter_riverpod`, `dio`, `fl_chart`, `camera`, `hive`, `workmanager`, `geolocator`, `geocoding`, `flutter_map`, `latlong2`, `phosphor_flutter`, `google_fonts`, `firebase_storage`, `cloud_firestore` — **all present**.
- **Add new deps:** `google_mlkit_face_detection: ^0.13.0` (verify latest), `syncfusion_flutter_gantt` (if not present).
- Run `flutter pub get`.
- Note: `syncfusion_flutter_gantt` was verified unavailable on pub.dev; no substitute was added pending product/package confirmation.
- **Definition of done:** `flutter analyze` passes.

#### `[DONE]` F.1 — Design tokens (SRD §10)
- Create files under `lib/core/theme/`:
  - `timesheet_module_colors.dart`
  - `timesheet_module_typography.dart` (Inter via `google_fonts`)
  - `timesheet_module_layout.dart`
  - `timesheet_module_shadows.dart`
  - `timesheet_attendance_status_colors.dart`
  - `timesheet_module_theme.dart` (barrel)
- **Naming:** prefix everything `TimesheetModule` (avoid clashing with `HrModule`).
- **Definition of done:** Tokens available via static getters; importable from a single barrel.

#### `[DONE]` F.2 — Shared widgets sandbox
- Implement under `/lib/core/widgets/timesheet/` with `Tm` prefix:
  - `TmScaffold` (lavender gradient bg + safe area, slot for bottom nav).
  - `TmGreetingHeader` (avatar, greeting, bell).
  - `TmSearchField` (pill, 48 dp, debounced 300 ms).
  - `TmFilterChipRow` + `TmFilterOption`.
  - `TmStatTile`.
  - `TmProjectCard`.
  - `TmTaskRow` (with `TmAvatarStack` slot).
  - `TmProgressBar`.
  - `TmSectionHeader`.
  - `TmPrimaryButton`, `TmSecondaryButton`.
  - `TmBottomNavBar` (with center FAB).
  - `TmAvatarStack`.
  - Barrel: `timesheet_widgets.dart`.
- Build a `TimesheetWidgetsSandbox` screen (debug only) opened from a "F.2 widget sandbox" entry on the Timesheet menu tile.
- **Definition of done:** All widgets render in sandbox using `TimesheetModule*` tokens only.
- **Commit:** `feat(timesheet): F.2 shared widgets — SRD §10`

#### `[DONE]` F.3 — Models
- Create plain Dart models with `fromJson` / `toJson` under `/lib/core/timesheet/models/`:
  - `Project` (id, name, code, client, start, end, status, address, hero_image_url, progress_pct, budget_min, budget_max, geofence_lat, geofence_lon, geofence_radius_m, pm_id, foreman_ids, chat_room_id).
  - `Task` (id, project_id, name, description, planned_start, planned_end, status, percent_complete, assigned_foreman_id, worker_ids).
  - `Worker` (id, project_id, name, trade, contact, hourly_rate, status, face_id, ref_photo_urls).
  - `AttendanceRecord` (full schema per SRD §3.6 + sync_state).
  - `SitePhoto` (id, project_id, foreman_id, ts, category, caption, lat, lon, storage_url).
  - `SiteReport` (id, project_id, date, weather, manpower, work_performed, issues, materials, equipment, photo_urls, signature_url, pdf_url, ui_status).
- **Definition of done:** All models compile, freezed/equatable not required (use plain Dart).
- **Commit:** `feat(timesheet): F.3 models — SRD §13`

#### `[DONE]` F.4 — Networking layer (mock-first)
- `lib/core/timesheet/network/timesheet_api_envelope.dart` — generic envelope (matches HR pattern).
- `lib/core/timesheet/network/timesheet_api_client.dart` — Dio client with mock responses for all Odoo endpoints (SRD §14.1). Each call site annotated `// TODO(backend)`.
- `lib/core/timesheet/network/timesheet_functions_client.dart` — Firebase callable wrapper for `enrollWorkerFace`, `matchAttendance`, `deleteWorkerFace`. Mock with deterministic delays + sample matched/needs_confirmation/no_match responses.
- **Definition of done:** Sandbox button "F.4 mock match" returns a fake match result.
- **Commit:** `feat(timesheet): F.4 networking layer — SRD §14`

#### `[DONE]` F.5 — Role provider + Dev role toggle ⚠️ CRITICAL
- `lib/core/timesheet/providers/timesheet_role_provider.dart`:
  - Enum `TimesheetEffectiveRole { foreman, pm }`.
  - `tmDevRoleOverrideProvider` (foreman | pm | null).
  - `tmDevHrWideScopeProvider` (bool) — when true, PM mock/API uses company-wide scope (simulates `is_hr_manager`).
  - `tmEffectiveRoleProvider` — **dev:** override wins; **prod / reset:** `is_hr_manager` → PM+wide, `is_pm` → PM+owned, `is_foreman` → foreman, else default.
- `lib/ui/presentation/timesheet/timesheet_dev_role_toggle_bar.dart` — `kDebugMode` only: Foreman, PM, HR (wide), Reset.
- Add the toggle bar to the Timesheet entry point. Include `TODO(release)` marker.
- **Definition of done:** Toggle switches between Foreman / PM views without restarting the app.
- **Commit:** `feat(timesheet): F.5 role provider and dev toggle — SRD §11`

#### `[DONE]` F.6 — Routing
- `lib/core/timesheet/routing/timesheet_route_names.dart` — all routes in SRD §11.4.
- Add entries to `lib/utils/generated_routes.dart`.
- Wire role-routed `home` → FM1 or PM1.
- **Definition of done:** All named routes resolve to placeholder screens.
- **Commit:** `feat(timesheet): F.6 routing — SRD §11.4`

#### `[DONE]` F.7 — Face capture service (ML Kit + camera wrapper)
- `lib/core/timesheet/services/face_capture_service.dart`:
  - Wraps `camera` package + `google_mlkit_face_detection`.
  - Real-time detection stream with quality gate (size, pose, eyes, sharpness).
  - Crop function (224 × 224) with face padding.
  - Liveness prompt helper (head turn / blink detection).
- Reuse / extend existing `lib/core/face/face_sdk_service.dart` if applicable; do NOT duplicate.
- **Definition of done:** Sandbox screen `F.7 face capture` shows preview with green box and emits a sample crop on shutter.
- **Commit:** `feat(timesheet): F.7 face capture service — SRD §4.1`

#### `[DONE]` F.8 — Capture queue service (Hive + workmanager)
- `lib/core/timesheet/services/capture_queue_service.dart`:
  - Hive box `timesheet_capture_queue` storing `AttendanceCaptureDraft` items (with crop bytes / local path).
  - Method `enqueue(draft)`, `drain()`, `markSynced(id)`, `markFailed(id, err)`.
- Register a workmanager task `timesheet_sync_drain` that runs every 5 min when online (priority: captures → photos → reports).
- **Definition of done:** Captures persist across app restarts; drain runs in foreground + background.
- **Commit:** `feat(timesheet): F.8 capture queue and sync — SRD §15`

#### `[DONE]` F.9 — Geofence service
- `lib/core/timesheet/services/geofence_service.dart` with helper `isInsideCircle(point, center, radiusM)` (haversine).
- App uses this only for **previewing** the foreman's distance from geofence in the camera screen (label "12 m inside fence" or "85 m outside fence"). Authoritative check is on the Cloud Function.
- **Definition of done:** Unit tests cover inside / outside / edge / no-GPS-lock cases.
- **Commit:** `feat(timesheet): F.9 geofence helper — SRD §5.2`

#### `[DONE]` F.10 — Cloud Functions skeleton (Phase 1 stubs)
- In `functions/index.js`, add three new callable functions (return deterministic mock responses for now; real AWS wiring lands in EN1 / AT2 backend tasks):
  - `enrollWorkerFace` → returns `{ success: true, face_id: 'mock_${worker_id}' }`.
  - `matchAttendance` → returns one of three canned responses based on a request hash so testing is repeatable.
  - `deleteWorkerFace` → returns `{ success: true }`.
- Add a region setter at the top: `setGlobalOptions({ region: 'me-central-1' })`.
- Wire IAM placeholder env vars `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (read but unused in Phase 1).
- **Definition of done:** `firebase emulators:start --only functions` runs and returns from each callable.
- **Commit:** `feat(timesheet): F.10 cloud functions skeleton — SRD §4 §14.2`

---

### Phase 1 — Foreman Screens

#### `[DONE]` FM1 — Foreman Dashboard
- **SRD section:** §2.1
- Read SRD §2.1 in full.
- Build `fm1_foreman_dashboard.dart` using `TmScaffold` + shared widgets.
- States: loading (skeleton), empty ("No projects assigned"), error (retry banner).
- Stat tiles tappable (drill to filtered lists).
- FAB → quick action sheet (Take Attendance / Capture Photo / New Report).
- Today's Tasks list → tap → FM3.
- Active Project card → tap → FM2.
- Place dev role toggle bar (F.5) in AppBar actions area (debug only).
- **Definition of done:** All states render with mock data. Bottom nav active = Home.
- **Commit:** `feat(timesheet): FM1 foreman dashboard — SRD §2.1`

#### `[DONE]` FM-PL — Projects List
- **SRD section:** §2.2
- Reuses `TmSearchField` + `TmFilterChipRow` + `TmProjectCard`.
- Tap → FM2.
- **Commit:** `feat(timesheet): FM-PL projects list — SRD §2.2`

#### `[DONE]` FM2 — Project Detail
- **SRD section:** §2.3
- Hero image + name + address + tabs (Overview / Tasks / Files / Teams).
- Overview: progress vs budget, Today's Tasks, Site Photos thumbnails (loaded via X-Photos provider once built; placeholder in Phase 1).
- Tasks: full task list filtered to this foreman, status-grouped.
- Files: list of submitted reports (placeholder until X-Report).
- Teams: read-only worker list.
- Overflow menu: Open Chat, View Geofence, Project Info.
- **Commit:** `feat(timesheet): FM2 project detail — SRD §2.3`

#### `[DONE]` FM3 — Task Detail (entry to Attendance)
- **SRD section:** §2.4
- Header pill = task status. Worker list with leading status dot. `0 / N today` counter (live from `attendanceProvider`).
- **Take Attendance** primary button → AT1 bottom sheet.
- Tap worker row → "Capture for [worker]" shortcut → AT2 individual mode pre-targeted.
- **Commit:** `feat(timesheet): FM3 task detail — SRD §2.4`

---

### Phase 2 — Attendance Capture

#### `[TODO]` AT1 — Capture Mode Bottom Sheet
- **SRD section:** §3.1
- Two large cards: Individual / Group. Persist last choice per device in `SharedPreferences`.
- **Commit:** `feat(timesheet): AT1 capture mode sheet — SRD §3.1`

#### `[TODO]` AT2 — Camera (Individual)
- **SRD section:** §3.2
- Camera preview (front camera default), live face detect overlay (green box on pass).
- Quality guidance label dynamic.
- Random liveness prompt before shutter enable.
- Shutter → crop → enqueue → background match → toast result.
- Header counter `X/N captured`. Switch to Group link in header.
- **Commit:** `feat(timesheet): AT2 individual camera — SRD §3.2 §4`

#### `[TODO]` AT3 — Camera (Group)
- **SRD section:** §3.3
- Multi-face overlay (green = pass / amber = too small). Counter "N faces detected".
- Shutter → fan-out (max 5 concurrent) → AT4.
- **Commit:** `feat(timesheet): AT3 group camera — SRD §3.3 §4.3`

#### `[TODO]` AT4 — Capture Result Summary
- **SRD section:** §3.4
- List of results with similarity %. Inline action chips for needs_confirmation / no_match.
- "Continue Capturing" returns to AT2/AT3. "Done" returns to FM3.
- **Commit:** `feat(timesheet): AT4 capture summary — SRD §3.4`

---

### Phase 3 — Enrolment + PM Screens

#### `[DONE]` EN1 — Worker Enrolment (Foreman / PM)
- **SRD section:** §12.3, §4.5
- Form fields + 3-photo capture with quality gate per photo.
- On Save: upload to Storage → call `enrollWorkerFace` → store returned `face_id` on worker (via Odoo bridge).
- **Commit:** `feat(timesheet): EN1 worker enrolment — SRD §4.5 §12.3`

#### `[DONE]` PM1 — PM Dashboard
- **SRD section:** §12.1
- Today summary (Present / Late / Absent), My Projects horizontal list, Alerts stack, Map View with `flutter_map`.
- **Commit:** `feat(timesheet): PM1 dashboard — SRD §12.1`

#### `[DONE]` PM2 — Project Detail (PM extended)
- **SRD section:** §12.2
- Same as FM2 + extra **Attendance Review** tab.
- **Commit:** `feat(timesheet): PM2 project detail — SRD §12.2`

#### `[DONE]` PM-AR — Attendance Review
- **SRD section:** §12.2
- Day picker, summary chips, flagged record detail (photo, similarity, GPS pin, foreman name, Approve / Reject).
- **Commit:** `feat(timesheet): PM-AR attendance review — SRD §12.2`

---

### Phase 4 — Module Extras

#### `[DONE]` X-Photos — Site Photos
- **SRD section:** §7
- Capture screen with watermark overlay. Gallery grid, filter chips, viewer.
- **Commit:** `feat(timesheet): X-Photos site photos — SRD §7`

#### `[DONE]` X-Report — Daily Site Report
- **SRD section:** §8
- Single template form, photo attach, signature pad. PDF export with emp_id watermark (reuse `pdf_watermark.dart`).
- **Commit:** `feat(timesheet): X-Report daily site report — SRD §8`

#### `[DONE]` X-Gantt — Gantt View
- **SRD section:** §9
- Phone portrait: list. Landscape / tablet: `syncfusion_flutter_gantt`. Read-only on mobile; PM can update percent_complete / status only.
- **Commit:** `feat(timesheet): X-Gantt gantt view — SRD §9`

#### `[DONE]` X-Live — Live Location & Map
- **SRD section:** §5.3
- Foreman toggle on FM1 dashboard. Heartbeat writer (60 s foreground, 300 s background).
- PM map pins (live), stale fade after 10 min.
- **Commit:** `feat(timesheet): X-Live live location — SRD §5.3`

#### `[DONE]` X-Chat — Per-Project Chat
- **SRD section:** §6
- FM2 / PM2 overflow → Open Chat. Pass `roomId = project_<projectId>` to existing chat module.
- **Commit:** `feat(timesheet): X-Chat per-project chat — SRD §6`

---

### Phase 5 — Polish & Sign-off

#### `[DONE]` P1 — Offline polish
- "N pending sync" badge on FM1 visible & accurate.
- Per-row sync state (PENDING_SYNC / SYNCED / FAILED).
- Manual retry from FM1 "Pending" drawer.
- **Commit:** `chore(timesheet): P1 offline polish`

#### `[TODO]` P2 — Accessibility & high-brightness mode
- Minimum tap target 44 × 44 dp.
- High-brightness toggle (manual on FM1 settings + auto based on `Light` sensor when available) → switches bg to pure white and bumps contrast.
- **Commit:** `chore(timesheet): P2 accessibility & high-brightness`

#### `[TODO]` P3 — Performance & sign-off
- Verify perf targets (SRD §16). Profile camera FPS. Profile cold start. Profile sync drain.
- Final SRD walkthrough with architect.
- **Commit:** `chore(timesheet): P3 perf & sign-off`

---

## 10. Module entry point — how to expose Timesheet

- Add a new tile **"Project Site Timesheet"** to the existing HR Management menu page (find it via grep on `HrManagementMenu` / `hr_management_menu_page.dart`).
- Tile uses the Timesheet palette (mint icon tile, navy label).
- Tap → `Navigator.pushNamed(TimesheetRouteNames.home)`.
- Place dev role toggle bar (F.5) inside the Timesheet entry screen's AppBar.

---

## 11. Backend bridge — what site_report_apis.py needs

Backend team should implement (or stub) endpoints listed in §8.1 + the server-to-server endpoints that the Cloud Function calls. Cloud Function authenticates to Odoo using a service token stored in Firebase Function config:

```
firebase functions:config:set odoo.base_url="https://erp.example.com" odoo.token="<token>"
```

---

## 12. Removal markers (production cleanup checklist)

- Remove dev role toggle (§3).
- Remove mock-first markers (`// TODO(backend)` once endpoints are wired).
- Remove debug sandbox screens.
- Switch Cloud Function `matchAttendance` from canned to real AWS calls.
- Verify Storage rules scope `timesheet/*` correctly.

---

## 13. Open items (decision needed before merge)

1. ~~New `is_foreman` boolean~~ — **Confirmed**; prod uses dynamic login flags only (§2 §11).
2. New design palette vs aligning with Module 1 navy — confirm.
3. AWS region `me-central-1` vs `me-south-1` — confirm.
4. Threshold values 95 / 90 — confirm.
5. Background live-location tracking opt-in default — confirm.

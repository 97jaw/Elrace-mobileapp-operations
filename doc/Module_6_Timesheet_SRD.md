**HR MANAGEMENT MOBILE APPLICATION**

**Module 6: Project Site Timesheet (Face-Recognized Attendance)**

*Software Requirements Specification*

  ----------------------- ----------------------- -----------------------
  ----------------------- ----------------------- -----------------------

  -----------------------------------------------------------------------
  **Field**               **Detail**
  ----------------------- -----------------------------------------------
  Project                 HR Management Mobile Application (el_race)

  Module                  Module 6 --- Project Site Timesheet

  Backend (HR / Project)  Odoo 14 ERP (hr.employee, project.project,
                          project.task) + custom site_report APIs

  Backend (Face Recog.)   Firebase Cloud Functions wrapping AWS
                          Rekognition (region: me-central-1, Dubai)

  Frontend                Flutter (existing app, widget integration)

  Document Type           Software Requirements Specification (SRD)

  Version                 1.0

  Prepared By             Pandora Tech LLC

  Audience                Mobile Development Team

  Phase                   Phase 1 --- Layout, Capture & Recognition

  Approach                Option C --- Best-judgment defaults with
                          flagged assumptions
  -----------------------------------------------------------------------

**1. Document Overview**

**1.1 Purpose**

This document defines the design, layout, and behavioural requirements
for the **Project Site Timesheet** module within the el_race HR
Management mobile application. The module enables **Foremen** to capture
site-attendance for laborers using face recognition (individual or group
photo), tied to project tasks, GPS-stamped and geofence-checked, and
provides **Project Managers** with oversight, review, and approval
tooling. It also exposes per-project chat (via the existing chat
module), site photos, site reports/inspections, a Gantt view, and
role-specific dashboards.

**1.2 Scope**

  -----------------------------------------------------------------------
  **Aspect**              **Phase 1 Position**
  ----------------------- -----------------------------------------------
  **In Scope**            Project list / detail / tasks for Foreman and
                          PM. Worker enrolment with face capture. Task-
                          scoped attendance capture in two modes
                          (individual + group). On-device face
                          detection + quality gate + crop. Cloud face
                          match via AWS Rekognition (me-central-1).
                          GPS capture + geofence flag. Offline capture
                          queue with background sync. Per-project chat
                          (re-uses existing chat module). Site photos.
                          Daily site report (single template). Gantt
                          read-only on mobile (PM-editable later).
                          Foreman + PM dashboards.

  **Out of Scope**        Laborer self-service login (laborers are
                          records, not users). Payroll calculation
                          inside this module (CSV export only).
                          Multiple inspection templates (Phase 4).
                          Drag-to-reschedule Gantt on mobile (PM web
                          continues to own this in Phase 1). AWS
                          Face Liveness (Phase 4 upgrade --- light
                          prompt-based liveness in Phase 1). RTL/Arabic
                          (inherits from foundation; Phase 1 EN-only).

  **Backend Source**      Odoo 14 (hr.employee, project.project,
                          project.task, site_report_apis.py) for project
                          / worker / task data. **Firebase Cloud
                          Functions** wrapping AWS Rekognition for face
                          enrolment + matching. **Firebase Storage** for
                          audit images + reference photos. **Firestore**
                          only for: ephemeral live-location heartbeats,
                          chat (existing), offline capture queue mirror.

  **Theme / Auth /        Inherits from foundation: light theme, English
  Notifications /         only, online-capture-friendly with offline
  Connectivity /          queue, EN. Module has a **distinct design
  Language**              palette** (soft lavender background + teal
                          primary) from the rest of the app --- see §10
                          for the full design token table for this
                          module.

  **Liveness**            Phase 1: light prompt-based (random head-turn
                          / blink) + ML Kit signals. Phase 4 upgrade:
                          AWS Rekognition Face Liveness on individual
                          mode (group mode stays prompt-based).
  -----------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| This module uses a **new visual palette** (lavender background +      |
| teal/mint primary) that intentionally differs from Module 1-5's       |
| navy `#1F3A5F` palette. The tokens live in `TimesheetModule*` files   |
| and never touch `HrModule*`. If the architect prefers to align with   |
| Module 1's existing navy palette, flag now and we'll reconcile.       |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| AWS region is **me-central-1 (UAE / Dubai)**. If Rekognition is not   |
| GA in me-central-1 at integration time, fall back to **me-south-1    |
| (Bahrain)**. The Cloud Function code reads the region from a runtime  |
| config so the swap is one env-var change.                             |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| Laborers do **not** log into the app. They are records owned by a     |
| project + assigned to one or more tasks. Only Foreman and Project     |
| Manager are app users for this module. If laborer self-service is    |
| required (view own attendance, hours, payslips), flag for a separate  |
| sub-module.                                                           |
+-----------------------------------------------------------------------+

**1.3 Roles & View Selection**

The login API response continues to provide existing booleans. For this
module:

  -----------------------------------------------------------------------
  **Role Flag**           **View Rendered**       **Visibility Scope**
  ----------------------- ----------------------- -----------------------
  `is_foreman` (NEW)      Foreman View            Projects + tasks
                                                  assigned to this
                                                  foreman. Can capture
                                                  attendance, upload
                                                  site photos, file
                                                  daily report.

  `is_pm` (existing)      Project Manager View    All projects owned
                                                  (`pm_id == self`).
                                                  Full CRUD on
                                                  projects, tasks,
                                                  workers, geofences;
                                                  read all attendance;
                                                  approve overrides.

  `is_hr_manager`         PM View (extended)      All projects
  (existing)                                      company-wide
                                                  (read-only on
                                                  Timesheet).
  -----------------------------------------------------------------------

If `is_foreman` + `is_pm` are both true, **`is_pm` takes precedence**
(PMs typically don't capture attendance themselves --- if they need to,
they use the dev role-toggle in debug).

+-----------------------------------------------------------------------+
| **✓ CONFIRMED (product)**                                             |
|                                                                       |
| The login API will expose role booleans including **`is_foreman`**    |
| (new), plus existing **`is_pm`** / **`is_hr_manager`**. Resolution   |
| rules are in §1.3.                                                    |
|                                                                       |
| **Development vs production:** During development, the app MUST allow |
| the architect/tester to reach **every Timesheet role surface**        |
| (Foreman + PM, and HR-wide PM scope where applicable) via a           |
| **`kDebugMode` override bar** without switching accounts. At release, |
| remove overrides and resolve the UI **only** from those login         |
| booleans (see §11.3).                                                  |
+-----------------------------------------------------------------------+

**1.4 Module entry point**

A new tile **"Project Site Timesheet"** is added to the existing app's
**HR Management menu** (alongside HR Requests, Recruitment, Performance,
Payslips, Attendance Reports). On tap, the user lands on the Foreman
Dashboard or PM Dashboard depending on role (with the standard dev role
toggle bar in debug builds --- see §11).

---

**2. Foreman View**

**2.1 Screen FM1 --- Foreman Dashboard (Home)**

Default landing for the foreman.

**2.1.1 Layout Wireframe**

```
+---------------------------------------------------+
| [avatar]  Hello,                            [bell]|
|           Shanta Mariya                           |
|                                                   |
| [ Find your match ........................... 🔍 ]|
|                                                   |
| [ All ●] [ Progress ] [ Tasks ] [ Teams ]         |
|                                                   |
| +---------+   +---------+   +---------+           |
| |   📋    |   |   ✍️    |   |   👥    |           |
| |   12    |   |   34    |   |   05    |           |
| | Projects|   |  Tasks  |   |  Teams  |           |
| +---------+   +---------+   +---------+           |
|                                                   |
| Active Project                          See All > |
| +-----------------------------------------------+ |
| | Midtown Tower Project           [hero image]  | |
| | 810 Grand Ave, NW York                        | |
| | 56% [============>            ]               | |
| | $1.2M - $2.5M                       8 Tasks   | |
| +-----------------------------------------------+ |
|                                                   |
| Today's Tasks                           See All > |
| +-----------------------------------------------+ |
| | 👷 Site's Inspection                          | |
| |    10:00 AM                       [avatars]   | |
| +-----------------------------------------------+ |
|                                                   |
| [Home] [Tasks] [(FAB)] [Calendar] [Profile]       |
+---------------------------------------------------+
```

**2.1.2 Component spec**

  -----------------------------------------------------------------------
  **Component**           **Behaviour**
  ----------------------- -----------------------------------------------
  Greeting header         Avatar (44 dp, circular, white border), greet
                          text + first name, bell icon trailing. Bell
                          opens existing notifications screen.

  Search field            Pill, 48 dp, leading magnifier. Searches across
                          projects + tasks for the foreman.

  Filter chips            All / Progress / Tasks / Teams. Single-select.
                          Active chip: teal-fill + white text + small
                          icon. Inactive: white + navy text + outline.

  Stat tiles (3)          Projects / Tasks / Teams counts. Square white
                          card, top-right tinted icon square (mint bg,
                          teal icon), large number (22 sp w700), label
                          below in muted grey. Tile is tappable: drills
                          into respective list.

  Active Project card     Shows the foreman's currently-active project.
                          Hero image (right side), name + address,
                          progress bar (teal fill on mint bg), budget
                          range, task count chip. Tap → opens FM2.
                          "See All" → opens FM-PL (Projects List).

  Today's Tasks list      Today's tasks across all assigned projects,
                          sorted by start time. Row: leading icon in
                          tinted square, title (15 sp w600), time/sub
                          (12 sp muted), trailing avatar stack (up to
                          3 + N indicator). Tap → opens FM3 Task Detail.
                          "See All" → opens FM-TL (Today's Tasks).

  Bottom nav              Home (active), Tasks, FAB (center, teal
                          gradient, raised, primary capture button),
                          Calendar, Profile. Same nav across all screens
                          of this module.

  FAB action              Tap → quick action sheet: "Take Attendance" |
                          "Capture Site Photo" | "New Report". "Take
                          Attendance" first asks foreman to pick a
                          project then task before the camera opens.
  -----------------------------------------------------------------------

**2.1.3 Data sources**

- Projects count, tasks count, teams count → Odoo summary endpoint
  filtered by `assigned_foreman_id = self`.
- Active project → most recently opened, persisted in
  `SharedPreferences` as `active_project_id`.
- Today's tasks → Odoo `project.task` filter
  `assigned_foreman_id = self AND planned_start <= today <= planned_end`.

**2.2 Screen FM-PL --- Projects List**

Filterable list of all projects assigned to this foreman.

- Search bar (pill, 48 dp).
- Filter chips: All / Active / On Hold / Done.
- Project tile (vertical stack of cards): hero image left, name + address
  + progress + status pill + task count.
- Tap → FM2 Project Detail.

**2.3 Screen FM2 --- Project Detail**

**2.3.1 Layout Wireframe**

```
+---------------------------------------------------+
| [<]   Midtown Tower Project              [⋮]      |
|       810 Grand Ave, NW York                      |
| [          hero image                       ]     |
|                                                   |
| | Overview | Tasks | Files | Teams |              |
|                                                   |
| $1.8M       [================>         ]          |
| Progress    Budget $1.2M       $ 2.5M             |
|                                                   |
| Today's Tasks                           See All > |
| +-----------------------------------------------+ |
| | 🚚 Material Milestone                         | |
| |    Midtown Tower Delivery Area  [avatars]     | |
| +-----------------------------------------------+ |
| | 🧱 Concrete Pouring                           | |
| |    Monday 22 April              [avatars]     | |
| +-----------------------------------------------+ |
|                                                   |
| Site Photos                             See All > |
| [img] [img] [img] [img >]                         |
|                                                   |
| [Home] [Tasks] [(FAB)] [Calendar] [Profile]       |
+---------------------------------------------------+
```

**2.3.2 Tabs**

  -----------------------------------------------------------------------
  **Tab**           **Content**
  ----------------- -----------------------------------------------------
  Overview          Progress vs Budget, Today's Tasks (read-only), Site
                    Photos thumbnails, quick-actions row (Take
                    Attendance, Capture Photo, New Report, Chat).

  Tasks             Full task list for the project, scoped to this
                    foreman. Section per status. Tap → FM3.

  Files             Site reports + uploaded documents list. PDF preview.

  Teams             Assigned workers list (read-only --- only PM adds).
                    Search + filter by trade.
  -----------------------------------------------------------------------

**2.3.3 Header overflow menu (⋮)**

- Open Chat (project chat room)
- View Geofence on map
- Project Info (read-only metadata)

**2.4 Screen FM3 --- Task Detail (entry to Attendance)**

This is the **primary attendance entry point**. Foreman picks a task,
sees its assigned workers + today's status, then proceeds to capture.

**2.4.1 Layout Wireframe**

```
+---------------------------------------------------+
| [<]   Concrete Pouring                            |
|       Mon 22 Apr  •  In Progress  •  64%          |
|                                                   |
| Description                                       |
| Pour foundation concrete sections A1-A4. Curing  |
| starts after pour.                                |
|                                                   |
| Assigned Workers (12)              0 / 12 today   |
| +-----------------------------------------------+ |
| | ⚪ Ahmed Khan        Concrete Foreman          | |
| | ⚪ Bilal Ali          Concrete Worker           | |
| | ⚪ Carlos Rodriguez   Crane Operator            | |
| | ...                                            | |
| +-----------------------------------------------+ |
|                                                   |
| Today's Attendance: 0 in / 0 out                  |
|                                                   |
| [          ▶  Take Attendance              ]      |
|                                                   |
| [Home] [Tasks] [(FAB)] [Calendar] [Profile]       |
+---------------------------------------------------+
```

**2.4.2 Behaviour**

- Worker row leading dot:
  - ⚪ Not yet captured today (default).
  - ✓ Checked in (teal).
  - ↗ Checked in + out (mint outline).
  - ⚠ Flagged (e.g. outside geofence, manual override).
- Counter `0 / 12 today` updates live as captures complete.
- `▶ Take Attendance` → opens **Capture Mode bottom sheet** (§3.1).
- Foreman can also tap an individual row → opens "Capture for [worker]"
  shortcut (individual mode pre-targeted at that worker).

**2.4.3 Status pill on task header**

Driven by Odoo `task.status` (PLANNED / IN_PROGRESS / BLOCKED / DONE).
Mobile only **reads** the pill; transitions are user-initiated:

- Foreman can flip PLANNED → IN_PROGRESS on first attendance capture.
- Foreman can flip IN_PROGRESS → DONE manually (with confirm dialog).
- BLOCKED is set only by PM.

---

**3. Attendance Capture Flow**

The headline flow of this module. Detailed step-by-step.

**3.1 Screen AT1 --- Capture Mode Bottom Sheet**

Triggered from FM3 "Take Attendance" or FAB → Take Attendance.

```
+---------------------------------------------------+
|                                                   |
|         How do you want to capture?               |
|                                                   |
|  +-----------------------+                        |
|  |  👤  Individual       |  ← one worker at a time|
|  |      Point at each    |                        |
|  +-----------------------+                        |
|                                                   |
|  +-----------------------+                        |
|  |  👥  Group Photo      |  ← capture many at once|
|  |      Match all faces  |                        |
|  +-----------------------+                        |
|                                                   |
|  Default: last used (per device).                 |
|                                                   |
+---------------------------------------------------+
```

**3.2 Screen AT2 --- Camera (Individual mode)**

```
+---------------------------------------------------+
| [×]   Capture: Concrete Pouring                   |
|       0/12 captured            [Switch to Group]  |
|                                                   |
| [         live camera preview                ]    |
| [          (front or back camera)            ]    |
| [   green box around detected face            ]   |
| [   guide: "Look at the camera"              ]    |
|                                                   |
| [Cancel]               [⚫ Shutter]    [Skip]      |
+---------------------------------------------------+
```

- ML Kit overlay: bounding box turns green when quality gate passes
  (face >= 80 px wide, eyes open, head pose within ±20°, sharp).
- Guidance text changes per failure: "Move closer", "Hold still",
  "Move out of glare", "Open eyes".
- Random liveness prompt: "Turn head left" → must detect movement
  within 2 s before shutter is enabled (Phase 1 light liveness).
- Tap shutter → ML Kit final detect + crop → on-device quality gate →
  push to local capture queue → background match (see §4).
- After capture, show a 1.5 s **toast** with result:
  - `✓ Ahmed Khan checked in (similarity 97%)` (teal).
  - `⚠ Bilal Ali --- not assigned to this task. Mark anyway / Add / Reject` (modal).
  - `✗ No match. Retry / Manual select / Skip` (modal).

**3.3 Screen AT3 --- Camera (Group Photo mode)**

```
+---------------------------------------------------+
| [×]   Group Capture: Concrete Pouring             |
|       0/12 captured        [Switch to Individual] |
|                                                   |
| [    live camera preview, all detected faces ]    |
| [    boxed (green = pass, amber = too small) ]    |
| [    counter: "8 faces detected"             ]    |
|                                                   |
| [Cancel]               [⚫ Shutter]                |
+---------------------------------------------------+
```

- After shutter: ML Kit detects N faces, crops each to 224 × 224, pushes
  N captures to the local queue. UI shows progress: "Recognizing
  8 faces…". Each result lands as a row in §3.4.

**3.4 Screen AT4 --- Capture Result Summary**

```
+---------------------------------------------------+
| Capture Summary --- Concrete Pouring              |
|                                                   |
| 6 of 8 matched. 2 need review.                    |
|                                                   |
| ✓ Ahmed Khan          97%   [in]                  |
| ✓ Bilal Ali           96%   [in]                  |
| ✓ Carlos Rodriguez    98%   [in]                  |
| ⚠ Faisal Hassan       92%   [Confirm? Yes/No]     |
| ✗ unknown                   [Manual / Reject]     |
| ...                                               |
|                                                   |
| [Continue Capturing]    [Done]                    |
+---------------------------------------------------+
```

**3.5 Check-out flow**

Foreman returns to the same task and taps "Take Attendance" again. The
app determines per-worker state:

- Worker has 0 records today → next capture is `event = checkIn`.
- Worker has a `checkIn` and no `checkOut` → next capture is
  `event = checkOut`.
- Worker has both → next capture is `event = checkIn` (treats it as a
  new shift, e.g. after-lunch return) but tags `shift_index = 2`.

**3.6 Attendance record fields (written per match)**

| Field | Type | Source |
|-------|------|--------|
| `id` | string | server-generated |
| `project_id` | string | from FM2 context |
| `task_id` | string | from FM3 context |
| `worker_id` | string | matched via Rekognition `ExternalImageId` |
| `foreman_id` | string | current user uid |
| `event` | enum | `checkIn` | `checkOut` |
| `timestamp` | server time | Cloud Function adds |
| `lat` / `lon` | double | device GPS at capture |
| `gps_accuracy_m` | double | from `geolocator` |
| `similarity` | double | Rekognition match score |
| `audit_photo_url` | string | Firebase Storage URL of the crop |
| `outside_geofence` | bool | Cloud Function computes vs project polygon |
| `manual_override` | bool | true if foreman force-marked |
| `device_id` | string | from `device_info_plus` |
| `sync_state` | enum | `pending` | `synced` | `failed` |

---

**4. Face Recognition Layer**

**4.1 Pipeline**

```
On device                          | Cloud (Cloud Functions)
-----------------------------------+--------------------------------
ML Kit face detection (real-time)  |
Quality gate (size, pose, eyes,    |
 sharpness)                        |
Crop to 224 × 224                  |
Push to local Hive queue           |
                                   |
Background sync worker —————————→  enrollWorkerFace (HTTPS callable)
                                   |   ↓ uploads ref images to Storage
                                   |   ↓ calls AWS IndexFaces
                                   |   ↓ writes face_id to Odoo worker
                                   |
                                   matchAttendance (HTTPS callable)
                                   |   ↓ accepts {project_id, task_id,
                                   |       worker_id?, crop_url, lat,
                                   |       lon, event}
                                   |   ↓ AWS SearchFacesByImage on
                                   |       collection
                                   |       `project_{id}_workers`
                                   |   ↓ threshold logic (see §4.2)
                                   |   ↓ geofence check
                                   |   ↓ write attendance doc to Odoo
                                   |       via site_report_apis bridge
                                   |   ↓ return {result, similarity,
                                   |       worker_id, attendance_id,
                                   |       outside_geofence}
```

**4.2 Threshold logic**

| Similarity returned by Rekognition | Action |
|------------------------------------|--------|
| ≥ 95 % | Auto-mark present. Write attendance record. |
| 90 % – 94.99 % | Return `needs_confirmation` to the app. Foreman confirms or rejects in AT4. |
| < 90 % | Return `no_match`. Foreman retries or manually selects a worker from the task list. |

**4.3 Group photo handling**

- On-device fan-out: ML Kit detects N faces → app crops each → uploads
  each crop to Storage → calls `matchAttendance` N times in parallel
  (max 5 concurrent on-device, to keep memory steady).
- The Cloud Function is **stateless per face** --- group context is
  reconstructed in the app from the response stream.

**4.4 Task-scoped cross-check**

After Rekognition returns a `worker_id`, the Cloud Function consults
the task's `worker_ids[]`:

- `worker_id ∈ task.worker_ids` → attendance written normally.
- `worker_id ∉ task.worker_ids` → response carries
  `task_membership: false`; the app shows a modal: **Mark anyway** (writes
  with `outside_task = true`) | **Add to task** (PM-permission-gated, calls
  Odoo to add worker to the task) | **Reject**.

**4.5 Enrolment**

- Triggered from FM-Team (PM) or AT4 "Manual" route's "Enrol new" link.
- Capture 3 reference photos with quality gate on each.
- `enrollWorkerFace(worker_id, photos[])` calls AWS `IndexFaces` with
  `ExternalImageId = worker_id` on collection `project_{id}_workers`.
- Stores reference photos in
  `gs://<bucket>/timesheet/projects/{projectId}/workers/{workerId}/ref_*.jpg`.

**4.6 Re-enrolment**

- PM may re-capture a worker's reference photos if matching accuracy
  drops below 92 % on 3 consecutive captures (UI surfaces a banner on
  the worker's row in the Teams tab).

**4.7 Liveness (Phase 1 light)**

- Individual mode: random prompt ("Turn head left", "Blink twice") that
  must be satisfied by ML Kit's `headEulerAngleY` / blink detection
  within 2 s of the shutter being available.
- Group mode: no per-face liveness in Phase 1. Foreman is accountable
  for the capture (audit photo of the full frame is retained).

**4.8 Manual override**

- After 2 consecutive `no_match` results on the same worker selection,
  foreman may tap **Mark Present (Manual)**.
- The record carries `manual_override = true` and the original
  unmatched audit photo.
- PM gets a push notification: "Foreman Ali marked Bilal Ali present
  manually on Concrete Pouring".

---

**5. Live Location & Geofence**

**5.1 Capture-time GPS**

- Every attendance record carries `lat`, `lon`, `gps_accuracy_m`.
- If `gps_accuracy_m > 50`, the app retries up to 3 times with
  `geolocator.LocationAccuracy.high`.

**5.2 Geofence**

- Each project has a circular geofence (center + radius in meters) set
  by the PM. (Polygon support is Phase 2.)
- The Cloud Function computes haversine distance and sets
  `outside_geofence = true` if outside `radius_m`.
- The PM dashboard flags `outside_geofence` records prominently.

**5.3 Live tracking (opt-in)**

- Foreman dashboard has a `"I'm on site"` toggle (off by default).
- When on, app writes a heartbeat to
  `liveLocations/{foremanId}` every 60 seconds (foreground) /
  300 seconds (background, opt-in only).
- The PM dashboard shows live foreman pins on a Map (using
  `flutter_map`).
- Heartbeats older than 10 minutes are stale; pins fade.

---

**6. Per-Project Chat (Existing Module Integration)**

- Each project has a chat room with `room_id = project_<projectId>`.
- Members auto-populated: project's PM + all `foremen[]`.
- The existing chat module (`lib/chat/`) is rendered inside FM2
  Project Detail (overflow menu → "Open Chat") with just the
  `roomId` + current `userId` passed in.
- System messages (optional, Phase 2): a Cloud Function listens on new
  attendance records and posts a summary message to the room every 30
  minutes ("Foreman Ali captured 23 check-ins on Concrete Pouring").

---

**7. Site Photos**

**7.1 Capture**

- From FM2 → "Site Photos" → "+" or from FAB → "Capture Site Photo".
- Camera screen with built-in watermark overlay:
  - Top-left: project name (small).
  - Bottom-right: timestamp + GPS (small).
- After capture: pick category (Progress / Issue / Safety / Delivery /
  Other) + optional caption (≤ 500 chars).

**7.2 Storage**

- Photos saved to
  `gs://<bucket>/timesheet/projects/{projectId}/photos/{yyyy-MM-dd}/{photoId}.jpg`.
- Firestore doc:
  `projects/{projectId}/photos/{photoId}` with metadata
  (foreman_id, ts, category, caption, lat, lon, exif).

**7.3 Gallery**

- FM2 "Site Photos" tab: grid (3 cols on phone, 4 on tablet), filter
  chips (category), date range picker.
- Tap → full-screen viewer with swipe + share.

---

**8. Site Reports & Inspections**

**8.1 Phase 1 scope**

- **One template only:** **Daily Site Report**. (Multi-template
  library is Phase 4.)
- Fields (configurable in Firestore `reportTemplates/daily_site_report`):
  - Project (read-only, from context)
  - Date (default today)
  - Weather (dropdown: Sunny / Cloudy / Rain / Sandstorm / Other)
  - Manpower (number, prefilled from today's attendance count)
  - Work performed (multi-line text, ≤ 2000 chars)
  - Issues encountered (multi-line text, ≤ 2000 chars)
  - Materials used (text)
  - Equipment on site (text)
  - Photos (multi-attach, up to 10)
  - Signature (drawn, mandatory)

**8.2 Submission**

- Saved as `projects/{projectId}/reports/{reportId}` in Firestore
  mirror + Odoo `site_report` table (via site_report_apis.py).
- PDF export via Cloud Function using `pdfmake`.
- Watermark on every page: `emp_id` of submitting foreman (matching
  the existing module convention).

**8.3 PM review**

- PM dashboard surfaces unread reports per project.
- PM can comment + mark `resolved = true`.

---

**9. Gantt View (Phase 1: Read-only)**

**9.1 Mobile presentation**

- Phone (portrait): list view. Each task = card with name, planned
  range, status pill, percent complete bar.
- Phone (landscape) / Tablet: full Gantt rendered with
  `syncfusion_flutter_gantt`. Tap a bar → opens FM3.

**9.2 PM editing**

- Phase 1: PM can update `percent_complete` and `status` from the task
  detail. Drag-to-reschedule and dependency editing remain on the
  desktop PM portal (out of scope on mobile in Phase 1).

---

**10. Design System (NEW palette for Module 6)**

Tokens live in `lib/core/theme/timesheet_module_*.dart` files. Naming
prefix: `TimesheetModule*`. Never mix with `HrModule*`.

**10.1 Colors** --- `timesheet_module_colors.dart`

| Token | Hex | Usage |
|-------|-----|-------|
| primary | `#0FB5A6` | CTA, active chip, FAB, progress fill |
| primaryGradientStart | `#16C0A8` | FAB / button gradient top |
| primaryGradientEnd | `#0A8F84` | FAB / button gradient bottom |
| primaryTint | `#E6F7F4` | Icon tile backgrounds, progress bar bg |
| bgGradientStart | `#F2EEF7` | App background gradient top (lavender) |
| bgGradientEnd | `#EFF1F8` | App background gradient bottom |
| surface | `#FFFFFF` | Card surface |
| text | `#13192B` | Body text / titles |
| mutedText | `#7A8194` | Captions, hints, sub-titles |
| divider | `#ECEEF3` | Outlines, dividers |
| success | `#22C29A` | Checked-in, on-track |
| warning | `#F5B544` | Late, needs review |
| danger | `#EF5C5C` | Absent, rejected, alert |
| info | `#5B8DEF` | Info banners |

**10.2 Typography** --- `timesheet_module_typography.dart`

Font: `Inter` (via `google_fonts` --- already in pubspec).

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| display | 22 sp | 700 | Greeting, screen titles |
| h1 | 20 sp | 700 | Hero card titles |
| h2 | 16 sp | 600 | Section headers ("Active Project") |
| cardTitle | 15 sp | 600 | Task names, project names |
| body | 14 sp | 500 | Default body |
| caption | 12 sp | 500 | Timestamps, metadata |
| statValue | 22 sp | 700 | KPI tile numbers |
| statLabel | 12 sp | 500 | KPI tile labels |
| button | 15 sp | 600 | Buttons |

**10.3 Spacing & layout** --- `timesheet_module_layout.dart`

| Token | Value |
|-------|-------|
| screenPaddingH | 20 dp |
| cardPadding | 16 dp |
| sectionGap | 24 dp |
| cardSpacing | 12 dp |
| cardRadiusLg | 20 dp (hero / large) |
| cardRadiusMd | 16 dp |
| cardRadiusSm | 12 dp (chips, tile icons) |
| chipHeight | 36 dp |
| buttonHeight | 56 dp |
| progressBarHeight | 6 dp |
| iconTileSize | 32 dp |
| avatarSize | 28 dp (stack) / 44 dp (header) |

**10.4 Shadow & elevation** --- `timesheet_module_shadows.dart`

| Token | Value |
|-------|-------|
| cardShadow | `0 8 24 rgba(20,24,47,0.06)` |
| fabShadow | `0 12 24 rgba(15,181,166,0.35)` (teal-tinted) |

**10.5 Iconography**

- Icon set: **Phosphor** (already in pubspec via `phosphor_flutter`).
- Stroke: 1.5--1.75 px. Color follows text color; tinted icon tiles
  use `primary` on `primaryTint`.

**10.6 Bottom navigation**

- 5 slots: Home / Tasks / **FAB (center, teal gradient)** / Calendar /
  Profile.
- White surface, 16 dp top corner radius, shadow at top.
- Active item: teal icon + label.
- Inactive: muted grey icon + label.
- FAB is raised ~16 dp above the bar, circular, 56 dp.

**10.7 Reusable widgets**

Implement under `lib/core/widgets/timesheet/` with `Tm` prefix:

- `TmScaffold` --- applies lavender gradient bg + safe area + bottom nav.
- `TmGreetingHeader` --- avatar, greeting, bell.
- `TmSearchField` --- pill search input.
- `TmFilterChipRow` --- horizontal single-select chips.
- `TmStatTile` --- KPI tile (number + label + icon).
- `TmProjectCard` --- hero project card.
- `TmTaskRow` --- task row with avatars.
- `TmProgressBar` --- 6 dp pill progress.
- `TmSectionHeader` --- "Section" + "See All".
- `TmPrimaryButton` / `TmSecondaryButton`.
- `TmBottomNavBar` --- with center FAB.
- `TmAvatarStack` --- overlapping avatars.

---

**11. Roles, Dev Toggle, Routing**

**11.1 Module entry point**

Add menu tile **"Project Site Timesheet"** to the existing HR
Management menu page. On tap, route to `TimesheetRouteNames.home` which
resolves to FM1 (Foreman) or PM1 (PM) based on the **effective role**.

**11.2 Effective role provider**

Reuse the pattern from Module 1 F.4. Add to
`lib/core/timesheet/providers/timesheet_role_provider.dart`:

```dart
enum TimesheetEffectiveRole { foreman, pm }
```

Resolution order when **not** in dev override (production / after Reset):
1. `is_hr_manager` → PM view, **company-wide** data scope.
2. `is_pm` → PM view, **owned projects** scope.
3. `is_foreman` → Foreman view.
4. Default → Foreman if user has any foreman project assignment, else PM read-only (or block entry with "no access" — product choice).

When **in** `kDebugMode` with an active `tmDevRoleOverrideProvider`, that override wins **before** any of the above.

**11.3 Dev role toggle (mandatory)**

On the Timesheet entry point, in `kDebugMode` only:

- 👷 Foreman icon → forces FM view.
- 🧑‍💼 PM icon → forces PM view (project-owner scope).
- 💼 HR Manager icon *(optional but recommended if HR-wide PM differs)* → forces PM view with **company-wide data scope** (same shell as PM1, wider mock/API filters).
- ↻ Reset → clears override and falls back to login-derived effective role.

**Purpose:** Give developers **all role access** during the build without relying on the backend shipping flags first or juggling multiple test users. **Production:** no toggle; effective role comes **only** from login booleans (`is_hr_manager` → broadest PM scope, then `is_pm`, then `is_foreman`).

Tag the removal point with:

```dart
// TODO(release): Remove dev role toggle. Replace with dynamic
// role detection from login API booleans (is_hr_manager, is_pm, is_foreman).
// Reference: Module 6 TASKS.md §3.
```

**11.4 Routing**

New routes (added to `lib/utils/generated_routes.dart`):

- `TimesheetRouteNames.home` → role-routed.
- `TimesheetRouteNames.foremanDashboard` → FM1.
- `TimesheetRouteNames.projectsList` → FM-PL.
- `TimesheetRouteNames.projectDetail` → FM2 / PM2.
- `TimesheetRouteNames.taskDetail` → FM3.
- `TimesheetRouteNames.captureMode` → AT1 (sheet).
- `TimesheetRouteNames.captureCamera` → AT2/AT3.
- `TimesheetRouteNames.captureSummary` → AT4.
- `TimesheetRouteNames.workerEnrol` → enrolment flow.
- `TimesheetRouteNames.sitePhotos` → photo gallery.
- `TimesheetRouteNames.reportForm` → daily site report.
- `TimesheetRouteNames.gantt` → Gantt view.
- `TimesheetRouteNames.pmDashboard` → PM1.

---

**12. Project Manager View**

**12.1 Screen PM1 --- PM Dashboard**

```
+---------------------------------------------------+
| [avatar]  Hello, [PM name]              [bell]    |
|                                                   |
| [ Search projects / workers ............... 🔍 ]  |
|                                                   |
| Today                                             |
| +---------+   +---------+   +---------+           |
| | Present |   |  Late   |   | Absent  |           |
| |   124   |   |    8    |   |    3    |           |
| +---------+   +---------+   +---------+           |
|                                                   |
| My Projects                             See All > |
| [card] [card] [card] >                            |
|                                                   |
| Alerts                                            |
| ⚠ 3 attendance records outside geofence           |
| ⚠ Foreman Ali manual-overrode 2 records          |
| ⚠ 1 unsubmitted daily report (Midtown Tower)      |
|                                                   |
| Map View                                          |
| [             flutter_map with pins         ]     |
|                                                   |
| [Home] [Tasks] [(FAB)] [Calendar] [Profile]       |
+---------------------------------------------------+
```

**12.2 Screen PM2 --- Project Detail (PM extended)**

Same as FM2 but with extra tab: **Attendance Review**.

- Day picker.
- Summary chips: Present / Late / Absent / Outside Geofence / Manual
  Override.
- Tap a flagged record → photo, similarity, GPS map pin, foreman name,
  Approve / Reject buttons.

**12.3 Screen PM-WE --- Worker Enrolment**

PM can add a worker:

```
+---------------------------------------------------+
| [<]   New Worker --- Midtown Tower                |
|                                                   |
| Name              [ Ahmed Khan                  ] |
| Trade             [ Concrete Worker  ▼          ] |
| Contact           [ +971 50 ...                 ] |
| Hourly Rate       [ 25 AED                      ] |
| Assigned Tasks    [ Concrete Pouring, …      ▼  ] |
|                                                   |
| Face Reference Photos (3 required)                |
| [   take photo 1   ] [   take photo 2   ] [ + ]   |
|                                                   |
| [Save Worker]                                     |
+---------------------------------------------------+
```

- On Save: photos upload → `enrollWorkerFace` → AWS IndexFaces → write
  worker record to Odoo with returned `face_id`.

---

**13. Data Model**

Source of truth split:

- **Odoo (HR / Project domain):**
  `hr.employee`, `project.project`, `project.task` extended with
  `foreman_ids`, `worker_ids`, `face_id`, `geofence_lat`,
  `geofence_lon`, `geofence_radius_m`.
- **Firestore (operational mirror + ephemeral):**
  - `timesheet_attendance/{recordId}` --- attendance records (mirror of
    Odoo for fast PM dashboard reads).
  - `projects/{projectId}/photos/{photoId}` --- site photo metadata.
  - `projects/{projectId}/reports/{reportId}` --- daily site reports.
  - `liveLocations/{foremanId}` --- live heartbeats (TTL 24 h).
  - `timesheet_audit/{recordId}` --- audit photo refs + Rekognition
    similarity (immutable).
- **Firebase Storage:**
  `timesheet/projects/{projectId}/workers/{workerId}/ref_*.jpg`,
  `timesheet/projects/{projectId}/captures/{yyyy-MM-dd}/{recordId}.jpg`,
  `timesheet/projects/{projectId}/photos/{yyyy-MM-dd}/{photoId}.jpg`.
- **AWS Rekognition:**
  Collection per project: `project_{projectId}_workers`.

---

**14. API Conventions**

**14.1 Odoo bridge endpoints (extend site_report_apis.py)**

> **FM ↔ existing controller mapping:** Site attendance **writes** use the
> production endpoint `POST /api/timesheet/submit` (same as HR Task Sheet).
> See `doc/Module_6_FM_API_Mapping.md` for per-field and per-screen mapping;
> code catalog: `lib/core/timesheet/network/timesheet_odoo_api_catalog.dart`.

- `GET /api/timesheet/projects?role=foreman` → list of assigned projects.
- `GET /api/timesheet/projects/{id}` → project detail + geofence.
- `GET /api/timesheet/projects/{id}/tasks?foreman_id=…` → tasks list.
- `GET /api/timesheet/tasks/{id}` → task detail + worker list.
- `POST /api/timesheet/attendance` → write attendance record (called
  by Cloud Function, NOT by mobile).
- `GET /api/timesheet/attendance?project_id=…&date=…` → PM review list.
- `POST /api/timesheet/workers` → create worker (PM).
- `POST /api/timesheet/reports` → daily site report.

**14.2 Cloud Function callables (mobile → Firebase)**

- `enrollWorkerFace(workerId, projectId, photoUrls[])` →
  `{success, face_id}`.
- `matchAttendance(projectId, taskId, cropUrl, lat, lon, event)` →
  `{result, similarity, worker_id?, attendance_id?, outside_geofence,
  needs_confirmation?}`.
- `deleteWorkerFace(workerId, projectId)` (PM only) →
  removes from Rekognition collection.

**14.3 Standard response envelope (Odoo side)**

Matches existing convention:

```json
{ "success": true, "data": { ... }, "error": null, "ui_status": "OK" }
```

**14.4 Error handling**

- 401 → re-login flow.
- 4xx → error toast from `response.error`.
- 5xx → "Something went wrong" with retry.
- Cloud Function errors → standard Firebase callable error shape.

**14.5 Mock first**

For Phase 1, all Odoo endpoints are mocked behind a `TimesheetApiClient`
with `// TODO(backend): replace with real endpoint --- SRD §14.x`
markers. Cloud Function callables are stubbed locally in
`functions/index.js` with deterministic responses to enable end-to-end
testing.

---

**15. Offline & Sync**

- All captures, photos, reports go into a local Hive box keyed
  per-project. UI shows "N pending sync" badge on FM1.
- Background sync via `workmanager` every 5 minutes when online.
- Order of upload: face captures (priority) → site photos → reports.
- On failure: retry with exponential backoff (max 5 attempts, then
  surface to user).
- Firestore offline persistence is enabled for chat + live-location
  reads (already done elsewhere in the app).

---

**16. Performance & Accuracy Targets**

| Metric | Target |
|--------|--------|
| Face match round-trip (4G, single face) | ≤ 1 s p50 / ≤ 2 s p95 |
| Face match accuracy (auto-mark, similarity ≥ 95 %) | ≥ 99 % true-positive at threshold |
| False-positive rate at 95 % threshold | ≤ 0.1 % |
| Camera preview FPS (on-device detection) | ≥ 24 fps |
| Group photo fan-out (8 faces) | ≤ 6 s end-to-end on 4G |
| Cold-start to FM1 dashboard | ≤ 2.5 s on mid-range device |
| Offline → online sync flush (50 captures) | ≤ 60 s on 4G |

---

**17. Security & Privacy**

- All AWS API calls happen only in Cloud Functions. AWS access keys
  never reach the device.
- Face captures are stored in Firebase Storage with bucket rules
  scoped per project; foreman can read only own captures, PM can read
  own projects.
- Live location is opt-in, disclosed at first run; foreman can disable
  any time; heartbeats auto-delete after 24 h.
- Audit photos retained 365 days (configurable per project).
- All AWS Rekognition data and Firebase data reside in **me-central-1**
  (Dubai) where available; otherwise me-south-1 (Bahrain).
- Worker data deletion: PM action "Delete Worker" purges Odoo record,
  Rekognition face, all reference photos, all capture audit photos
  within 7 days.

---

**18. Cost Model (Phase 1 Baseline)**

10 projects, 500 workers, 2 events / worker / workday:

- AWS Rekognition: ~30 000 calls / mo @ Tier 1 → ≈ **USD 30 / mo**.
- Firebase Storage (audit photos): ~20 GB → ≈ **USD 0.50 / mo**.
- Cloud Functions invocations: ~50 k / mo → typically within free
  tier.
- Firestore reads/writes: incremental; budget separately.

Round number: **~USD 30--50 / mo** added by this module at the baseline
scale. Scales linearly with attendance events.

---

**19. Test Strategy (high-level)**

Detailed in `Module_6_Timesheet_Test_Cases.md` (to be authored once
implementation begins). Coverage areas:

- Role resolution + dev toggle.
- Routing across FM1 → FM2 → FM3 → AT1 → AT2/AT3 → AT4.
- Camera quality gate (reject blurry, poorly-lit, multi-face on
  individual).
- Threshold logic (≥ 95 auto, 90--94 confirm, < 90 reject).
- Group photo fan-out (8 faces, 12 faces, no faces detected).
- Geofence (inside, outside, no GPS lock).
- Offline capture + queue + sync.
- PM review screen with flagged records.
- Worker enrolment success + failure paths.
- Daily site report submit + PDF export + watermark.

---

**20. Open Items**

1. ~~Confirm new `is_foreman` boolean on login API~~ **DONE** — login will expose `is_foreman` / `is_pm` / `is_hr_manager`; dev uses toggles, prod uses dynamic resolution (§11).
2. Confirm new design palette vs aligning with Module 1 navy
   (§1.2 assumption).
3. Confirm AWS region me-central-1 vs me-south-1 (§1.2 assumption).
4. Confirm laborer self-service is out of Phase 1 (§1.2 assumption).
5. Confirm circular geofence is sufficient (polygon = Phase 2).
6. Confirm one inspection template (Daily Site Report) is sufficient
   for Phase 1.
7. Confirm `syncfusion_flutter_gantt` community license is acceptable
   (already in pubspec only on demand).
8. Decide background tracking on/off by default (currently off,
   opt-in).
9. Sign-off on threshold values (95 / 90).

---

**21. Glossary**

- **Foreman:** field user who captures attendance.
- **PM:** Project Manager, oversight role.
- **Laborer / Worker:** non-app-user; record + face reference only.
- **Task:** unit of work inside a project, owns a list of assigned
  workers, drives the attendance scope.
- **Capture:** a single shutter event that produces one (individual)
  or many (group) face crops.
- **Match:** the Rekognition `SearchFacesByImage` result for a single
  crop.
- **Event:** `checkIn` or `checkOut`, derived from per-worker state
  in the task on that day.
- **Audit photo:** the cropped face image associated with each
  attendance record, kept for evidence.

# Module 6 — Project Site Timesheet | Master TODOs

> Rolling checklist for the architect / PM. The granular task breakdown lives in `Module_6_Timesheet_TASKS.md`. The full requirements are in `Module_6_Timesheet_SRD.md`. Use this file to see overall progress at a glance.

**Status legend:** `[ ]` Not started · `[~]` In progress · `[x]` Done · `[!]` Blocked · `[?]` Decision needed

---

## A. Pre-Build Decisions (block Phase 1)

- [x] Confirm new role booleans on login (`is_foreman`, existing `is_pm` / `is_hr_manager`). Dev phase uses **kDebugMode toggles for all roles**; production uses **dynamic condition from login only**. *(SRD §1.3, §11.3)*
- [ ] Confirm new lavender + teal palette vs aligning with Module 1's navy `#1F3A5F`. *(SRD §1.2, §10)*
- [ ] Confirm AWS region: `me-central-1` (Dubai) primary, `me-south-1` (Bahrain) fallback. *(SRD §1.2)*
- [ ] Confirm laborer self-service stays out of Phase 1 (record-only, no login). *(SRD §1.2)*
- [ ] Confirm threshold values: auto-match ≥ 95 %, confirm 90–94.99 %, reject < 90 %. *(SRD §4.2)*
- [ ] Confirm one inspection template (Daily Site Report) is enough for Phase 1. *(SRD §8.1)*
- [ ] Confirm circular geofence is enough (polygon = Phase 2). *(SRD §5.2)*
- [ ] Confirm background live-location tracking is off by default, foreman opt-in. *(SRD §5.3)*
- [ ] Confirm `syncfusion_flutter_gantt` community license is acceptable. *(SRD §9, TASKS F.0)*

---

## B. Foundation (Phase 0 — TASKS F.0 → F.10)

- [x] **F.0** Add `google_mlkit_face_detection` + `syncfusion_flutter_gantt` to `pubspec.yaml`; `flutter pub get`; `flutter analyze` clean. `syncfusion_flutter_gantt` is not available on pub.dev, so no substitute was added.
- [x] **F.1** Design tokens in `lib/core/theme/timesheet_module_*.dart` (colors, typography, layout, shadows, attendance status colors, theme barrel).
- [x] **F.2** Shared widgets in `lib/core/widgets/timesheet/` (`Tm*` prefix) + widget sandbox screen.
- [x] **F.3** Models (`Project`, `Task`, `Worker`, `AttendanceRecord`, `SitePhoto`, `SiteReport`).
- [x] **F.4** Networking layer: Odoo bridge client + Firebase callables client, both mock-first.
- [x] **F.5** Role provider + dev role toggle bar (Foreman / PM / HR-wide / Reset) — `kDebugMode` only; production path uses login booleans only.
- [x] **F.6** Routing: `TimesheetRouteNames.*` + entries in `lib/utils/generated_routes.dart`.
- [x] **F.7** Face capture service (ML Kit + camera + quality gate + crop + liveness prompt).
- [x] **F.8** Capture queue (Hive) + `workmanager` sync drain.
- [x] **F.9** Geofence helper (haversine), display-only on device.
- [x] **F.10** Cloud Functions skeleton (`enrollWorkerFace`, `matchAttendance`, `deleteWorkerFace`) deployed to me-central-1, returning canned responses.

---

## C. Foreman Screens (Phase 1 — TASKS FM1 → FM3)

- [x] **FM1** Foreman Dashboard with greeting, search, filter chips, 3 stat tiles, Active Project card, Today's Tasks list, bottom nav with center FAB.
- [x] **FM-PL** Projects List with filter chips + search.
- [x] **FM2** Project Detail with hero header + tabs (Overview / Tasks / Files / Teams), Today's Tasks, Site Photos thumbnails, overflow menu (Chat / Geofence / Info).
- [x] **FM3** Task Detail with worker list, status dots, "0/N today" counter, **Take Attendance** primary button.

---

## D. Attendance Capture (Phase 2 — TASKS AT1 → AT4)

- [ ] **AT1** Capture Mode bottom sheet (Individual / Group), persisted default.
- [ ] **AT2** Camera (Individual) with live overlay, quality guidance, liveness prompt, post-capture toast.
- [ ] **AT3** Camera (Group) with multi-face overlay, fan-out to parallel matches.
- [ ] **AT4** Capture Result Summary with per-face status (matched / needs_confirmation / no_match) + actions.

---

## E. Enrolment + PM Screens (Phase 3 — TASKS EN1 → PM-AR)

- [x] **EN1** Worker Enrolment: form + 3-photo capture, AWS IndexFaces, store `face_id`.
- [x] **PM1** PM Dashboard: today summary, projects, alerts, map.
- [x] **PM2** Project Detail (PM extended) with Attendance Review tab.
- [x] **PM-AR** Attendance Review: day picker, flagged records, Approve / Reject.

---

## F. Module Extras (Phase 4 — TASKS X-*)

- [x] **X-Photos** Site Photos: watermark camera, gallery grid, filter + viewer.
- [x] **X-Report** Daily Site Report: single template form + photo attach + signature + PDF export with emp_id watermark.
- [x] **X-Gantt** Gantt View: list on phone, full Gantt on tablet/landscape.
- [x] **X-Live** Live Location: foreman toggle, heartbeats, PM map pins.
- [x] **X-Chat** Per-Project Chat: embed existing chat module with `roomId = project_<projectId>`.

---

## G. Polish & Sign-off (Phase 5 — TASKS P1 → P3)

- [x] **P1** Offline polish: sync badge, per-row sync state, manual retry drawer.
- [ ] **P2** Accessibility + high-brightness mode for outdoor sites.
- [ ] **P3** Performance verification against SRD §16 targets + final architect walkthrough.

---

## H. Backend Coordination (Owner: backend team)

- [ ] Add endpoints in `site_report_apis.py` per SRD §14.1.
- [ ] Add `is_foreman` boolean to login API response.
- [ ] Extend `project.task` with `assigned_foreman_id` and `worker_ids`.
- [ ] Extend `hr.employee` (or new `site.worker`) with `face_id`, `ref_photo_urls`.
- [ ] Extend `project.project` with `geofence_lat`, `geofence_lon`, `geofence_radius_m`.
- [ ] Provide service-account token for Cloud Function → Odoo server-to-server.
- [ ] Confirm Odoo region + data residency (UAE).

---

## I. Infrastructure (Owner: DevOps)

- [ ] Create AWS IAM role for Rekognition with minimal `rekognition:IndexFaces`, `rekognition:SearchFacesByImage`, `rekognition:DeleteFaces`, `rekognition:CreateCollection` (auto on first project) in `me-central-1` (fallback `me-south-1`).
- [ ] Store AWS keys in Firebase Functions runtime config (NOT in repo).
- [ ] Verify Firebase Storage rules scope `timesheet/projects/{projectId}/...` correctly per role.
- [ ] Set up Storage lifecycle rule: audit photos retained 365 days, then auto-archive.
- [ ] Add Crashlytics filters for `timesheet:*` errors.

---

## J. Tracking targets

| Item | Target | Current |
|------|--------|---------|
| Face match round-trip (4G, single) | ≤ 1 s p50 / ≤ 2 s p95 | — |
| Auto-mark accuracy (≥ 95 % similarity threshold) | ≥ 99 % true-positive | — |
| False-positive rate at 95 % | ≤ 0.1 % | — |
| Camera preview fps (on-device detect) | ≥ 24 fps | — |
| Group fan-out (8 faces) | ≤ 6 s | — |
| Cold-start to FM1 | ≤ 2.5 s on mid-range | — |
| Offline → online sync flush (50 captures) | ≤ 60 s on 4G | — |
| AWS Rekognition cost (10 projects baseline) | ≤ USD 35 / mo | — |

---

## K. Sign-off

- [ ] SRD review by architect — date: ____
- [ ] TASKS file accepted as build order — date: ____
- [ ] Phase 0 (Foundation) demo — date: ____
- [ ] Phase 1 (Foreman screens) demo — date: ____
- [ ] Phase 2 (Capture flows) demo — date: ____
- [ ] Phase 3 (PM screens) demo — date: ____
- [ ] Phase 4 (Extras) demo — date: ____
- [ ] Phase 5 (Polish) demo — date: ____
- [ ] Production go-live — date: ____

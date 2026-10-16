# TASK 06 — Authenticated face image route + app download switch

Side: Backend (`elrace_backend_apis`) + App
Depends on: nothing (can run in parallel); app part touches `ProfilePhotoFaceDb`, so merge after Task 02 to avoid conflicts
Read first: `doc/face_capture_1to1/00_TECHNICAL_APPROACH.md` §6

## Context
Face templates are built from `GET /public/employee/image/<id>` (module `pandora_project_timesheets_apis`, `auth='public'`, `sudo()`, sequential ids). Anyone can download any employee's face photo without logging in. That module is **off-limits** and its route is used across the app for avatars, so it is not changed here. This task gives **face matching** its own authenticated route, so the biometric pipeline no longer depends on a public endpoint.

## Part A — Backend
File: a controller in `elrace_backend_apis/controllers/` (the timesheet or face_db controller is a natural home; follow the module's existing structure).

1. Route `GET /api/v2/employee/face_image/<int:employee_id>`, `type='http'`, `auth='none'`, `csrf=False`.
2. Auth: same mobile bearer validation the v2 timesheet endpoints use (`_validate_mobile_request()` / `_v2_auth()` pattern). Invalid / missing token → HTTP 401, empty body.
3. Authorisation — allow only if **one** of:
   - caller employee is foreman or HR (reuse the `_is_foreman_or_hr` logic in `controllers/face_db_controller.py`), or
   - target is in caller's `x_labor_ids`, or
   - target is the caller themself.
   Otherwise HTTP 403. Same company only.
4. Body: `image_1024` of the employee (fallback `image_1920`). No image → HTTP 404.
5. Headers: correct `Content-Type` detected from magic bytes (PNG / JPEG / WEBP; the public route always says PNG), `Content-Length`, `Cache-Control: private, max-age=3600`, `ETag` from the employee's image write date; honour `If-None-Match` with 304.
6. Add the route to `utils/middleware_map.py` (cache TTL, `read`, a rate limit in line with similar routes).
7. Log denied requests at INFO with caller id and target id (no image data).
8. Bump module version (if Task 01 already bumped to 1.0.16, use 1.0.17).

## Part B — App
Files: `lib/core/site_management/face_recognition/profile_photo_face_db.dart` (`_download`, `setTeam` URL), and where `TimesheetOdooEmployee.faceMatchImageUrl` is built.

1. Profile template download uses the new route with the same `Authorization` header as the timesheet API client (find the token source used by the client behind `lib/core/timesheet/network/timesheet_odoo_api_catalog.dart`; do not hard-code tokens).
2. On 401: refresh the token the same way the API client does, retry once. On 403/404: mark template `failed` with reason (e.g. "no access" / "no photo") — no retry loop; the existing 1-day failed retry still applies.
3. Keep the public URL for **avatars** elsewhere (notice tile, chips, lists) — out of scope.
4. Template cache key must not change because of the URL change (no forced rebuild for this task).

## Notes (not in this task — decision needed)
- The public route still exposes all employee photos. Closing it requires changing `pandora_project_timesheets_apis` or adding a reverse-proxy rule, and moving app avatars to an authenticated loader. Raise separately.
- `/api/register_face_images` has no auth (`csrf=False`). Unused by capture now; disable or protect separately.

## Verify
1. Backend: no token → 401; foreman token, own labor → 200 with correct `Content-Type`; foreman token, employee from another team (not HR) → 403; unknown id → 404; second call with `If-None-Match` → 304.
2. App: fresh install → templates build via the new route (log shows URL path `/api/v2/employee/face_image/`), verification works as before.
3. Expired token mid-build → one refresh + retry, templates complete.
4. Avatars elsewhere in the app still load.

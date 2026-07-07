# Module 6 — Face recognition → employee auto-fill (backend plan)

## Current app behavior (Phase A)

- Foreman captures **labor** face; match roster = **project labors** from `/api/timesheet/labor_list` with `image_url` + `has_profile_image`.
- On-device ML Kit crop + pixel match against `https://erp.elrace.com/public/employee/image/{id}`.
- On match, `FmTimesheetCaptureSubmitScreen` pre-selects the labor in the form before Odoo submit.

## Target backend flow

1. **POST `/api/timesheet/face/match`** (new)
   - Input: `project_id`, `task_id`, `image_base64` (or multipart), optional `latitude`/`longitude`.
   - Server: run same model or call existing face service; search only employees in `staff_list_ids` / foreman `x_labor_ids` for that project.
   - Output: `{ "success": true, "employee_id": 4309, "name": "...", "confidence": 0.92, "file_id": "..." }` or `{ "success": false, "message": "no_match" }`.

2. **Enrollment sync** (optional phase 2)
   - **POST `/api/timesheet/face/enroll`** — store reference embedding keyed by `hr.employee` id (Firebase UID link already used in chat).
   - Reuse mobile capture pipeline; server validates face count = 1.

3. **Submit integration**
   - Mobile may still submit via existing **`/api/timesheet/submit`** with `employee_id` from match response.
   - Log `match_request_id` on analytic line for audit.

## Odoo data rules

- Scope candidates by project assignment + foreman labor list (same as `labor_list` / `staff_list_ids`).
- Reject match if employee not on project or inactive.

## Security

- Auth: existing Odoo session / API token.
- Rate-limit match endpoint; do not return embeddings to client.

## Rollout

| Phase | Deliverable |
|-------|-------------|
| A | Match endpoint + mobile calls server when online (fallback to on-device) |
| B | Server-side enrollment + admin re-enroll in Odoo |
| C | Offline queue: store image + match after sync |

## Mobile follow-up

- After backend A: on match callback, set employee field from API response (same as today’s local match).
- Show confidence threshold in UI; require manual pick if below 0.85.

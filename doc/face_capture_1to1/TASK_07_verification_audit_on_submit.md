# TASK 07 — Verification audit on timesheet submit

Side: Backend (`elrace_backend_apis`) + App
Depends on: TASK 03 (app has verify results per capture)
Read first: `doc/face_capture_1to1/00_TECHNICAL_APPROACH.md` §2

## Context
`POST /api/v2/timesheet/submit` creates `account.analytic.line` rows from `employee_ids`, dates, break and `coords {empId: {x_lat, x_long}}`. Nothing about the face check reaches Odoo, so HR cannot review doubtful entries or tune bars from real data. Add an **optional, additive** audit block. This changes a live API — it is backward compatible (old app builds send nothing), but get approval before deploying.

## Part A — Backend

### Model
Extend `account.analytic.line` in `elrace_backend_apis/models/` (new file, add to `models/__init__.py`):

| Field | Type | Notes |
|---|---|---|
| `x_face_verified` | Boolean | true only when the app sent a verified 1:1 result |
| `x_face_score` | Float (digits 4) | target score |
| `x_face_lead` | Float (digits 4) | lead over cohort; empty when cohort too small |
| `x_face_cohort_size` | Integer | |
| `x_face_liveness` | Selection `pass` / `fail` / `not_run` | |
| `x_face_method` | Char | e.g. `profile_1to1` |
| `x_face_app_version` | Char | app version + build |

All readonly in UI. Add them as optional (hidden by default) columns to the timesheet list view HR uses, and a filter "Face score below bar" is a nice-to-have. If adding a view requires a new module dependency, add the fields only and report back.

### Controller
File: `elrace_backend_apis/controllers/timesheet_controller.py`

1. Request shape (new, optional key on `/api/v2/timesheet/submit`):
```json
"face_verification": {
  "<employee_id>": {
    "verified": true,
    "score": 0.4123,
    "lead": 0.0841,
    "cohort_size": 23,
    "liveness": "pass",
    "method": "profile_1to1",
    "app_version": "1.0.35+103"
  }
}
```
2. **Critical:** `submit_timesheet_v2(**kwargs)` calls `self.submit_timesheet(**kwargs)`, and `submit_timesheet` has an explicit signature — an unknown kwarg raises `TypeError`. Pop `face_verification` from `kwargs` in v2 **before** calling it.
3. Pass the popped dict to the line creation without changing `submit_timesheet`'s signature: set it on the request (same pattern as `request._elrace_ts_user` in `_v2_auth`), and where `submit_timesheet` builds the per-employee create payload, merge the audit fields for that employee if present.
4. Sanitise: ignore if not a dict; ignore employee ids not in `employee_ids`; numbers cast to float/int and clamped (score/lead −1..1, cohort 0..1000); `liveness` must be one of the selection values else `not_run`; strings truncated to 64 chars. Never fail the submit because of bad audit data — log a warning and drop the bad entry.
5. Edit/update path (`id` given): only overwrite audit fields when new audit data is sent for that employee.
6. v1 route `/api/timesheet/submit` unchanged.
7. Bump module version (next after Tasks 01/06).

## Part B — App
1. Carry the verify result from the capture (Task 03 callback) into the capture session entry and the Hive queue draft: `verified`, `targetScore`, `lead`, `cohortSize`, `liveness` (`pass` when the burst + shutter anti-spoof passed). Drafts already in the queue from an older build must still deserialise (fields nullable).
2. When submitting via `/v2/timesheet/submit` (`TimesheetOdooApiCatalog.submitTimesheet`), add `face_verification` for employees that have audit data. Manually added labors send nothing.
3. `method` = `profile_1to1`; `app_version` from package info.

## Verify
1. Old app build (no `face_verification`) → submit works exactly as before; audit fields empty.
2. New build, 3 verified captures + 1 manual add → 3 lines with audit fields filled, manual line empty.
3. Malformed audit (`"score": "abc"`, unknown employee id) → submit succeeds, warning logged, bad entry dropped.
4. Edit an existing line without audit data → existing audit values unchanged.
5. HR list view: optional columns show values.

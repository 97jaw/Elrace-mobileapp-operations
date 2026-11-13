# A1 (Odoo) — Check-in location (foremen always, other staff behind a System Parameter) + server time

Repo `odoo14-clients`, branch **`elrace-addons`** only. Module `elrace_backend_apis`
(`services/attendance_service.py`, `controllers/attendance_controller.py`,
`utils/location_thresholds.py`). Backup pointer branch before deploy. Old app builds
must keep working (no new required params).

## Rule
| Employee | Location check on `/api/check_in/` | Projects that count |
|---|---|---|
| Foreman (role flag `x_is_foreman`) | Always (as today) | In-progress projects where he is a supervisor |
| Other staff, param OFF (default) | None (as today) | — |
| Other staff, param ON | Yes | 1) `hr.employee.project_id` (Current Project/Location) when set, in progress and with coordinates; 2) otherwise in-progress projects where he is in `staff_list_ids` |

- New System Parameter **`elrace.staff_checkin_location`**: `1`/`True` = ON; missing,
  empty, `0`, `False` = OFF. Read it with the same safe helper style as
  `location_thresholds.py`.
- Distance = haversine metres, radius `elrace.staff_attendance_threshold`
  (default 100 m), within **any** project of the list.
- One helper, e.g. `_checkin_location_rule(emp)` → `(location_required, projects)`,
  used by `check_in`, `get_checkin_context` and `get_checkin_projects`, so all three
  agree.
- Messages (same style as today): location missing → "Location is required for
  check-in."; no project → "You are not assigned to any project. Contact HR.";
  projects without coordinates → "Project(s) [..] have no location set. Contact
  Document Controller."; too far → "You are not within N meters of your project
  site(s): [..]."

## Server time (not the phone clock)
- `check_in` / `check_out`: use the server's current time (`fields.Datetime.now()`)
  for `check_in` / `check_out`. Keep accepting `checkin_date_time` /
  `checkout_date_time` (old builds send them, the routes must not break), but only
  log them: when the phone time differs from the server by more than 5 minutes,
  `_logger.warning` with employee, both times and the difference.
- "Today" (`_get_today_attendance`, `_today_utc_range`, `/api/attendance/today_status`):
  compute today's date in the employee's time zone (default Asia/Dubai), not
  `fields.Date.today()` (UTC). Today 00:00–04:00 Dubai counts as the previous day.

## Old app safety (no crash, no behaviour break)
- No new required params; every existing param still accepted.
- Response shapes unchanged: same keys and types (`status`, `message`,
  `check_in_record_id`, `check_in_time`, `check_out_time`, `already_exists`).
  New keys are additions only.
- Old builds keep sending rounded GPS and calling `validate_user_location`: leave
  that route working as today.

## API changes (additive)
- `attendance/checkin_context` → add `location_required` (bool).
- `attendance/checkin_projects` → when `location_required`, return exactly the
  projects of the rule (the ones that count); otherwise unchanged.
- `check_in/` → apply the rule above. Nothing else changes (one record per day,
  BioTime, status).

## Tests
Server time used even when the phone time is wrong (and the warning logged); today in Dubai between 00:00 and 04:00; old-style payload (rounded GPS, phone time) still accepted with the same response keys; foreman inside / outside / no project / no coordinates; non-foreman with param OFF
(no check, even without GPS); param ON with `project_id`, with only staff list, with
neither, outside radius; `checkin_context.location_required` for each case.

## Deploy
Restart workers (no XML/field change → no `-u`). Parameter stays OFF until the
business decides.

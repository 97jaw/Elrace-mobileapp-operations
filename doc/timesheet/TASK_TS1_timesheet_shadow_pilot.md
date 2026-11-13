# TASK TS1 — Timesheet shadow (pilot) table: run the new app in parallel

Repos
- Odoo: ~/projects/elrace/odoo14-clients/.worktrees/elrace-addons (branch elrace-addons), module elrace_backend_apis
- Mobile: ~/projects/mobileapp/Elrace-mobileapp-operations (branch feat/checkin-attendance-v2)
Author: M Jawad <jawad@elrace.com>. NO Co-authored-by / Cursor trailer.

## Goal
Foremen keep using the OLD timesheet flow (real account.analytic.line = payroll source). In parallel,
pilot foremen also submit from the NEW mobile app. Everything the new app writes must go to a separate
shadow table, never to account.analytic.line. Same API, same validations, same responses. Afterwards we
compare shadow vs real to find difficulties before switching the old app off.

## 1. Why a standalone model (not `_inherit` copy of account.analytic.line)
account.analytic.line is extended by 14+ modules (payroll costing, labor payroll engine, attendance
penalties, disciplinary attendance queue, transfer sync, job costing, sheet, stages…). Their create/write
overrides have side effects (payroll refresh, penalties, attendance queue, analytic amounts, sheets).
A prototype copy would inherit these or clash on m2m relation tables. So: a standalone model with the
fields the timesheet APIs read/write, and NO downstream side effects.

## 2. Model `elrace.timesheet.shadow` (table elrace_timesheet_shadow), in elrace_backend_apis
Fields = everything the timesheet APIs set or return on account.analytic.line. Check every
read/write in controllers/timesheet_controller.py (v1 + v2), the face-audit fields
(models/account_analytic_line.py), and _serialize_timesheet_row. At least:
project_id, task_id, employee_id, user_id (submitter), date, date_time, date_time_end, name,
unit_amount, break_time, leave_type, custom_timesheet_stage_id, all x_face_* / face audit fields,
company_id, create_uid/create_date (std).
Extra: source_app (char, e.g. 'mobile_v2'), real_line_id (m2o account.analytic.line, set by compare),
note. Indexes on (employee_id, date) and (project_id, date).
Same SQL/python constraints as the real flow (one entry per employee per day etc.), but checked only
inside the shadow table.
Do NOT call _compute_sheet or any analytic/payroll/attendance hook.

## 3. Routing (server-side, the app UI stays the same)
Shadow mode for a request = ALL true:
  a) ir.config_parameter elrace.timesheet_shadow_enabled = True (data/params.xml, noupdate, default 'False')
  b) the request comes from the NEW app: header `X-Elrace-Ts-Mode: shadow` (mobile adds it, see 5)
  c) the user has the role feature `timesheet.shadow_pilot` (new mobile.feature in
     emp_mobile_conf/data/mobile_features.xml, name "Timesheet: Pilot (shadow table)", category
     human_resource, module timesheet, kind action, is_default False)
The old app / Odoo web never send the header → always real table, even for a pilot foreman.

One helper in the controller: `_ts_model()` → env['elrace.timesheet.shadow'] in shadow mode, else
env['account.analytic.line']. EVERY timesheet endpoint used by the new app must use it:
submit (v1 + v2), check/by/date, copy/timesheet/from/date, task + project timesheets list (v1 + v2),
count/timesheets/by/days (v1 + v2), update/timesheets/status, delete/timesheet,
project_foremen_summary, print_report. Validation helpers (_get_timesheet_day_block_message,
_lock_employee_timesheet_day, duplicate checks, _ts_restrict, _ts_submit_allowed, month lock) must take
the model as a parameter:
- duplicate / one-per-day / overlap checks → against the SHADOW table only
- month lock, leave, attendance, project/role/policy checks → same real data as today
In shadow mode the response shape and messages must be identical. Do not change real-mode behaviour.
Go-live later = flag only, NO app update: set elrace.timesheet_shadow_enabled = False → the server
ignores the header and the new app writes to the real table. The header stays in the app permanently
and is harmless when the flag is OFF. The old app keeps calling the same live APIs without the header
and is never affected.

Never touched by shadow: hub_controller export, payroll, penalties, attendance queue, Odoo web timesheet views.

## 4. Compare (Odoo)
- Menu: Timesheets → Pilot (Shadow) → "Shadow Timesheets" (tree/form/search, group by project/date/foreman)
  and "Shadow vs Real".
- `elrace.timesheet.shadow.compare` (transient or SQL view) for a date range + optional project:
  per (date, project, employee): shadow hours / real hours, leave type each side, start/end each side,
  status: match | hours_diff | time_diff | leave_diff | only_shadow | only_real. Set real_line_id on match.
- Button "Compare" on a wizard (date from/to, project). Export to Excel through standard list export.
- Access: timesheet managers + base.group_system.

## 5. Mobile
- Add header `X-Elrace-Ts-Mode: shadow` to ALL timesheet API calls (one place in the HTTP client used by
  the timesheet module). Build flag `--dart-define=TS_SHADOW=true` (default true for the pilot build).
- No UI change. Optional small "PILOT" chip in the timesheet header when the server response has
  `shadow: true` (server adds this key in shadow mode).

## 6. Tests
- Real mode unchanged: existing tests pass.
- Shadow mode: submit → row in elrace_timesheet_shadow, nothing in account_analytic_line; list/count/
  check/copy/status/delete operate on shadow; one-per-day enforced in shadow only (a real line for the
  same employee/day does NOT block shadow); no header or feature or param OFF → real table.
- Compare: match / hours_diff / only_shadow / only_real cases.

## 7. Deploy
New table only (no change to existing big tables). -u emp_mobile_conf,elrace_backend_apis.
Then: param elrace.timesheet_shadow_enabled=True, tick "Timesheet: Pilot (shadow table)" for the pilot
foremen (Role User Features), install the pilot app build.

## 8. Commits
- elrace-addons: "timesheet: shadow pilot table, routing, compare"
- mobile: "timesheet: send shadow header for pilot build"
Report: list of endpoints switched to _ts_model(), validation helpers changed, fields on the shadow model
(and any AAL field you left out + why), tests, hashes.

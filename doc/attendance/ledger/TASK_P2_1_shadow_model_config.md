# TASK P2_1 — Shadow day model + resolver settings

Module `elrace_attendance_ledger` (worktree `.worktrees/elrace-addons`). Version → `14.0.2.0.0`.

## Model `elrace.attendance.day` ("Attendance Day (shadow)")

One row per employee per date. `_order = "day_date desc, employee_id"`.

| Field | Type | Notes |
| --- | --- | --- |
| `employee_id` | Many2one `hr.employee`, required, index, `ondelete='cascade'` | |
| `day_date` | Date, required, index | Local date |
| `company_id` | Many2one `res.company`, related `employee_id.company_id`, store | |
| `day_type` | Selection, required | `present`, `absent`, `leave`, `jm_full`, `jm_half`, `off`, `holiday`, `not_yet` |
| `leave_code` | Char | Work-entry code of the leave (e.g. `LEAVE100`), when `day_type = leave` |
| `check_in` / `check_out` | Datetime | UTC |
| `in_source` / `out_source` | Selection `gate`, `mobile`, `policy` | `policy` = time set by JM rule |
| `punch_count` | Integer | Punches used for the day (not ignored) |
| `late_minutes` | Integer | After grace |
| `early_minutes` | Integer | Before scheduled end |
| `excused_minutes` | Integer | Minutes inside an approved TP window |
| `worked_hours` | Float | out − in, 0 when no out |
| `flags` | Char | Comma list: `missing_out`, `out_only`, `worked_on_leave`, `worked_on_off`, `late_upload`, `unlinked_request`, `multiple_requests` |
| `request_ids` | Many2many `employee.requests` | Requests used (JM / TP / leave) |
| `leave_id` | Many2one `hr.leave` | Leave used, when any |
| `punch_ids` | Many2many `elrace.attendance.punch` | Punches used |
| `state` | Selection `open`, `final`, `error` | `open` before cutoff, `final` after, `error` if the resolver failed |
| `error` | Text | Exception text when `state = error` |
| `resolved_at` | Datetime | Last rebuild |
| `rule_version` | Char | Hash of the settings used (to see which days were built with old rules) |
| `compare_status` | Selection `match`, `diff`, `no_odoo_row`, `duplicate_odoo_rows`, `only_odoo_row` | Set by TASK_P2_4 |
| `compare_reason` | Char | Set by TASK_P2_4 |
| `odoo_attendance_ids` | Many2many `hr.attendance` (relation `elrace_att_day_hr_att_rel`) | Today's rows for the same employee + date, set by TASK_P2_4 |

SQL constraint: `unique(employee_id, day_date)`.

No create/write from the UI. Access (`ir.model.access.csv`): read for
`hr_attendance.group_hr_attendance_manager` and `base.group_system`; write/create/unlink only through
`sudo()` in the resolver (no group gets them).

## Settings (`data/ir_config_parameter.xml`, `noupdate="1"`)

| Key | Default | Decision |
| --- | --- | --- |
| `attendance.resolver_shadow` | `False` | flag |
| `attendance.day_start_hour` | `4` | D1: local hour a workday starts (punch at 03:59 belongs to the previous day) |
| `attendance.cutoff_hour` | `6` | local hour on the NEXT day after which a day becomes `final` |
| `attendance.work_start` | `8:00` | used when the employee has no calendar |
| `attendance.work_end` | `17:00` | used when the employee has no calendar |
| `attendance.grace_minutes` | `15` | late grace |
| `attendance.min_out_gap_minutes` | `30` | a punch counts as "out" only this long after "in" |
| `attendance.missing_out_rule` | `review` | D3: `review` (flag only) — other values added after audit |
| `attendance.leave_vs_punch` | `leave` | D4: `leave` wins, flag `worked_on_leave` |
| `attendance.tp_mode` | `excuse_window` | D5: TP only excuses late/early minutes inside its window |

Helper on the model: `_settings()` returns a dict of all keys parsed to int/float/time with the defaults
above on any bad value, plus `rule_version` = short sha1 of the sorted dict.

## Done when

Module upgrades on the live DB with the flag off and creates the table, params and access rules;
nothing else changes.

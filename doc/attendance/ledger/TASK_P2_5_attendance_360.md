# TASK P2_5 — "Attendance 360": one complete row per employee per day (+ tree/form/pivot, BioTime menu)

Module `elrace_attendance_ledger` (worktree `.worktrees/elrace-addons`, branch `elrace-addons`, no commit
until reviewed). Version → `14.0.3.0.0`. Replaces the earlier read-only-views draft of P2_5.

## Goal

HR opens ONE screen and sees, for every staff member and day, everything needed to judge and pay that day:
who, which project, which schedule, every punch (gate + mobile), requests (JM / TP / leave), what the
resolver decided, what Odoo `hr.attendance` currently says, and what payroll would do with the day — without
opening attendance, requests, leaves, BioTime or the payslip separately.

Everything is computed by the resolver and STORED on `elrace.attendance.day` (fast list, group by, pivot,
export). Nothing in this task writes to `hr.attendance`, requests, leaves, contracts or payslips.

## New / changed fields on `elrace.attendance.day`

Column groups below = the order of columns in the list and the tabs of the form.
`(rel)` = related stored field; `(res)` = set by the resolver; `(cmp)` = set by the compare.

### A. Employee (rel, `store=True` so HR can group/filter)
| Field | Source |
| --- | --- |
| `emp_file_no` | `employee_id.emp_id` (Employee ID / file number) |
| `department_id` | `employee_id.department_id` |
| `job_id` | `employee_id.job_id` |
| `project_id` | `employee_id.project_id` ("Current Project/Location") — snapshot at resolve time (res, not related, so history stays) |
| `attendance_mode` | (res) Selection `gate` (linked in `biotime.employee`), `mobile` (has mobile access, no BioTime link), `gate_mobile` (both), `none` |
| `biotime_code` | (res) `biotime.employee.emp_code` of the employee, comma list if several |

### B. Day & schedule (res)
| Field | |
| --- | --- |
| `weekday` | Selection Mon…Sun |
| `is_working_day` | Boolean (calendar / weekly off) |
| `holiday_name` | Char (public holiday name) |
| `sched_start` / `sched_end` | Datetime (UTC, shown in user tz) from the calendar |

### C. Punches (res)
| Field | |
| --- | --- |
| `check_in`, `check_out`, `in_source`, `out_source` | existing |
| `in_device` / `out_device` | Char: terminal alias for gate, "Mobile (lat, lng)" for mobile |
| `punch_count` | existing |
| `gate_punch_count` / `mobile_punch_count` | Integer |
| `punch_timeline` | Char, every punch of the workday in order, local time + source, e.g. `07:58 G · 12:41 G · 13:20 G · 17:06 M` |
| `first_gate_in` / `last_gate_out` | Datetime (gate only — for HR cross-check with BioTime report) |
| `outside_minutes` | Integer: time between gate pairs inside the day (shown, NOT deducted — D2). Use BioTime `punch_state` (0 = in, 1 = out) when the device sends it; if not, pair punches in order and set flag `outside_estimated` |
| `in_latitude` / `in_longitude` | Float (10,7): GPS of the punch used as check-in (mobile only; empty for gate) |
| `out_latitude` / `out_longitude` | Float (10,7): GPS of the punch used as check-out |
| `in_map_url` / `out_map_url` | Char computed (not stored): `https://maps.google.com/?q=<lat>,<lng>` when GPS exists — shown with `widget="url"` |
| `in_distance_m` / `out_distance_m` | Integer: metres from the employee's project site (`project_id` coordinates) when both exist; else empty |

### D. Calculation (res)
| Field | |
| --- | --- |
| `late_minutes`, `early_minutes`, `excused_minutes`, `worked_hours` | existing |
| `deductible_minutes` | late + early − excused (never < 0) |
| `missing_out` | Boolean (from flag) |
| `flags` | existing, + `wrong_tz` |

### E. Requests & leave (res)
| Field | |
| --- | --- |
| `jm_request_id` | Many2one `employee.requests` |
| `jm_kind` | Selection `full_day`, `morning`, `afternoon` |
| `tp_request_id` | Many2one `employee.requests` |
| `tp_window` | Char `15:00–17:00` |
| `tp_hours` | Float |
| `leave_id`, `leave_code` | existing |
| `leave_name` | Char (leave type name) |
| `leave_paid` | Selection `paid`, `unpaid`, `sick`, `annual` (from payroll engine meta) |
| `leave_half` | Selection `am`, `pm`, False |
| `request_summary` | Char, e.g. `JM morning #18812 · TP 15–17 #18840` |

### F. Odoo today vs shadow (cmp)
| Field | |
| --- | --- |
| `compare_status`, `compare_reason`, `odoo_attendance_ids` | existing |
| `odoo_row_count` | Integer |
| `odoo_type` | Char (types of the Odoo rows, comma list) |
| `odoo_check_in` / `odoo_check_out` | Datetime of the row payroll would pick (latest `write_date`, same rule as the engine) |

### G. Payroll preview (res) — **amount fields visible only to `hr_payroll_community.group_hr_payroll_community_manager`**
| Field | |
| --- | --- |
| `payroll_bucket` | Selection mirroring the engine metrics: `present`, `off_day`, `absent`, `annual_leave`, `sick_leave`, `paid_leave`, `unpaid_leave`, `jm`, `tp`, `no_record` |
| `work_entry_code` | Char (`WORK100`, `LEAVE100`, `LEAVE210`, `OFFDAY`, …) as the engine would use |
| `day_amount` | Monetary: daily salary as the engine computes it (`total_salary / days in month`), 0 for unpaid/absent/off as the engine does — **groups = payroll manager** |
| `late_amount` | Monetary: engine `_get_late_amount(snapshot, deductible_minutes)` — **groups = payroll manager** |
| `currency_id` | related company currency |

Use the engine's own helpers (`_build_contract_snapshot_map`, `_get_daily_salary_amount`, `_get_late_amount`,
`_is_weekly_off_day`, leave meta) through `self.env['elrace.staff.payroll.engine']` — never re-implement the
salary formula. Load snapshots once per `resolve_range` (batched by contract). If the employee has no running
contract: `payroll_bucket = no_record`, amounts 0, flag `no_contract`.

With these fields, summing a month per employee gives the same metrics the payslip shows (present days, absent,
leave days, late minutes, late amount) — the base for the Phase 4 "shadow vs payslip" check.

### H. Audit (existing)
`state`, `resolved_at`, `rule_version`, `error`.

## Views

All views: `create="0" edit="0" delete="0"`, no buttons except the existing "Rebuild" server action
(system group only). User timezone display for all datetimes.

### Tree (`elrace.attendance.day` list) — "Daily Attendance"
- Default columns: Date, Weekday, File No, Employee, Department, Project, Day Type, Check In, In Source, Check
  Out, Out Source, Late (min), Early (min), Worked (h), Requests (`request_summary`), Payroll Bucket, Compare
  Status, Flags.
- `optional="hide"` columns (HR can switch on): Job, Attendance Mode, BioTime Code, Schedule start/end, Punch
  Timeline, Gate/Mobile counts, Outside (min), Excused (min), Deductible (min), Leave name/paid/half, TP window,
  Odoo Type, Odoo In/Out, Odoo rows, Compare Reason, Work Entry Code, Day Amount*, Late Amount*, State.
  (*payroll manager only)
- Decorations by the nature of the record (first match wins in this order):
  - `decoration-danger` + bold: `compare_status` in (diff, no_odoo_row, duplicate_odoo_rows) or `state == 'error'`
  - `decoration-danger`: `day_type == 'absent'`
  - `decoration-warning`: `late_minutes > 0` or `missing_out` or `early_minutes > 0`
  - `decoration-info`: `day_type == 'leave'`
  - `decoration-primary`: `day_type` in (jm_full, jm_half) or `tp_request_id`
  - `decoration-muted`: `day_type` in (off, holiday, not_yet)
  - `decoration-success`: `compare_status == 'match'` and no flags
- Badges (`widget="badge"` with the same decoration attributes) on Day Type, Payroll Bucket, Compare Status,
  In Source / Out Source (gate = info, mobile = primary, policy = muted).
- Coordinates: `in_latitude`, `in_longitude`, `out_latitude`, `out_longitude`, `in_distance_m`,
  `out_distance_m` as `optional="hide"` columns; map links in the form.
- Sum aggregators on minutes, hours and amounts.

### Search view
- Filters: Today, Yesterday, This Week, This Month, Last Month (on `day_date`); Working Days; Needs Attention
  (`compare_status != match` OR `flags != False` OR `day_type == absent`); Late; Missing Check-out; Out Only; On
  Leave; JM; TP; Absent; Wrong TZ; Gate / Mobile / No attendance mode; Errors.
- Search fields: Employee, File No, BioTime Code, Department, Project, Job, Request.
- Group by: Date, Employee, Department, Project, Day Type, Payroll Bucket, Compare Status, Compare Reason,
  Attendance Mode, Month (`day_date:month`).
- Default filter: Yesterday + Working Days.

### Form — one complete record
- Header: status bar on `day_type` (read-only), smart counters: Punches, Odoo rows, Requests.
- Title: Employee — Date (Weekday).
- Groups: Employee (A) | Day & schedule (B).
- Notebook tabs:
  1. **Summary** — check in/out with source and device, late/early/excused/deductible, worked hours, flags,
     request summary, payroll bucket, compare status + reason in a coloured alert box when not match.
  2. **Punches** — `punch_ids` list (local time, source, device/terminal, GPS lat/lng, upload time, ignored),
     punch timeline, outside minutes; check-in / check-out GPS with map links (`widget="url"`) and distance from
     the project site.
  3. **Requests & Leave** — JM / TP / leave fields with links to the records.
  4. **Odoo today** — `odoo_attendance_ids` list (type, in, out, terminal, create date) + compare fields.
  5. **Payroll preview** — bucket, work entry code, day amount*, late amount* (*group-restricted).
  6. **Technical** — state, resolved_at, rule_version, error.

### Pivot + graph
- Pivot default: rows Department, columns Payroll Bucket, measure count; measures available: late minutes,
  deductible minutes, worked hours, late amount*, day amount*.
- Graph: bar, Day Type by Date.

### Raw Punches (`elrace.attendance.punch`) — tree + form, read-only
Local date, punch time, employee, emp_code, source, terminal alias/SN, punch state, GPS, upload time, ignored.
Filters: Gate, Mobile, Unlinked (no employee), Today, Yesterday. Group by local date / source / employee.

### Compare Runs (`elrace.attendance.compare.run`) — tree + form, read-only.

## Menu (under the existing top menu `cubes_biotime.action_biotime_root_menu` "Biotime")

```
Biotime
├── Biotime Config / Terminals / Employees   (existing, unchanged)
└── Attendance Audit                          (new, sequence 10)
    ├── Daily Attendance   → Attendance 360 (tree, form, pivot, graph)
    ├── Raw Punches
    └── Compare Runs
```
Groups on "Attendance Audit": `hr_attendance.group_hr_attendance_manager`, `base.group_system`. Payroll amount
fields additionally restricted by field `groups=`. Do not touch existing menus/views.

## Resolver changes

- Fill all new (res) fields in `_resolve_day` (pure) from the batched context: add employee/BioTime mapping,
  project, terminal alias + GPS from punches, holiday names, request ids, contract snapshots.
- Compare fills the new (cmp) fields.
- Values that change only by display (e.g. `punch_timeline`) are part of the changed-values diff, so reruns stay
  idempotent.
- After upgrade: rebuild the last 31 days once (shell or the server action) so old rows get the new columns.

## Backfill from 1 Oct 2026 (shadow only — hr.attendance is NOT changed)

The ledger only holds punches from 4 Nov. To see October in the shadow table:

1. **Gate punches** — the Lambda now accepts `"ledger_only": true` (commit 789de1c): it fetches BioTime for the
   range and stores punches in the ledger only (no `hr.attendance` writes). The user runs it day by day.
2. **Mobile punches** — new method `elrace.attendance.punch.backfill_mobile_punches(date_from, date_to)`
   (system group only): for each `hr.attendance` row with `x_attendance_type = 'mobile'` in the range, create
   `mobile:<att_id>:in` / `:out` punches from `check_in` / `check_out` + `check_in_latitude/longitude`,
   `check_out_latitude/longitude` — the SAME refs the live hook uses, so it is idempotent. Flag those punches
   `backfilled = True` (new Boolean on the punch). Note: the old Lambda overwrote some mobile rows' times with
   gate times, so backfilled mobile times can be gate times — the punch keeps `backfilled` so HR knows.
3. Then `resolve_range(staff, 2026-10-01, today)` + `compare.run(...)` in chunks (cron-style commits).

## Gaps found before implementation (handle them in this task)

1. `day_amount` must follow the engine exactly: the engine pays a daily amount for present and policy (JM/TP)
   days and adds 0-amount lines for leave/absent/off. Mirror that; do not invent amounts for leave days. Add the
   leave paid/unpaid split only as a label (`leave_paid`).
2. `odoo_check_in/out` = the row the engine would pick (`write_date desc, create_date desc, id desc`), so the
   preview matches payroll even while duplicates exist.
3. `attendance_mode`: mobile access field on `hr.employee` — verify its real name (`mobile_access` was seen in
   `elrace_backend_apis`); if missing, derive `mobile` from having any mobile punch in the last 30 days.
4. `project_id` on the shadow row is a snapshot at resolve time; a later rebuild of an old day would take the
   CURRENT project. Keep the stored value on rebuild if the day is older than 2 days and already has one.
5. Distance needs project coordinates: verify the project latitude/longitude field names used by the A1
   location rule in `attendance_service.py` and reuse that helper.
6. Payroll preview needs the contract snapshot per month: build it once per (contract, month) in
   `_load_context`, never per day.
7. Employees with `wrong_tz` keep the flag even after the tz fix only if `employee.tz` still differs.

## Tests

- `_resolve_day`: punch timeline + outside minutes for gate in/out/in/out; device text for gate and mobile;
  JM morning + TP fields; leave paid/unpaid/half; payroll bucket for each day type; no contract → `no_record`.
- Payroll preview equals the engine: for one employee-month, the sum of `day_amount` / `late_amount` and bucket
  counts equals `elrace.staff.payroll.engine` metrics for the same month (build a payslip-less check by calling
  the engine's payload builder with the same inputs).
- Mobile backfill: idempotent (twice = same count), refs match the live hook.
- Map URL and distance computed from GPS + project coordinates.
- Access: a user in attendance manager but NOT payroll manager cannot read `day_amount` / `late_amount`.
- Views load (`fields_view_get` for tree/form/search/pivot/graph) without errors.

## Report back

Files changed, screenshots are not possible — instead list the tree default columns and filters as built,
how to test, and anything in the engine helpers that could not be reused as-is.

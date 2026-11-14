# TASK P2_5 — Read-only views (ONLY after the user approves this UI)

Module `elrace_attendance_ledger`. Skip this task unless the user has approved it.

## Menu

Attendances → **Attendance Audit** (groups: `hr_attendance.group_hr_attendance_manager`,
`base.group_system`):

- **Raw Punches** → `elrace.attendance.punch`
- **Shadow Days** → `elrace.attendance.day`
- **Compare Runs** → `elrace.attendance.compare.run`

## Views (all `create="0" edit="0" delete="0"`, no buttons)

- Raw Punches list: local date, punch time, employee, source, terminal alias, emp_code, ignored.
  Search: employee, emp_code, source filter (Gate / Mobile), "Unlinked" (employee not set), group by local
  date / source / employee.
- Shadow Days list: date, employee, day type, check in/out, in/out source, late, early, flags, state,
  compare status, compare reason. Decorations: `diff`/`no_odoo_row`/`duplicate_odoo_rows` red, `match`
  green. Search filters per compare status and day type; group by date / compare status / reason.
  Form (read-only): all fields + the punches, requests, leave and Odoo rows used.
- Compare Runs list: date, counts per status, duration.

No change to existing menus or views.

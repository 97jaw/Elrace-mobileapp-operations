# Human Resource — Widget Development Plan

## Overview

This category contains 3 widgets that surface attendance, workforce, and timesheet information for the logged-in employee. All three are configured through the existing `emp_mobile_conf` widget model and served via the `elrace_backend_apis` module.

**Widgets in this category**
1. Attendance (half width)
2. HRMS (half width — sits next to Attendance in the same row)
3. Timesheet (full width — own row below)

**Frontend reference:** `screen2_v7` — Human Resource section. Visuals, gradients, icons, faded background patterns, and inline data displays must match the approved design pixel-for-pixel.

---

## Widget model configuration (emp_mobile_conf)

Three new records (or updates to existing ones) in the widget model.

| Field | Attendance | HRMS | Timesheet |
|---|---|---|---|
| code | `attendance` | `hrms` | `timesheet` |
| name | Attendance | HRMS | Timesheet |
| category | `human_resource` | `human_resource` | `human_resource` |
| sequence | 1 | 2 | 3 |
| size | `half` | `half` | `full` |
| icon | fingerprint | users | clock-check |
| theme_color | blue (#3E7BFA) | coral (#E63946) | amber (#D4A82A) |
| is_active | True | True | True |
| role_ids | All employees | HR roles, managers | Site engineers, supervisors, HR |
| is_hub | False (mobile only initially) | False | False |

Endpoint resolver maps `code` → service method that returns the widget payload. One endpoint pattern across the module; the service layer carries the business logic per widget.

---

## Widget 1: Attendance

### Frontend (must match v7)
- Half-width card, gradient: `#C5DFF8 → #DCE9F7 → #E8F2FC → #F7FAFE` with white highlight top-left
- Fingerprint pattern faded at bottom-right (opacity ~0.7)
- Blue glass icon container top-right with fingerprint icon
- Top text: small uppercase label "Attendance", title "May"
- Big number: "22/24" (present / working days)
- Trend below in green: "92% present"
- Week-dot row at bottom: 7 small rounded cells (S M T W T F S) — present days filled blue, today filled navy with white text, future empty grey

### Backend business logic
- **Source models:** `hr.attendance`, `hr.employee` (`identification_id` resolved from middleware header `X-Hub-Odoo-Id` or current `request.env.user.employee_id`)
- **Working days in current month:** count of weekdays in month minus public holidays (Odoo's `resource.calendar` for the employee can supply this if configured; otherwise default to all weekdays for the month).
- **Present days this month:** distinct `check_in.date()` for the employee within current month.
- **Percentage:** `present / working_days * 100`, rounded to integer.
- **Week dots:** last 7 days ending today.
  - Each day → present (any `hr.attendance` record with `check_in.date() == day`), today (highlighted regardless of present), or empty.
  - Day labels = first letter of weekday in user locale.

### Edge cases
- Month start: if today is the 1st, "present" may be 0 or 1 — still return a valid week dot list.
- No attendance recorded yet today: today's dot stays "today" (highlighted) but not "present".
- Employee on leave: leave days do not count as present and do not count against the working-days denominator (subtract approved leaves from denominator).
- Multiple check-ins on the same day count as one "present" day.

### API contract (data only)
- Input: employee resolved from middleware (no client-passed employee_id).
- Output payload contains: `present_days`, `working_days`, `percentage`, `month_label`, `week_days[]` where each entry has `letter`, `is_present`, `is_today`.
- Errors: if employee not found → standard 404 envelope; if no records → return zeros, never null arrays.

### Tap behavior (frontend)
Opens detailed Attendance screen (existing or to be built) showing month calendar, check-in/check-out timeline, and approved leaves.

### Caching
Lazy cache in `hub.widget.cache` keyed by `(employee_id, widget_code, current_month)`. TTL: 5 minutes (attendance updates frequently). Invalidated on `hr.attendance` create/write/unlink for the employee.

### Acceptance criteria
- Numbers match Odoo backend reports for the same employee/month.
- Week dots correctly show today highlighted even when no record yet.
- Card renders identically to v7 mock on iPhone 13/14/15 widths.
- Loading skeleton uses the same gradient base.

---

## Widget 2: HRMS

### Frontend (must match v7)
- Half-width card sitting beside Attendance
- Gradient: `#FFE8E5 → #FFCFC9 → #F5B7B1 → #E8A8A2` (coral/rose)
- Faded people-network pattern bottom-right (3 circles connected by lines, white at opacity ~0.7)
- Red gradient icon container top-right with HR users icon
- Top label "Employees", title "HRMS"
- Big number: "142" total employees
- Trend in red: "▲ 8 hired this month"
- Two soft white pill chips below: "5 depts" "3 sites"

### Backend business logic
- **Source models:** `hr.employee`, `hr.department`, project / site model (Elrace site model where workers are assigned).
- **Visibility scope:** HRMS widget shows company-wide totals for HR managers and managers; for regular employees it shows their own department's counts only. Driven by role_ids on the widget config + employee's role line.
- **Total employees:** count of `hr.employee` where `active = True` (scoped per role above).
- **New hires this month:** count where `create_date` (or `joining_date` custom field if present) is in the current month.
- **Departments count:** distinct `department_id` of active employees in scope.
- **Sites count:** distinct active sites with at least one assigned worker (Elrace site model). For non-managers this is just the employee's assigned site(s).

### Edge cases
- Department with no manager assigned: still counted.
- Employees without a department: counted in total but not in department list.
- Inactive (archived) employees never counted.
- Future hires (joining_date later this month but `create_date` already passed) still count when joining_date arrives, not before — preference depends on business decision (recommendation: use `joining_date`).

### API contract (data only)
- Input: employee from middleware → resolves scope (manager vs self) automatically.
- Output payload: `total_employees`, `new_hires_count`, `departments_count`, `sites_count`, `top_sites[]` (max 2 site names + "+N more" if exceeding 2), `scope` ("company" or "department").

### Tap behavior
Opens HRMS module landing screen — employee directory with filters.

### Caching
Lazy cache keyed by `(employee_id, widget_code, scope, current_month)`. TTL: 1 hour. Invalidated on `hr.employee` create/write/unlink and `hr.department` changes.

### Acceptance criteria
- Numbers match Odoo HR module reports.
- Scope correctly differs between manager-role and employee-role users.
- Coral gradient + people-network pattern renders identically to v7.

---

## Widget 3: Timesheet

### Frontend (must match v7)
- Full-width card, single row of its own
- Gradient: `#FAF6EC → #F5F0E0 → #E8E0CC → #DBD2B5` (cream/beige)
- Yellow helmet shape decoration bottom-right with subtle inner highlight
- Amber icon container top-right with clock-check icon
- Top label "Timesheet", title "This Week · 15 Workers"
- Three-column stat row separated by vertical gradient dividers:
  - Total Hours: "142h" (navy)
  - Overtime: "12h" (amber)
  - Avg / Worker: "9.4h" (navy)
- Trend at bottom in green: "▲ 5h vs last week"

### Backend business logic
- **Source models:** `account.analytic.line` (Odoo timesheet entries), `hr.employee`.
- **Visibility scope:** for site engineers / supervisors → all workers under their site(s); for HR / managers → company-wide or selectable; for individual employees → only their own hours (the widget then becomes single-stat focused).
- **Week range:** Monday 00:00 → Sunday 23:59 of current week (configurable per company calendar).
- **Total hours:** sum of `unit_amount` across all timesheet lines in scope for the week.
- **Overtime hours:** any hours per employee per day beyond the standard daily working hours (typically 8h, but read from `resource.calendar.hours_per_day` if defined). Sum the excess.
- **Workers count:** distinct employees with at least one timesheet line in the week.
- **Avg per worker:** `total_hours / workers_count`, rounded to one decimal.
- **Week-over-week delta:** total_hours_this_week − total_hours_last_week.

### Edge cases
- No timesheet lines yet this week: return zeros for all stats but still show the card.
- Workers with timesheets in last week but not this week: not counted in current workers but used for delta.
- Multi-project employees: their hours roll up correctly across projects.
- Public holiday in week: still counted; overtime rules unchanged.

### API contract (data only)
- Input: employee from middleware → resolves scope.
- Output payload: `total_hours`, `overtime_hours`, `avg_per_worker`, `workers_count`, `week_label`, `delta_vs_last_week` (positive or negative number), `scope`.

### Tap behavior
Opens Timesheet module — daily breakdown by worker with the ability to approve/edit.

### Caching
Lazy cache keyed by `(employee_id, widget_code, scope, current_iso_week)`. TTL: 30 minutes. Invalidated on `account.analytic.line` create/write/unlink for any employee in scope.

### Acceptance criteria
- Hours match the Timesheet module reports for the same week and scope.
- Overtime calculation respects employee-specific working calendar if defined, defaults to 8h otherwise.
- Cream gradient + yellow helmet shape render identically to v7.

---

## Common to all 3 widgets

### Shared dependencies
- `hr.employee` (must be linked from middleware-resolved user via `X-Hub-Odoo-Id` header or session user).
- `resource.calendar` (optional — improves working days & overtime accuracy).
- Existing services layer in `elrace_backend_apis` (thin controllers, business logic in service classes).

### Permissions
- Service-token authentication via existing middleware.
- Per-widget role check before returning data — if the widget config's `role_ids` do not include any of the requesting employee's roles, return empty / not-authorized envelope.

### Sequencing (build order)
1. **Attendance first** — simplest logic, most-used data, validates the pattern.
2. **Timesheet second** — extends attendance pattern with aggregation.
3. **HRMS last** — most permission-sensitive, scope-aware.

### Testing checkpoints
- Backend unit test per service method with known fixtures (5 employees, known attendance and timesheets, verify exact counts).
- Postman collection covering: regular employee, manager, HR manager, no-data scenario, cross-month boundary.
- Flutter golden-test snapshots for each widget rendering against the v7 reference.
- End-to-end test: employee checks in → Attendance widget shows updated `present_days` within cache TTL.

### Out of scope (for this iteration)
- Real-time push updates when attendance changes (polling/refresh-on-pull-down is sufficient).
- Per-day overtime breakdown inside the Timesheet widget (only weekly totals shown; details live in the module).
- Custom date range selection (current month / current week is the default; date selector lives in the module screens).

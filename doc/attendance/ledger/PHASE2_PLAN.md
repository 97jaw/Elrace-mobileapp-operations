# Attendance — Phase 2: resolver in shadow mode

Design: https://claude.ai/artifact/VnYdD3J4Md7XKjncijpAbg (sections "Proposed design" and "Rollout plan").
Phase 1 (punch ledger) is live: `elrace.attendance.punch`, flag `attendance.ledger_enabled`.

## Goal

Build ONE day record per staff employee per date from all sources — ledger punches (gate + mobile),
approved JM / TP requests, approved leaves, public holidays, weekly off — into a separate **shadow**
table, and compare it every day with today's `hr.attendance` rows. Nothing that payroll, HR, the mobile
app or the Lambda uses changes in this phase.

## Where

- Repo `odoo14-clients`, worktree `.worktrees/elrace-addons`, branch `elrace-addons`. No branch
  create/switch, no commit — the user commits.
- Extend module `elrace_attendance_ledger` (version → `14.0.2.0.0`). No change to `cubes_biotime`,
  `elrace_backend_apis`, payroll, or the Lambda.

## Tasks, in order

| Task | What |
| --- | --- |
| [TASK_P2_1](TASK_P2_1_shadow_model_config.md) | Shadow day model + resolver settings (system parameters) |
| [TASK_P2_2](TASK_P2_2_resolver.md) | Resolver: one day for one employee, pure and testable |
| [TASK_P2_3](TASK_P2_3_runs_and_triggers.md) | Nightly run, request/leave triggers, manual rebuild |
| [TASK_P2_4](TASK_P2_4_compare_report.md) | Daily compare: shadow vs `hr.attendance`, with a reason per difference |
| [TASK_P2_5](TASK_P2_5_readonly_views.md) | Read-only list views + menu for Raw Punches and Shadow Days (**only if the user approves the UI**) |

## Rules for every task

- Flag `attendance.resolver_shadow` (default `False`) gates every automatic run and trigger.
  Manual methods may run with the flag off (for testing in `odoo shell`).
- Read `hr.attendance`, `hr.leave`, `employee.requests`, `public.holidays`, contracts and calendars;
  NEVER write to them.
- Staff only: `hr.employee.is_labor = False`, active.
- All rule values come from system parameters (TASK_P2_1), not constants, so the audit (D1–D7) can change
  them without code.
- Timezone: the employee's `tz`, fallback `Asia/Dubai`. Store datetimes in UTC.
- Odoo 14 APIs only. Batch reads (no per-employee search inside per-day loops); one employee-month must
  resolve in well under a second.
- A failure for one employee-day is logged and stored on that shadow row (`state = 'error'`), never stops
  the run.

## Phase 2 exit gate

The compare report runs every night without errors for 5 working days, and every difference has a reason.
Then: manager/HR audit of D1–D7, then one payroll month of shadow vs BioTime before Phase 4.

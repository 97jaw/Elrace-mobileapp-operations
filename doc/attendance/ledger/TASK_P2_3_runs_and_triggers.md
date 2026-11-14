# TASK P2_3 — Runs and triggers

Module `elrace_attendance_ledger`. Depends on TASK P2_2.

## Nightly run (cron)

`data/cron.xml`: "Attendance shadow — nightly resolve", model `elrace.attendance.resolver`,
`model.cron_nightly()`, daily, first run tomorrow 03:15 Dubai (23:15 UTC), active.

```python
def cron_nightly(self):
    if not shadow flag: return
    # yesterday + the 6 days before it (late uploads, late approvals), all active staff
    self.resolve_range(staff, today - 7, today - 1)
    self.env['elrace.attendance.compare'].run(today - 7, today - 1)   # TASK P2_4
```

Use a Postgres advisory lock (`pg_try_advisory_xact_lock`) so two runs never overlap; process employees
in chunks of 100 with `self.env.cr.commit()` after each chunk (cron only), so one long run does not hold
one huge transaction.

## Intraday refresh (cron)

"Attendance shadow — today", every 30 minutes, `model.cron_today()`: when the flag is on, resolve today
only for employees with a punch created in the last 35 minutes (search the ledger by `create_date`).

## Triggers (when the flag is on)

Override `write` on `employee.requests` and `hr.leave` (in this module, `_inherit`): after `super()`, if
`status` / `state` / dates / `jm_radio` / `temp_*` changed, add the affected employee + date range to a
queue and resolve it **after commit** with `self.env.cr.after('commit', fn)` (Odoo 14 API; verify it
exists in this codebase before using it). Inside `fn` open a new cursor with
`self.env.registry.cursor()` and `api.Environment(new_cr, SUPERUSER_ID, {})`. A trigger failure is logged only;
it must never block approving a request or a leave.

## Manual

- `resolve_range` callable from `odoo shell` with the flag off (testing).
- Server action "Rebuild shadow days" on `hr.employee` (list action, `base.group_system` only) that asks for
  nothing and rebuilds the last 31 days for the selected employees. (Server action only — no new screen.)

## Tests

- Flag off → crons do nothing.
- Approving a JM request for a date with punches changes that shadow day to `jm_*` after commit
  (use a test that commits or calls the queued function directly).
- Two overlapping `cron_nightly` calls: the second returns immediately.

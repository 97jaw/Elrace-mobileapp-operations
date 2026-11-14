# TASK P1_1 — Punch ledger module (Odoo)

Repo `odoo14-clients`, branch `elrace-addons`. New module `elrace_attendance_ledger`.

## Why

Today each writer (Lambda, mobile API) decides on its own whether a day row exists, so rows get lost,
overwritten or duplicated. The ledger stores every raw punch once, unchanged, so a later resolver can build
one day record from all of them. This task only stores punches; it does not touch `hr.attendance`.

## Module

- `__manifest__.py`: name "El Race Attendance Ledger", version `14.0.1.0.0`,
  depends `['base', 'hr', 'hr_attendance', 'cubes_biotime']`, data: `security/ir.model.access.csv`,
  `security/groups.xml`, `data/ir_config_parameter.xml`. No views, no menus (needs approval later).
- `data/ir_config_parameter.xml` (`noupdate="1"`): `attendance.ledger_enabled` = `False`.

## Model `elrace.attendance.punch`

`_description = "Attendance Punch (raw)"`, `_order = "punch_time desc, id desc"`, `_log_access` default.

| Field | Type | Notes |
| --- | --- | --- |
| `employee_id` | Many2one `hr.employee`, index, `ondelete='restrict'` | Empty when the BioTime code is not linked |
| `punch_time` | Datetime, required, index | UTC, seconds kept |
| `local_date` | Date, required, index | Date of the punch in the employee's tz (fallback `Asia/Dubai`) |
| `source` | Selection `gate`, `mobile`, `manual`, required, index | |
| `source_ref` | Char, required | BioTime transaction id, or `mobile:<attendance_id>:in` / `:out` |
| `emp_code` | Char, index | BioTime code as received |
| `punch_state` | Char | Device state as received (not interpreted) |
| `terminal_sn`, `terminal_alias` | Char | |
| `upload_time` | Datetime | When the device uploaded it (UTC); empty for mobile |
| `latitude`, `longitude` | Float (digits 10,7) | Mobile only |
| `attendance_id` | Many2one `hr.attendance`, `ondelete='set null'` | The row the mobile tap wrote; empty for gate |
| `ignored` | Boolean, default False | Never delete a punch; mark it ignored |
| `ignore_reason` | Char | |
| `company_id` | Many2one `res.company`, default current company | |

SQL constraint: `unique(source, source_ref)` — message "This punch is already stored."

No `write` on `punch_time`, `employee_id`, `source`, `source_ref` after create (override `write` and raise
`UserError` if any of these keys are in vals) — raw data stays raw. `ignored` / `ignore_reason` may change.

## Methods

```python
@api.model
def ledger_enabled(self):
    return self.env['ir.config_parameter'].sudo().get_param('attendance.ledger_enabled', 'False') == 'True'
```

```python
@api.model
def ingest_gate_punches(self, rows, tz_name='Asia/Dubai'):
    """Called by the Lambda through call_kw. Idempotent.
    rows: list of dicts straight from BioTime /iclock/api/transactions/:
          id, emp_code, punch_time ('YYYY-MM-DD HH:MM:SS' local), punch_state,
          terminal_sn, terminal_alias, upload_time (local, may be empty)
    Returns {'enabled': bool, 'received': n, 'created': n, 'duplicates': n, 'rejected': [{'id':..,'reason':..}]}
    """
```

Rules:

1. If `ledger_enabled()` is False → return `{'enabled': False, ...zeros}` and store nothing.
2. Caller must be in group `elrace_attendance_ledger.group_punch_ingest` (see Security) or be superuser;
   otherwise `AccessError`.
3. Map `emp_code` → employee through `biotime.employee` (`emp_code`, `odoo_employee_id`); build the map
   once per call. Unmapped codes are stored with `employee_id = False`.
4. Parse `punch_time` with `datetime.strptime(s[:19], '%Y-%m-%d %H:%M:%S')`, localize with `tz_name`, store
   UTC. A row that does not parse goes to `rejected` with reason — never use "now".
   `local_date` = the parsed local date. Same for `upload_time` when present.
5. `source = 'gate'`, `source_ref = str(row['id'])`. Rows without `id` → `rejected`.
6. Skip refs that already exist: one `search_read` on `source='gate'` and `source_ref in [...]` per batch,
   then `create` the rest in one `create(list)` call. Count those as `duplicates`.
7. Process at most 2000 rows per call (Lambda sends batches of 500).
8. Use `sudo()` for the writes after the group check; `with_context(tracking_disable=True)`.

```python
@api.model
def record_mobile_punch(self, attendance, kind, lat=None, lng=None):
    """kind: 'in' | 'out'. Called by the mobile API after a successful check-in/out. Never raises."""
```

- Returns False without doing anything when the flag is off.
- `punch_time` = `attendance.check_in` for `in`, `attendance.check_out` for `out` (both are server time
  since A1). `local_date` from the employee tz. `source_ref = f"mobile:{attendance.id}:{kind}"`.
- If the ref exists, return the existing record (idempotent). Wrap everything in
  `try/except Exception` with `_logger.exception` and return False on error, inside a savepoint
  (`with self.env.cr.savepoint():`) so a failure can never roll back the check-in.

## Security

- `security/groups.xml`: group `group_punch_ingest` "Attendance punch ingest (Lambda)", no implied groups.
  The user adds the Lambda's Odoo user to it after install.
- `ir.model.access.csv`:
  - `hr_attendance.group_hr_attendance_manager`: read only.
  - `base.group_system`: read, write (for `ignored`), no create, no unlink.
  - `group_punch_ingest`: read, create.
  - Nobody gets unlink.

## Tests (`tests/test_punch_ledger.py`, `post_install`, `at_install` False)

1. Flag off → `ingest_gate_punches` stores nothing and returns `enabled: False`.
2. Flag on → 3 rows stored with correct UTC (`2026-11-04 08:05:30` Dubai → `04:05:30` UTC) and `local_date`.
3. Same batch sent twice → second call `created: 0`, `duplicates: 3`.
4. Bad `punch_time` → rejected, others stored.
5. Unmapped `emp_code` → stored with empty employee.
6. Writing `punch_time` on an existing punch raises; writing `ignored` works.
7. `record_mobile_punch` twice for the same attendance and kind → one punch.

## Exit-gate queries (for the user, after 5 days with the flag ON)

```sql
-- punches per day and source
SELECT local_date, source, COUNT(*) FROM elrace_attendance_punch
WHERE local_date >= CURRENT_DATE - 7 GROUP BY 1, 2 ORDER BY 1, 2;

-- must return 0 rows (unique constraint should make this impossible)
SELECT source, source_ref, COUNT(*) FROM elrace_attendance_punch
GROUP BY 1, 2 HAVING COUNT(*) > 1;

-- unlinked BioTime codes seen
SELECT emp_code, COUNT(*) FROM elrace_attendance_punch
WHERE employee_id IS NULL GROUP BY 1 ORDER BY 2 DESC;
```

Compare gate counts per day with the BioTime transaction report for the same day.

## Done when

- Module installs and upgrades cleanly on a copy of production; tests pass.
- With the flag OFF nothing is stored and nothing else in the system changes.

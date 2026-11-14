# TASK P1_2 — Mobile check-in / check-out also store a punch

Repo `odoo14-clients`, branch `elrace-addons`, module `elrace_backend_apis`,
file `services/attendance_service.py`. Depends on TASK P1_1.

## Change

`elrace_backend_apis` must NOT get a hard dependency on the new module (it must keep working where the
ledger is not installed). Add one helper in `AttendanceService`:

```python
def _ledger_record(self, att, kind, lat=None, lng=None):
    """Store the raw mobile punch in the ledger when installed and enabled. Never raises."""
    try:
        Punch = self.env.get('elrace.attendance.punch')
        if Punch is None:
            return
        Punch.sudo().record_mobile_punch(att, kind, lat=lat, lng=lng)
    except Exception:
        _logger.exception("ledger: mobile %s punch not stored for attendance %s", kind, att.id)
```

(Odoo 14: `self.env.get(model)` returns `None` when the model is not in the registry; if that is not
available, use `'elrace.attendance.punch' in self.env.registry`.)

Call it:

1. `check_in`: right after the successful `Attendance...create({...})`, before building the response:
   `self._ledger_record(att, 'in', check_in_lat, check_in_long)`.
   Not on the "Already checked in today" path (no new tap was stored there).
2. `check_out`: right after the successful `att...write({...})`:
   `self._ledger_record(att, 'out', check_out_lat, check_out_long)`.
   Not on the "Already checked out" path.

## Must not change

- Request and response shape of both endpoints (old app versions).
- Which `hr.attendance` row is created or written, `_get_today_attendance`, location rule from A1.
- Any error path: a ledger problem is logged only.

## Tests (extend the A1 test file or add `tests/test_ledger_hook.py`)

1. Ledger module not installed / flag off → check-in and check-out work exactly as before.
2. Flag on → one `in` punch and one `out` punch with `source='mobile'`, `attendance_id` set,
   `punch_time` equal to the row's `check_in` / `check_out`.
3. `record_mobile_punch` patched to raise → check-in still succeeds and returns the same response.

## Done when

Tests pass and a manual check-in / check-out from the app (flag on, staging) shows both punches.

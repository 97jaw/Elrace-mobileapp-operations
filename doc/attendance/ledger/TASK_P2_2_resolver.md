# TASK P2_2 — Resolver

Module `elrace_attendance_ledger`, new file `models/attendance_resolver.py`
(AbstractModel `elrace.attendance.resolver`). Depends on TASK P2_1.

## Shape

```python
def resolve_range(self, employees, date_from, date_to):
    """Rebuild shadow days for these employees and dates. Returns stats dict."""

def _load_context(self, employees, date_from, date_to):
    """ONE batched read of everything needed:
       punches (not ignored) by employee+local_date — read a window of date_from-1 .. date_to+1
         and re-assign each punch to its workday with day_start_hour,
       approved JM / TEMP requests overlapping the range,
       hr.leave (state validate / validate1) overlapping the range,
       public.holidays (x_type = 'holiday') overlapping the range,
       contracts + resource calendars (working weekdays, start/end time),
       existing shadow days."""

def _resolve_day(self, employee, day, ctx, settings):
    """PURE function: no ORM writes, no searches. Returns a dict of shadow-day values."""
```

`resolve_range` builds the context once, calls `_resolve_day` for every employee × date, then writes with
one `create` for new keys and `write` only for rows whose values changed. A day that raises → row with
`state = 'error'`, `error = traceback[:2000]`, continue.

## Sources and how to read them

- **Punches**: `elrace.attendance.punch` with `employee_id` set, `ignored = False`. Workday of a punch =
  local date of `punch_time - day_start_hour hours`.
- **JM**: `employee.requests` with `status = 'approve'`, `request_type_id.code = 'JM'`, overlapping
  `[request_date_from, request_date_to or request_date_from]`. `jm_radio`: `full_day`, `morning`,
  `afternoon`. Use the request CODE, never the display name.
- **TP**: `employee.requests`, `status = 'approve'`, `request_type_id.code = 'TEMP'`. Window start =
  `temp_hours` mapped with the same map the request module uses
  (`'1'→13, '2'→14, '3'→15, '4'→16, '5'→17, '6'→18`, others as is), length = `temp_selection` hours.
- **Leave**: `hr.leave`, `state in ('validate', 'validate1')`, overlapping the day. **Exclude** leaves whose
  `employee_request_id` is a JM or TEMP request (the request module creates `hr.leave` rows for those).
  Leave code: reuse `elrace.staff.payroll.engine` helpers `_meta_from_leave_type` +
  `_staff_request_leave_meta` (call through `self.env['elrace.staff.payroll.engine']`) so shadow and payroll
  classify leaves the same way. Half-day leave (`request_unit_half`) → treat like a JM half (D-question,
  flag `half_leave` for now).
- **Holiday**: `public.holidays` with `x_type = 'holiday'`, date in `[date_from, date_to]`.
- **Weekly off / schedule**: same logic as payroll `_is_weekly_off_day` (contract calendar → employee
  calendar → company calendar → Saturday). Scheduled start/end of the day from the calendar's
  `attendance_ids` for that weekday (earliest `hour_from`, latest `hour_to`); fallback settings
  `work_start` / `work_end`.

## Rules, in priority order (first match decides `day_type`)

1. **Approved full-day leave** → `leave`, `leave_code`, `leave_id`. Punches still attached; if any →
   flag `worked_on_leave`.
2. **JM full day** → `jm_full`, `in_source = out_source = 'policy'`, in/out = scheduled start/end.
3. **Holiday** or **weekly off** with no punches → `holiday` / `off`. With punches → `present` + flag
   `worked_on_off`.
4. **JM half**:
   - morning → in = scheduled start (`policy`), out = last punch of the day if any (else flag `missing_out`).
   - afternoon → in = first punch if any (else scheduled start, `policy`), out = scheduled end (`policy`).
   - `day_type = jm_half`; late/early only for the half that comes from punches.
5. **Punches** (any source):
   - in = earliest punch; out = latest punch that is at least `min_out_gap_minutes` after in.
   - only one usable punch → in set, out empty, flag `missing_out`.
   - exception: a single usable punch after the midpoint of the scheduled day (e.g. one 17:30 punch)
     → `present`, `check_out` = that punch, `check_in` empty, flag `out_only`.
   - `late_minutes` = max(0, in − (start + grace)); `early_minutes` = max(0, end − out) when out set.
   - TP (`tp_mode = excuse_window`): minutes of late/early that fall inside the TP window move to
     `excused_minutes`.
   - `in_source` / `out_source` from the punch used.
6. **Nothing above**:
   - day not past cutoff → `not_yet` (`state = open`).
   - past cutoff → `absent`.

More than one approved request of the same kind on a day → use the latest approved, flag
`multiple_requests`.

`state` = `final` when now (local) ≥ day + 1 at `cutoff_hour`, else `open`. A late punch for a `final`
day is simply resolved again (no lock in Phase 2) and adds flag `late_upload` when the punch's
`create_date` is after the cutoff.

## Tests (`tests/test_resolver.py`)

Test `_resolve_day` with hand-built contexts (no DB rows needed) — one test per rule above, plus:
mobile in + gate out on the same day; two gate punches 2 minutes apart (no out); punch at 03:30 belongs to
the previous day; TP 15:00–17:00 excuses an early exit at 15:10; leave + punches flags `worked_on_leave`;
JM morning without evening punch flags `missing_out`; JM/TP `hr.leave` rows are not treated as leave.
Plus one `resolve_range` test on real records: running it twice changes nothing the second time.

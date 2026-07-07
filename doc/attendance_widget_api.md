# Attendance home widget — backend APIs

The HR **Attendance** card loads **current calendar month** stats for the logged-in employee.

## APIs used (in order)

### 1. List (first call)

```
POST https://erp.elrace.com/api/attendance/list
Authorization: Bearer <token>
Content-Type: application/json

{
  "jsonrpc": "2.0",
  "params": {
    "month": 6,
    "year": 2026,
    "limit": 200,
    "offset": 0
  }
}
```

**Fields the widget reads** (grouped / employee mode):

| Field | Purpose |
|-------|---------|
| `result.total_present_days` | Present days numerator |
| `result.total_working_days` | Working days denominator |
| `result.records[]` | Week-dot row + fallback counts |

If `mode` is `flat` or `records` is empty, the app calls **detail** (step 2).

### 2. Detail (fallback — same as Attendance Reports module)

```
POST https://erp.elrace.com/api/attendance/detail
Authorization: Bearer <token>

{
  "jsonrpc": "2.0",
  "params": {
    "employee_id": <login employee_id>,
    "month": 6,
    "year": 2026
  }
}
```

Use this to verify numbers when list returns `0 / —`.

### 3. Login stub (offline / loading only)

```
POST https://erp.elrace.com/api/login/new
→ result.data.default_widgets.data.attendance_widget.record_to_show
   { "present": N, "absent": M }
```

Not used when list/detail succeed. Planned dedicated widget endpoint per `doc/category_01_human_resource.md` (`present_days`, `working_days`, `percentage`, `week_days[]`).

### 4. Summary (HomeBloc legacy — not used by v7 card)

```
POST https://erp.elrace.com/attendance/summary
{ "start_date": "2026-06-01", "end_date": "2026-06-30" }
```

## Quick curl test

Replace `TOKEN` and `EMP_ID`:

```bash
# List
curl -s -X POST 'https://erp.elrace.com/api/attendance/list' \
  -H 'Authorization: Bearer TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","params":{"month":6,"year":2026,"limit":50,"offset":0}}' | jq '.result | {mode,user_type,total_present_days,total_working_days,records_count:(.records|length)}'

# Detail
curl -s -X POST 'https://erp.elrace.com/api/attendance/detail' \
  -H 'Authorization: Bearer TOKEN' \
  -H 'Content-Type: application/json' \
  -d "{\"jsonrpc\":\"2.0\",\"params\":{\"employee_id\":$EMP_ID,\"month\":6,\"year\":2026}}" | jq '.result | {total_present_days,total_working_days,records_count:(.records|length)}'
```

## Expected widget display

- **Big number:** `{total_present_days} / {total_working_days}`
- **Trend:** `{round(present/working*100)}% present`
- **Week dots:** derived from `records[].date` + `day_status` for current week

If list returns zeros but detail has data → backend list endpoint should populate totals for employee scope, or Flutter will keep using detail fallback.

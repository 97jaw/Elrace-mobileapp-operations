# HRMS & Attendance home widgets — backend (elrace_backend_apis)

Deploy from: `/Users/mjawad/projects/elrace/odoo14-clients/elrace_backend_apis`

## New services

| File | Purpose |
|------|---------|
| `services/attendance_widget_service.py` | Current-month `present_days` / `working_days` via `AttendanceService._build_monthly_summary` |
| `services/hrms_widget_service.py` | Direct reports via `hr.employee.parent_id` only (no labor/foreman) |

## New / updated routes

### Live refresh (JWT required)

```
POST /api/widgets/attendance/data
POST /api/widgets/hrms/data
```

Response envelope:
```json
{
  "status": "success",
  "message": "...",
  "data": { ...payload... }
}
```

**Attendance `data`:**
```json
{
  "present_days": 12,
  "working_days": 30,
  "percentage": 40,
  "month_label": "June",
  "month": 6,
  "year": 2026,
  "present": 12,
  "absent": 18
}
```

**HRMS `data`:**
```json
{
  "scope": "manager",
  "direct_reports_count": 8,
  "pending_requests_count": 2,
  "department_name": "R&D",
  "section_name": "Software",
  "headline_count": 8,
  "trend_label": "8 under your team"
}
```

Manager scope when `direct_reports_count > 0` (active employees with `parent_id = login employee`).

### Login payload (`POST /api/login/new`)

- `attendance_widget.record_to_show` — real counts (was stub zeros)
- `hrms_widget.record_to_show` — new key
- `my_request_widget.record_to_show` — real pending counts (was stub zeros)

### Extended directory

`GET /api/employee/listx` now includes per row:
`employee_id`, `parent_id`, `department`, `department_name`, `section`, `section_name`, `job_position`

## Files changed

- `controllers/auth_controller.py`
- `controllers/widget_controller.py`
- `controllers/misc_controller.py`
- `services/__init__.py`

## Deploy steps

1. Copy/sync module to Odoo addons path
2. Upgrade module: `-u elrace_backend_apis`
3. Re-login on mobile (login payload) or hot restart (live widget routes)

## Verify

```bash
TOKEN=...
curl -s -X POST 'https://erp.elrace.com/api/widgets/hrms/data' \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"call","params":{}}' | jq .

curl -s -X POST 'https://erp.elrace.com/api/widgets/attendance/data' \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"call","params":{}}' | jq .
```

# TASK LT2 — APIs (elrace_backend_apis)

Branch `elrace-addons`. Follow existing controller patterns (`_validate_mobile_request`, `_success/_error`, `_ts_access` restrictions, JSON type routes). Bump module version. Add `elrace_labor_transfer` to depends.

| Route | Who | Input | Output |
|---|---|---|---|
| POST /api/labor_transfer/labors | foreman | search (optional), limit/offset | labors in caller's city: id, emp_id, name, photo url, current foreman (id, name), `in_pending_transfer` bool, `in_my_team` bool |
| POST /api/labor_transfer/foremen | foreman | search | foremen (same city first, then others) excluding caller |
| POST /api/labor_transfer/create | foreman | labor_ids, target_foreman_id, note | created + submitted record |
| POST /api/labor_transfer/list | any | box = mine \| to_approve \| incoming, state filter | list with name, state, requester, target, labor count, dates |
| POST /api/labor_transfer/detail | involved users | id | full record incl. labors + previous foremen |
| POST /api/labor_transfer/approve | approver | id | updated record |
| POST /api/labor_transfer/reject | approver | id, reason | updated record |
| POST /api/labor_transfer/cancel | requester | id | updated record |

- Errors use model constraint messages (city mismatch, duplicate pending, no approver).
- Push: implement `_push_notify` with the existing FCM service used by other modules; data payload `{type: "labor_transfer", id, state}` so the app can open the detail.
- After approve, the existing Your Team endpoints (x_labor_ids) already return the new labors — verify.

## Test (curl / Odoo shell)
Each route with valid and invalid users; approve updates `/api/timesheet/my_team`-style responses for both foremen.

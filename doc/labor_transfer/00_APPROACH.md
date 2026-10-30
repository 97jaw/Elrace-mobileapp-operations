# Labor Transfer — Approach

## Flow
1. Foreman A (requester) opens "Labor transfer" in the app, picks labors (any labor in A's city — `hr.employee.city_id` same as A's), picks Foreman B (target, who needs them), adds an optional note, submits.
2. Record created in Odoo, state = `pending`. Approver = **direct manager of the requester** (`requester.parent_id`; fallback `x_foreman_manager_id`). One helper `_get_approver()` so this rule can be changed in one place.
3. Approver sees it in Odoo (Timesheet menu) and in the app → Approve / Reject (reject needs a reason).
4. On approve: every labor's `current_forman` = Foreman B (authoritative field), then B's and each previous foreman's `x_labor_ids` are synced immediately (the cron rebuilds from `current_forman`, so this stays consistent). Mobile "Your Team" updates on next refresh.
5. Notifications (Odoo activity/chatter + mobile push): on submit → approver, Foreman B, previous foremen of the labors; on approve/reject → requester, Foreman B, previous foremen, approver (confirmation).
6. No end date for now (permanent transfer).

## Order
LT1 Odoo module → LT2 APIs → LT3 Mobile. Each step tested before the next.

## Branches
- Backend: `odoo14-clients`, work directly on branch `elrace-addons` (no new branch). New module `elrace_labor_transfer`; APIs in `elrace_backend_apis`. Never touch `pandora_project_timesheets_apis`.
- Mobile: `feature/labor-transfer` from updated `main`.

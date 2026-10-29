# TASK LT1 — Odoo module `elrace_labor_transfer`

Repo `odoo14-clients`, branch `elrace-addons` (no new branch). Odoo 14.

## Model `elrace.labor.transfer` (mail.thread, mail.activity.mixin)
| Field | Type | Notes |
|---|---|---|
| name | Char | sequence `LT/%(year)s/0001`, readonly |
| requester_id | Many2one hr.employee | foreman who creates, required |
| target_foreman_id | Many2one hr.employee | foreman who receives, required, ≠ requester |
| city_id | Many2one city.project | = requester.city_id, readonly, stored |
| labor_ids | Many2many hr.employee | required, domain: same city_id, labor employees (`is_labor` / position type labor) |
| line_ids | One2many `elrace.labor.transfer.line` | snapshot per labor: labor_id, previous_foreman_id (labor.current_forman at submit) |
| approver_id | Many2one hr.employee | computed on create via `_get_approver()` = requester.parent_id or requester.x_foreman_manager_id; stored |
| state | Selection | draft, pending, approved, rejected, cancelled; tracking |
| note | Text | optional |
| reject_reason | Text | required on reject |
| request_date, decision_date | Datetime | |
| decided_by_id | Many2one res.users | |

## Rules / constraints
- All labors must have the same city_id as the requester (constraint).
- A labor can't be in two `pending` transfers (constraint).
- Labor already under target foreman → error.
- No approver found → error on submit ("No direct manager set for <requester>").

## Methods
- `action_submit()` draft→pending, fill line_ids snapshot, notify.
- `action_approve()` (only approver, or group Timesheet Manager): for each labor set `current_forman = target_foreman_id`; sync `x_labor_ids` of target + all previous foremen immediately (same logic the cron uses — reuse it, don't duplicate); state approved; notify.
- `action_reject(reason)`; `action_cancel()` (requester, only while pending).
- `_notify(event)`: chatter message + mail.activity for approver on submit; collect partner ids of requester, target, previous foremen, approver. Leave a hook `_push_notify(employee_ids, title, body, data)` that LT2 implements with the existing mobile push service.

## Views / menu
- Form (statusbar + Submit/Approve/Reject/Cancel buttons by state & user), tree (name, requester, target, city, labor count, state, date), search (state, my approvals filter default: approver_id.user_id = uid & state=pending).
- Menu under the existing Timesheet menu: "Labor Transfers".
- Security: ir.model.access for base user (read own), foreman, timesheet manager; record rules: requester / target / approver / previous foremen see their records; managers see all.

## Do not
- Change `current_forman` / cron logic elsewhere. Touch pandora_* modules.

## Test
Create in Odoo UI: submit → approver sees it in "My approvals" → approve → labors' current_forman = target, target's x_labor_ids include them, previous foreman's removed. Reject path keeps everything unchanged. Constraints fire (different city, duplicate pending).

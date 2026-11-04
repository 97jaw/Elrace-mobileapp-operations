# M8 — App: waiting and progress pushes are never saved in the Notification Center

Mobile repo, branch (approved name only) from up-to-date `main`. Follow
`.cursor/rules/branching-from-main.mdc`. No deploy.

## Rule
| Push | Show | Save in Notification Center |
|---|---|---|
| Waiting for your approval (any level) | ✅ | ❌ |
| Progress: approved at a level / fully approved (requester) | ✅ | ❌ |
| Everything stored by the manager's matrix (HR final approved/rejected, LPO issued, petty cash paid, new employee, project, documents, circulars) and timesheet approval results | ✅ | ✅ (as today) |

## Recognise them (both payload shapes)
- v1 (`nv` set): `type` is `approval.waiting` or `approval.progress`.
- Legacy (today's Odoo sends): approval `model` in `employee.requests`,
  `purchase.order`, `account.move`, `hr.expense.sheet`, `it.hardware.request`
  and `status` in `pending`, `approved`, `approved_final`. Check the real legacy
  payloads in `elrace_dashboard/models/elrace_notification.py`
  (`_notify_pending_reviewer`, `send_tier_review_update`, `validate_tier`
  overrides, HR `send_employee_request_status_update`) and match exactly; keep
  `rejected` stored.
- One helper (e.g. `isPushOnlyApproval(data)`) used by every save path:
  `_saveNotificationToStorage` (foreground, background tap, initial message) in
  `firebase_service.dart` and the background handler in `main.dart`. Same place
  as the existing timesheet skip.

## Keep
Banner, tap routing (router + registry already open the record), mute rules,
counters refresh on approval pushes (Task 7 throttle).

## Done when
Unit tests for the helper with real v1 and legacy payload samples (waiting,
per-level approved, approved_final, rejected, HR final, circular, chat);
`flutter analyze` no new issues; `flutter test` all pass. Push, PR to `main`,
report, stop.

## Commits
1. `docs(notifications): M8 push-only approvals`
2. `feat(notifications): never store waiting and progress approval pushes`

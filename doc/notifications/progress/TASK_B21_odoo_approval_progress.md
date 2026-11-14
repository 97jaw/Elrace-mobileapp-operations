# B21 — Odoo: `approval.progress` (push to the requester at every approval level)

Repo `odoo14-clients`, branch **`elrace-addons`** (production; no new backend
branch). Backup pointer branch before deploy. Follow `elrace_notify` rules:
unique helper names in controllers, `emit()` never raises, seed **inactive**.

## Why
Manager's matrix (28 Oct) keeps only final results. B9 (`_retire_level_mobile`)
removes the per-level "Approved" and "Fully Approved" requester pushes when
`approval.waiting` / `account.vendor_invoice` is taken over. Decision (3 Nov):
the requester gets a **push at every level of the hierarchy, first to final**.
These are **push only** (never stored in the inbox). Stored items stay exactly as
in the manager's matrix.

## Type (seed, inactive: active False, shadow False, takeover False)
`approval.progress` — channel **push**, category `waiting`, mandatory,
exclude_actor, exclude_labour, action `open_record`, dedupe 0.
- intermediate level: title `{request_type} approved by {actor}`,
  body `{reference} — waiting for the next approval`
- final level: title `{request_type} fully approved`,
  body `{reference} has been fully approved`
(Pass `stage` = `level` / `final` in values and pick the template in code, or
seed two templates — keep it simple.)

## Where it fires (requester = same person the legacy code notifies)
| Source | Intermediate | Final |
|---|---|---|
| Invoice (customer + vendor bill), LPO/RFQ, Petty Cash — web `validate_tier` overrides and app `send_tier_review_update` | ✅ | ✅ |
| HR `send_employee_request_status_update` | ✅ | ❌ (final stays `hr.request.approved`, inbox, per matrix) |
| IT request `action_approve` | ✅ | ✅ |

- Same switch as every call site: `takes_over('approval.progress')` → `emit`;
  else legacy unchanged + `shadows()` → `emit(dry_run=True)`.
- `_retire_level_mobile` must also return True when `approval.progress` is taken
  over, so the legacy per-level / fully-approved pushes stop and nothing is sent
  twice. Rejection pushes are not part of this type.
- `event_key = 'progress:tier:<tier.id>'` (HR: the validation line id, IT: the
  approval step) so the web path and the app path (`approval_service.tier_review`
  → `validate_tier` + `send_tier_review_update`) produce **one** push per approval.
- Vendor bills are included (the requester gets progress); the vendor-invoice
  "None" row in the matrix stays for other vendor-bill actions.

## Tests (`elrace_notify/tests`)
Per source: intermediate and final emit once (web path, app path, both run →
one event); actor and labour skipped; HR final emits no progress; shadow →
`shadow_*` event only; takeover → legacy per-level push not called; takeover
off → legacy unchanged.

## Deploy
Backup branch + DB dump, `-u elrace_notify,elrace_dashboard` (new seed data),
restart workers. Then: type `approval.progress` Active + Shadow (takeover off),
watch Events for a day, then Takeover together with / after `approval.waiting`.

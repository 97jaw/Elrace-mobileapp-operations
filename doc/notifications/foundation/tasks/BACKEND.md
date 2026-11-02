# Backend tasks — Odoo (`odoo14-clients`)

Read first: `../01_ARCHITECTURE.md`, `../02_TRIGGER_MATRIX.md`, `../03_ROLLOUT_AND_TESTING.md`.
Repo: `pandoratech-llc/odoo14-clients`. Branch from `origin/elrace-addons`. One task = one branch.
Never touch `elrace_hub_guard`, v1 SSO, or Hub auth flags. All behaviour OFF by default.

**Live-safety rule:** every backend commit must be deployable to production with **zero change for current app users**.
Before each commit, list every code path a live request can hit that changed, and show the flag that keeps it unchanged.
Schema additions (new fields/models) are fine; behaviour changes are not, unless flag-gated (default OFF).

Legacy reference file: `elrace_dashboard/models/elrace_notification.py` (≈3,200 lines; most senders live here).

---

## Phase 1 — Foundation (no behaviour change)

### B1. Module skeleton, models, seed, security

**Scope:** new module `elrace_notify` only.

- `__manifest__.py`: version `14.0.1.0.0`; depends `base`, `hr`, `emp_mobile_conf`, `pandora_expo_notifications`, `elrace_backend_apis`.
- Models per architecture §4: `elrace.notify.type`, `elrace.notify.event`, `elrace.notify.delivery`; extensions of `mobile.notification.category`, `expo.notifications`, `expo.notification.users`, `mobile.device`.
- `data/params.xml` (`noupdate="1"`): every parameter in architecture §8 with its default (secrets empty).
- `data/categories.xml` (`noupdate="1"`): category seed from matrix §3. **Before creating, search by `code`; create only missing ones** (post-init hook) **with `active=False`**, never rename or modify existing rows. (Active categories appear in the live app's mute screen.)
- `data/types.xml` (`noupdate="1"`): every type in matrix §1 with templates, channel, action, category, `hub_category`, all `active=False`, `takeover=False`.
- Security: `base.group_system` full access on new models; no access for normal users (all access via `sudo()` in services/controllers).
- Views: Settings → Technical → Notifications: Types (list/form, editable), Events (list, filters by state/type/user, read-only), Deliveries (read-only).

**Acceptance:** install on staging without errors; existing categories unchanged; new categories inactive; `/api/mobile/notification/categories` returns exactly what it returned before install; all types inactive; no other module modified.

### B2. Dispatcher

**Scope:** `elrace_notify/models/dispatcher.py` (AbstractModel `elrace.notify.dispatcher`) + tests.

```python
emit(type_code, record=None, recipients=None, values=None, actor=None,
     event_key=None, model=None, res_ref=None, screen=None, params=None,
     mandatory=False) -> dict   # {'queued': n, 'skipped': {...}}
takes_over(type_code) -> bool   # master flag AND type.active AND type.takeover
```

Pipeline (architecture §2): master flag → type active → normalise recipients to active `res.users` → filters (labour via `hr.employee.is_labor`, actor, mute via `mobile.notification.preference` unless `mandatory or type.mandatory`) → dedupe (`dedupe_key = sha1(type|model|res_ref|user|event_key)` searched within `dedupe_minutes`) → render (safe `format_map`, missing → `""`, `False/None` → `""`) → create `elrace.notify.event` → inbox row if channel `inbox`/`both` (store `type_code`, `category_code`, `model`, `res_ref`, `action`, `screen`, `params_json`) → delivery rows for every active device of the user if channel `push`/`both` → register postcommit sender (B3) → Hub adapter if `type.hub_category`.

- Every skipped recipient still gets an event row with the reason state (for "why didn't X get it?").
- `emit()` wraps everything in `try/except`, logs, **never raises**.
- `model`/`res_ref` default from `record` (`record._name`, `str(record.id)`).

**Tests:** all of `03_ROLLOUT_AND_TESTING.md` §5.1 that concern the dispatcher.

### B3. Delivery: FCM sender, outbox, Hub adapter

**Scope:** `elrace_notify/services/fcm.py`, `elrace_notify/models/delivery.py`, cron.

- FCM HTTP v1. Credentials from `elrace_notify.fcm_project_id` / `elrace_notify.fcm_service_account_json`; if empty, fall back to `operating.unit` record 6 fields `x_project_id` / `x_service_account_json` (same as legacy `_send_fcm_push`) and log a warning once.
- Build the payload exactly as architecture §5 (all `data` values strings; `record_id` legacy key; Android `channel_id` + `tag=nid`; iOS `thread-id`).
- Postcommit: send queued deliveries of this transaction in a **new cursor**. Cron every minute: retry `failed` with backoff (1, 5, 15 min; max 3 attempts).
- `UNREGISTERED` / `INVALID_ARGUMENT` token → `invalid_token`, clear that `mobile.device.fcm_token`, and clear `res.users.expo_token` if equal.
- Never log full tokens (first 12 chars only).
- Hub adapter: call existing `elrace.notification._push_hub_pending_notification(user/users, title, body, category=type.hub_category, record=record, event=...)` postcommit. Do not modify that method.
- Optional silent sync (`elrace_notify.inbox_silent_sync`): for inbox-only events send data-only `{nv:"1", type:"inbox.sync"}`.

**Acceptance:** with a test type active on staging, a push reaches two devices of one user; invalid token is cleaned; Hub receives a pending item for a type with `hub_category`.

### B4. Device registry, logout, token security

**Scope:** `elrace_notify/controllers/devices.py`; small edits in `elrace_backend_apis` (listed below).

- `POST /api/v2/notifications/device/register` `{device_id, fcm_token, platform, app_version}`: upsert `mobile.device` for (employee, device_id); set token, clear `logged_out_at`; **remove the same token from any other `mobile.device` and from any other user's `expo_token`**; also set `res.users.expo_token` (legacy senders) only if different (keep the serialization-safe write pattern of `/api/save_expo_token`).
- `POST /api/v2/notifications/device/unregister` `{device_id}`: clear `fcm_token`, set `logged_out_at`; clear `res.users.expo_token` if it equals this token.
- `elrace_backend_apis/controllers/linked_devices_controller.py` `logout-current` and remote logout (`linked_devices_logout`, `logout_others`): also clear the token of the affected device(s) (same helper) **only when `elrace_notify.device_lifecycle` is True**. Additive change. The same flag gates moving a token away from a previous user on `/api/save_expo_token`.
- Close legacy public endpoints `/api/update/expo/token` in `pandora_tier_validation_apis/controllers/main.py` and `pandora_model_based_notifications/controllers/main.py`: first grep all clients (the app does not call it; confirm Hub does not), then make them return 410 Gone **only when `elrace_notify.close_legacy_token_routes` is True** (otherwise unchanged behaviour). Separate commit.
- `_validate_mobile_request` from `elrace_backend_apis/controllers/base_controller.py` for auth.

**Acceptance:** two devices registered; unregister one → only the other gets deliveries; token reused by another user is removed from the first.

### B5. Inbox v2, config, categories, permission preflight, retention

**Scope:** `elrace_notify/controllers/inbox.py`, cron.

Endpoints per architecture §7: `config`, `list`, `unread_count`, `mark_all_read`, `hide`, `hide_all`, `open`, `categories`, `preferences/update`.

- `list`: own rows only (`expo.notification.users.user_id = uid`), `is_hidden=False`, within retention; `q` = ilike on title/body; `category` on `notification_id.category_code` (legacy rows without code: derive from `json_data` model, else `other`); newest first; returns `id`, `title`, `body`, `category`, `type`, `action`, `model`, `res_id`, `screen`, `params`, `is_read`, `created_at` (ISO UTC).
- `open {model, res_id}`: run `env[model].with_user(uid).browse(id)` → `check_access_rights('read')` + `check_access_rule('read')`; return `{allowed, reason}`. `firestore.*` models → always allowed. Unknown model → `{allowed: false, reason: 'unknown'}`.
- `categories`: active categories with `icon`, `color`, `sequence`, `mandatory`, `local_only`, and this employee's `muted`.
- `preferences/update`: reject mandatory categories.
- Retention cron (daily): delete events/deliveries/inbox rows older than `retention_days`. When `app_inbox_v2` is True, the legacy "keep last 50 per user" cron must not run (guard inside it via a check of the parameter — the cron is `elrace_backend_apis/data/ir_cron_notification_cleanup.xml` → `elrace_backend_apis/models/expo_notification_users.py`).

**Acceptance:** Postman collection for every endpoint; old `/api/notifications` still works unchanged.

### B6. Internal ingest endpoint (Firebase → Odoo)

**Scope:** `elrace_notify/controllers/ingest.py`.

- `POST /api/internal/notify/emit`, header `X-Notify-Token`, constant-time compare with `elrace_notify.ingest_token`; empty parameter → 503 (fail closed).
- Body per architecture §7. Recipients by `odoo_user_ids` only.
- If `takes_over(type)` is False → return `{handled: false}` (the function then uses its legacy send). Otherwise `emit()` and return `{handled: true, result}`.
- Rate limit: max 500 recipients per call.

**Acceptance:** wrong token 403; type not taken over → `handled:false`; taken over → events created.

---

## Phase 4 — Type migration (one wave per branch)

Pattern for every legacy sender (keep legacy code intact in the `else` branch):

```python
D = self.env['elrace.notify.dispatcher'] if 'elrace.notify.dispatcher' in self.env else None
if D and D.takes_over('approval.waiting'):
    D.emit('approval.waiting', record=rec, recipients=users,
           values={'request_type': label, 'reference': rec.name},
           actor=self.env.user, event_key='tier:%s' % tier.id)
else:
    ...  # legacy code, unchanged
```

Only Hub calls that are part of the same legacy block move into the dispatcher (via `hub_category`); make sure Hub still receives exactly one item.

### B7. Wave A — `approval.waiting`

Sources (catalogue §3.1–3.2): `send_employee_request_notification` (≈line 1696), `RequestValidationStatus._post_commit_waiting_push` / `_get_users_needing_waiting_updates` (≈1620 / 1631), refuse wizard next-approver branch (≈1304–1440), `send_tier_review_update` next reviewer (≈2782), `send_petty_cash_creation_notification` (≈2891), `request_validation` / `validate_tier` for `purchase.order` (≈996/1042), `account.move` (≈546/568, **customer invoices only**, OD-1), `hr.expense.sheet` (≈849/748); `elrace_backend_apis/services/approval_service.py` (≈472–483, the duplicate path).

- `request_type` labels: matrix §1.1. HR label from the request's type name; never "New Request Submitted".
- `event_key`: tier review / validation line id → the web path and the app path collapse into one event.
- Waiting counters / Pusher updates stay as they are.

**Acceptance (staging):** submit HR leave, LPO, petty cash, customer invoice → approver gets exactly one push per step with the matrix text; tap opens the record; Hub pending unchanged; approving from the app does not double-notify.

### B8. Wave A — HR final result, Wave B — new employee

- `hr.request.approved`: only when no next validator remains. `hr.request.rejected`: on reject (app `send_employee_request_status_update` ≈2933 and web refuse wizard). Remove the next-approver notification on rejection (inside the takeover branch).
- `hr.employee.assigned`: `DraftHrEmployee.action_confirm` (≈line 17); recipient `parent_id.user_id`; `record` = the created `hr.employee`.

### B9. Wave B — LPO issued, petty cash paid, vendor bills, BioTime

- `purchase.lpo.issued` at PO final tier (≈1105–1125). Recipient per OD-3 helper `_lpo_project_manager(po)`.
- `expense.petty_cash.paid` in `approve_expense_sheets` (≈871): loop **per sheet**, recipient `sheet.employee_id.user_id`, `request_number = sheet.name` (fixes the wrong-number bug).
- `account.vendor_invoice` (channel none): in invoice senders, when `move_type in ('in_invoice','in_refund')` and `takes_over('account.vendor_invoice')` → send nothing to mobile; Hub path unchanged.
- `attendance.biotime_sync` (none): `cubes_biotime/models/attendance_sync.py` (≈1074) and `biotime_config.py` push calls → skip when `takes_over`.
- Retire AP-2, AP-4 (invoice/petty), AP-5 requester messages inside takeover branches (OD-2).

### B10. Wave C — Projects

- `project.manager.assigned`: `project.project` `create` / `write` when `user_id` changes (≈66 / 209 in `elrace_notification.py`).
- `project.member.added`: `elrace_project_new_theme/models/staff_list.py` (≈137, 163, 200). Takeover branch also stops PR-1 creation fan-out and the hard-coded user 874.
- PR-2 (project completed) untouched.

### B11. Wave C — Document expiry

`emp_mobile_conf/models/document_expiry_notify.py` `_cron_send_document_expiry_soon_notifications`: when taken over, emit per document only if `(expiry_date - today).days in (30, 7, 1)`; `event_key = "{doc.id}:{expiry_date}:{days}"`; `values = {document_type, expiry_date}` (date formatted `DD Mon YYYY`); recipient = owner employee's user. No grouped "You have n documents" message.

### B12. Wave C — Circulars

- In `elrace_dashboard` `OdxAnnouncementMobileNotify` (≈3042–3190): add `x_notify_mandatory` (Boolean) + form view field; when taken over, `emit('circular.published', record=ann, recipients=<existing _mobile_news_recipient_users() minus labour>, values={'circular_title': ann.name}, screen='circulars', params={'id': ann.id, 'tab': ...}, mandatory=ann.x_notify_mandatory)` and **do not** create the Firestore `odoo_push_jobs` document.
- Volume: deliveries are batched by the outbox cron (≤ 500 per FCM batch).

### B13. IT Request waiting (OD-9)

Find the pending-approver moment on `it.hardware.request.approval` (`elrace_it_hardware_request/models/it_hardware_request.py` — class ≈1682; `action_submit` ≈660, `action_approve` ≈673). If there is a clean hook (approval line becomes current), emit `approval.waiting` with `model='it.hardware.request'`. Otherwise report back; keep the type inactive.

---

## Phase 5 — Cleanup

### B14. Retire legacy paths (after ≥ 3 weeks stable per type)

- Delete the `else` legacy branches for taken-over types; remove `_is_push_only_approval_model` special cases that no longer apply.
- Replace remaining `user.expo_token` single-token sends with `_push_tokens_for_user` or the dispatcher.
- Drop the `operating.unit(6)` credential fallback once parameters are set.
- Separate PR per module, each with the usual diff review.

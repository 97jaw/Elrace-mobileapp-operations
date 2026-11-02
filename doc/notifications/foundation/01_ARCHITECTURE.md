# 01 — Architecture: Notifications Foundation v2

## 1. Current state (summary)

Full detail with file/line references: `../NOTIFICATIONS_CATALOGUE_AND_TRIGGERS.md`.

| Concern | Today |
|---|---|
| Senders | ~35 Odoo triggers inside business methods (`elrace_dashboard/models/elrace_notification.py` and ~15 other modules, 33 `_send_fcm_push` call sites); 6 Cloud Functions; 7 local schedules in the app |
| Tokens | `res.users.expo_token` (one per user, used by most senders — 81 references), `mobile.device.fcm_token` (multi-device, used by 6 call sites), Firestore `users/{uid}/fcm_tokens` (Firebase senders). Logout does not clear tokens |
| Inbox | `expo.notifications` / `expo.notification.users` (mobile API), `elrace.notification` (web bell), app SharedPreferences cache merged by content match (source of duplicates). Firebase-originated items never reach the server inbox |
| Payload | No contract. App guesses category from `category` → `type` → `model`; attendance detected by keywords in title/body |
| Tap | Hard-coded `if/else` in `lib/firebase_service.dart` `_handleNotificationTap`: chat, task/ticket, circular, labour transfer. Everything else does nothing. Notification Center row tap does nothing |
| Text/channel rules | Inline strings and hard-coded sets (`_is_push_only_approval_model`); client-side text patches (`_withLpoIssuedRemap`) |
| Config | FCM credentials read from `operating.unit` record `browse(6)`; app base URL hard-coded |

## 2. Target design

```
 Odoo business event            Firebase event (task, ticket, note, signature)
 (tier step, paid, publish…)    Cloud Function ──POST /api/internal/notify/emit──┐
          │                                                                       │
          └──────────► elrace.notify.dispatcher.emit(type_code, …) ◄──────────────┘
                         1. master flag + type active?
                         2. recipients: drop inactive, labour, actor, muted (unless mandatory)
                         3. dedupe (type + record + recipient + event_key)
                         4. render title/body from type templates
                         5. elrace.notify.event row (audit, always)
                         6. channel inbox/both → inbox row (expo.notification.users)
                         7. channel push/both  → delivery rows, one per ACTIVE device token
                         8. type has hub_category → Hub pending adapter (existing)
                         9. postcommit: send; cron retries failures
                                         │
                   FCM payload contract v1 (§5) to every active device
                                         │
            Flutter: parse → foreground/background rules → generic router (§6)
            Notification Center: server inbox v2 (90 days, search, filter, hide)
```

Chat stays entirely in Firebase (push only, high volume). Prayer stays local on the phone.

## 3. Decisions

| # | Decision | Reason |
|---|---|---|
| D1 | New Odoo module **`elrace_notify`**, depends on `base`, `hr`, `emp_mobile_conf`, `pandora_expo_notifications`, `elrace_backend_apis` (reuses `BaseController._validate_mobile_request`). Existing modules call it with a soft check (`'elrace.notify.dispatcher' in self.env`), **no new hard dependency** on `elrace_dashboard` etc. | No uninstall cascade; legacy keeps working if module absent |
| D2 | Reuse and extend `expo.notifications` / `expo.notification.users` as the inbox | Old app versions keep reading their inbox through legacy `/api/notifications` |
| D3 | **Recipients are computed in code** at the trigger (business logic). The dispatcher only applies generic filters. No rule engine | Recipient logic is domain-specific; a rule engine is over-engineering |
| D4 | Templates use `{placeholder}` with a safe formatter: missing key → empty string. Never render `None`/`False` | Fixes catalogue issue #12 |
| D5 | Delivery through an outbox model + postcommit send + retry cron | Business transaction never waits on FCM; failures are visible and retried |
| D6 | **`mobile.device` is the single device registry** for Odoo pushes. `res.users.expo_token` is kept in sync only for legacy senders until they are retired | Multi-device + logout |
| D7 | Firebase functions (except chat) stop sending FCM themselves and call the Odoo ingest endpoint | One inbox, one token registry, one set of rules |
| D8 | Prayer remains a local notification on the device | No server value; location-based |
| D9 | Hub pending notifications are preserved: the dispatcher calls the existing `_push_hub_pending_notification` for types with `hub_category` | Do not break Hub |
| D10 | **Per-type takeover**: `takeover=True` makes the legacy sender for that type skip. Turning it off restores legacy behaviour | Reversible, module by module |
| D11 | Mute is server-authoritative (`mobile.notification.preference`). `mandatory` types ignore mute | Manager: mandatory circulars cannot be muted |
| D12 | Web bell (`elrace.notification`), Pusher counters, helpdesk web activities: **out of scope, unchanged** | Mobile-only change |
| D13 | The app reads `GET /api/v2/notifications/config` at start/resume; behaviour switches by server flags, not app releases | One app release for the whole programme |
| D14 | Record references are stored as `model` (Char) + `res_ref` (Char) so Firestore ids (strings) and Odoo ids share one schema | Tasks, tickets, notes and signatures live in Firestore |
| D15 | `emit()` **never raises** into the caller; it logs and returns a result | A notification bug must never block an approval |

## 4. Data model (`elrace_notify`)

### 4.1 `elrace.notify.type` (configuration, seeded with `noupdate="1"`)

| Field | Type | Notes |
|---|---|---|
| `code` | Char, unique, required | e.g. `approval.waiting` |
| `name` | Char | Admin label |
| `active` | Boolean, default False | Seeded inactive |
| `takeover` | Boolean, default False | Legacy sender for this type skips when True **and** `active` **and** master flag on |
| `category_id` | M2o `mobile.notification.category` | Mute + icon/color |
| `channel` | Selection `push` / `inbox` / `both` / `none` | Manager's OUTSIDE / INSIDE / NONE |
| `title_template`, `body_template` | Char / Text | `{placeholder}` |
| `action` | Selection `open_record` / `open_screen` / `open_chat` / `none` | |
| `screen` | Char | For `open_screen` (e.g. `circulars`, `approvals`) |
| `exclude_labour` | Boolean, default True | `hr.employee.is_labor` |
| `exclude_actor` | Boolean, default True | |
| `mandatory` | Boolean, default False | Ignores mute |
| `dedupe_minutes` | Integer, default 1440 | 0 = no dedupe |
| `hub_category` | Char | When set, Hub pending adapter fires (`hr`, `rfq`, `petty_cash_pending`, …) |
| `android_channel` | Char, default `high_importance_channel` | |
| `note` | Text | Link to matrix row |

### 4.2 Extensions

- **`mobile.notification.category`**: add `icon` (Char, Material icon name), `color` (Char hex), `sequence`, `mandatory` (Boolean), `local_only` (Boolean — prayer, chat). Seed codes listed in `02_TRIGGER_MATRIX.md` §3 (today the table has **no seed data**). New category rows are created with `active=False` — the live mute screen reads active categories, so seeding must not show anything to current users. They are activated with the wave that uses them.
- **`expo.notifications`**: add `type_code`, `category_code`, `model`, `res_ref`, `action`, `screen`, `params_json`, `event_id` (M2o event), `payload_version`.
- **`expo.notification.users`**: add `is_hidden` (Boolean), `read_at` (Datetime); index on `(user_id, create_date)`.
- **`mobile.device`**: add `platform`, `app_version`, `token_updated_at`, `logged_out_at`. A device with empty `fcm_token` or `logged_out_at` set receives nothing.

### 4.3 New models

- **`elrace.notify.event`** — one row per (emit × recipient): `type_id`, `user_id`, `model`, `res_ref`, `event_key`, `dedupe_key` (indexed), `title`, `body`, `channel`, `state` (`skipped_flag`, `skipped_labour`, `skipped_actor`, `skipped_muted`, `skipped_duplicate`, `queued`, `delivered`, `failed`), `inbox_user_id`, `create_date`. Audit + dedupe + debugging ("why did X not get it?").
- **`elrace.notify.delivery`** — one row per device token: `event_id`, `device_id`, `token` (not logged in full), `state` (`queued`, `sent`, `failed`, `invalid_token`), `attempts`, `next_try_at`, `last_error`.

Retention cron: delete events, deliveries and inbox rows older than `elrace_notify.retention_days` (default 90). The legacy "keep last 50 per user" cron must be disabled when `elrace_notify.app_inbox_v2` is on.

## 5. Payload contract v1 (FCM)

FCM `data` values are strings. Keys:

| Key | Example | Notes |
|---|---|---|
| `nv` | `"1"` | Contract version |
| `nid` | `"84211"` | `elrace.notify.event` id |
| `inbox_id` | `"55120"` or `""` | `expo.notification.users` id when channel is `both` |
| `type` | `"approval.waiting"` | Type code |
| `category` | `"waiting"` | Mute/visual category code |
| `action` | `"open_record"` | `open_record` / `open_screen` / `open_chat` / `none` |
| `model` | `"purchase.order"` | Also `firestore.todo`, `firestore.ticket`, `firestore.note`, `firestore.signature` |
| `res_id` | `"1234"` / Firestore doc id | String |
| `screen` | `"circulars"` | For `open_screen` |
| `params` | `"{\"tab\":\"circular\"}"` | JSON string |
| `record_id` | same as `res_id` | **Legacy compat** — keep until old app versions are gone |

`notification` block: `title`, `body` (OS displays it when the app is in background).
Android: `channel_id` from the type; `tag` = `nid` (OS replaces instead of stacking duplicates).
iOS: `thread-id` = category.

**Inbox-only types send no FCM.** Optional: when `elrace_notify.inbox_silent_sync` is on, a data-only push `{nv, type:"inbox.sync"}` lets the app refresh the badge.

## 6. Flutter routing contract

- One `NotificationRouter` with a **registry** `Map<String model, RouteBuilder>` and `Map<String screen, RouteBuilder>`.
- Unknown `model`/`screen` → open Notification Center (never crash, never "nothing").
- Before opening an **Odoo** record: `POST /api/v2/notifications/open` → `{allowed, reason}`. Not allowed → snackbar "You no longer have access to this item." Firestore items rely on Firestore rules.
- Taps arriving before home is ready are queued and flushed when home is ready, **including after login from the sign-in screen** (catalogue issue #1).
- The same router is used for OS taps and Notification Center row taps.

Registry targets (existing screens are listed in `tasks/MOBILE.md` M2):

| `model` / `screen` | Screen |
|---|---|
| `employee.requests` | `HrRequestDetailScreen(requestId)` |
| `purchase.order` | RFQ/LPO details (`RfqDetailsScreen`) |
| `hr.expense.sheet` | `PettyCashDetailsScreen(requestId)` |
| `account.move` | `InvoiceDetailsScreen(requestId)` |
| `it.hardware.request` | IT request detail (new loader if missing) |
| `project.project` | Project detail by id (new loader) |
| `hr.employee` | Employee detail by id (new loader) |
| `hr.employee.document` | `DocumentDetailsScreen` via by-id loader |
| `firestore.todo` | `TaskDetailsScreen` |
| `firestore.ticket` | `TicketDetailsScreen(ticketId)` |
| `firestore.note` | `NoteDetailScreen` via by-id loader |
| `firestore.signature` | `SignatureDocumentViewerScreen` via by-id loader |
| `odx.announcement` / screen `circulars` | Circulars & Announcements on the item |
| action `open_chat` | Chat screen (existing handler) |

## 7. APIs

All new endpoints: `type='json'`, mobile JWT auth (same validator as existing mobile APIs), under `/api/v2/notifications/`. `/api` is already in the guard's `MACHINE_PREFIXES`; endpoints authenticate themselves.

| Endpoint | Purpose |
|---|---|
| `config` | Flags for the app: `enabled`, `app_inbox_v2`, `server_task_notifications`, `prayer_text_v2`, `retention_days` |
| `list` | `limit, offset, q, category, unread_only, date_from, date_to`; within retention; excludes `is_hidden` |
| `unread_count` | Badge |
| `mark_all_read` | Called when the Notification Center opens |
| `hide` / `hide_all` | Clear one / Clear All → `is_hidden=True` (original records untouched) |
| `open` | Permission preflight (`check_access_rights('read')` + `check_access_rule('read')` as the user) |
| `categories` | Categories with `icon`, `color`, `mandatory`, `local_only`, `muted` |
| `preferences/update` | Mute/unmute; rejects mandatory |
| `device/register` | `device_id, fcm_token, platform, app_version`; moves a token away from any other user |
| `device/unregister` | Logout: clears this device's token |

Internal (Firebase → Odoo): `POST /api/internal/notify/emit`, header `X-Notify-Token` compared in constant time with System Parameter `elrace_notify.ingest_token`. Body: `{type, recipients:{odoo_user_ids:[…]}, actor_odoo_user_id, model, res_id, screen, params, values, event_key}`.

## 8. Flags and System Parameters

| Parameter | Default | Effect |
|---|---|---|
| `elrace_notify.enabled` | `False` | Master switch for the dispatcher. Off → `emit()` returns `skipped_flag`, legacy senders run |
| `elrace_notify.app_inbox_v2` | `False` | App uses v2 inbox APIs and stops the local SharedPreferences merge |
| `elrace_notify.server_task_notifications` | `False` | App stops local task/ticket notifications; Firebase emits through Odoo |
| `elrace_notify.inbox_silent_sync` | `False` | Data-only badge sync for inbox-only items |
| `elrace_notify.device_lifecycle` | `False` | Logout / remote logout clears the device token; token moved away from a previous user |
| `elrace_notify.close_legacy_token_routes` | `False` | Public `/api/update/expo/token` routes return 410 |
| `elrace_notify.prayer_text_v2` | `False` | App uses the manager's prayer wording |
| `elrace_notify.retention_days` | `90` | |
| `elrace_notify.ingest_token` | (secret) | Firebase → Odoo |
| `elrace_notify.fcm_project_id`, `elrace_notify.fcm_service_account_json` | (secret) | Fallback to `operating.unit(6)` fields until set |

Per type: `active`, `takeover`.

## 9. Security items folded into the foundation

1. Close the public legacy token endpoints `/api/update/expo/token` (`pandora_tier_validation_apis/controllers/main.py`, `pandora_model_based_notifications/controllers/main.py`) — any caller can redirect a user's pushes (catalogue issue #6).
2. Logout clears the device token (catalogue issue #4).
3. A token registered for user B is removed from user A (shared phones).
4. FCM credentials move to System Parameters.
5. Never log full tokens or payload secrets.

## 10. Out of scope

Web bell (`elrace.notification`), Pusher counters (hard-coded keys — separate backlog item), Hub internals, chat delivery mechanics, timesheet notifications (not specified), face-enrolment / widget-update / admin broadcast / shared-folder / labour-transfer / project-completed (left on legacy, see matrix §4).

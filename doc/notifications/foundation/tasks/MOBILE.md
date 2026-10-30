# Mobile tasks — Flutter (`Elrace-mobileapp-operations`)

Read first: `../01_ARCHITECTURE.md` (§5 payload, §6 router, §7 APIs, §8 flags) and `../02_TRIGGER_MATRIX.md`.
All of M1–M7 ship in **one store release**. Server flags (`GET /api/v2/notifications/config`) decide
which new behaviour is active, so later changes need no release.
Keep the legacy path working when flags are off. Do not touch the Mobile APIs JWT login flow.

Key existing files:
`lib/firebase_service.dart` (FCM handlers, `_handleNotificationTap`), `lib/main.dart` (background handler),
`lib/core/services/notification_storage_service.dart`, `lib/core/services/notification_api_service.dart`,
`lib/ui/presentation/Notification/*`, `lib/chat/services/chat_notification_service.dart`,
`lib/data/services/task_notification_service.dart`, `lib/data/services/assignment_push_service.dart`,
`lib/data/services/prayer_notification_service.dart`.

---

### M1. Payload model + generic router + home-ready fix

**Scope:** new folder `lib/core/notifications/` (`notification_payload.dart`, `notification_router.dart`, `route_registry.dart`, `notification_config_service.dart`); rewire `firebase_service.dart`.

- `NotificationPayload.fromData(Map)`: reads contract v1 (`nv`, `nid`, `inbox_id`, `type`, `category`, `action`, `model`, `res_id`, `screen`, `params`). **Legacy fallback** when `nv` is missing: `category` → `type` → `model`; `record_id`/`request_id`/`expense_sheet_id` → `res_id`; `click_action == OPEN_RECORD` → `open_record`; `chat_id` → `open_chat`; circular/announcement and labour-transfer keys as today.
- `NotificationRouter.open(payload)`: `open_record` → registry by `model`; `open_screen` → registry by `screen`; `open_chat` → existing chat handler; unknown → Notification Center. For Odoo models, call `POST /api/v2/notifications/open` first when `config.enabled`; denied → snackbar "You no longer have access to this item."
- Replace the `if/else` in `_handleNotificationTap` with the router; keep the prayer/azan early return.
- Pending-tap queue flushed when home is ready. **Call `FirebaseService.markHomeReady()` after login from `lib/ui/presentation/signin/sign_in_screen.dart`** (≈line 114) and after UAE Pass login, not only from the splash (catalogue issue #1).
- `NotificationConfigService`: fetch `config` at start and on resume; cache in memory + SharedPreferences; default all flags false on error.
- Move the hard-coded `https://erp.elrace.com/api` in `notification_api_service.dart` to `UrlUtil`.

**Acceptance:** legacy payloads (`model` + `record_id`) already open HR requests / LPO / petty cash; tap works after sign-in without restart; unknown payload opens the Notification Center.

### M2. Route targets (registry entries + by-id loaders)

Registry entries (architecture §6). Existing screens that already take an id:
`HrRequestDetailScreen(requestId, managerContext)`, `PettyCashDetailsScreen(requestId, type)`,
`InvoiceDetailsScreen(requestId, type)`, `RfqDetailsScreen` (`lib/ui/presentation/Email Approval/screens/`),
`TicketDetailsScreen(ticketId)`, Firebase `TaskDetailsScreen` (use the one the current tap handler opens — two classes share this name: `lib/ui/presentation/tasks/task_details_screen.dart` and `lib/ui/presentation/tasks_dashboard/screens/task_details.dart`), circulars screen (existing circular tap handler).

Build thin **by-id loader** screens (load, spinner, error state, then show the existing screen) for screens that take an object today:
- `hr.employee.document` → `DocumentDetailsScreen(document)`
- `firestore.note` → `NoteDetailScreen(note)`
- `firestore.signature` → `SignatureDocumentViewerScreen(pdfUrl, title)`
- `project.project` → project detail (pick the existing project screen; add a loader)
- `hr.employee` → employee detail (new minimal screen or existing profile screen if one supports another employee)
- `it.hardware.request` → IT request detail (if a screen exists; else registry falls back to Notification Center)

If a backend "get by id" API is missing for any of these, list it in the PR description for the backend agent; do not add Odoo code.

**Acceptance:** each target opens from a cold start (app killed) via a test push.

### M3. Device registration and logout

- After login, on resume, and on `onTokenRefresh`: `POST /api/v2/notifications/device/register {device_id, fcm_token, platform, app_version}` (reuse the device id the login already sends). Keep the existing `/api/save_expo_token` call for older backends.
- On every logout path (normal logout, forced logout `lib/core/session/force_logout_guard.dart`, UAE Pass logout `lib/auth/uaepass_auth_cubit.dart`): call `device/unregister` **before** the session is revoked, then the existing `linked-devices/logout-current`. Keep chat `signOut()` removing the Firestore token.
- On logout also cancel local task notifications for that user.

**Acceptance:** two phones receive; after logout on one, it receives nothing.

### M4. Notification Center v2 (behind `config.app_inbox_v2`)

`lib/ui/presentation/Notification/notification_screen.dart` + a new `NotificationInboxRepository` (v2 APIs).

- On open: load page 1 (`limit 50`) from `list`, then `mark_all_read`, then reset the badge (fix the baseline order — catalogue issue #16).
- Infinite scroll (offset), search box (`q`, debounced 400 ms), category chips from `categories`, date range filter, 90-day window.
- Row tap → `NotificationRouter.open` (same as OS tap).
- Swipe → `hide`; "Clear All" → `hide_all` (wording unchanged).
- Circulars/announcements are shown (remove the hide filter).
- Badge: `unread_count` on app start, resume, push receipt, `inbox.sync` data push; poll every 60 s only while the home header is visible (replace the 5 s poll in `home_glass_app_bar.dart`).
- When v2 is on, stop the local SharedPreferences merge and `_sameContent` matching in `notification_storage_service.dart` (source of duplicates) and the `_withLpoIssuedRemap` patch. When off, current code path unchanged.

**Acceptance:** list matches server; search/filter work; Clear All hides; no duplicates after receiving the same push in background and tapping it.

### M5. Categories and mute

- `notification_mute_settings_screen.dart`: read `categories` (icon, color, sequence, mandatory, local_only, muted). Mandatory → toggle disabled with "Required" label. Local-only (`chat`, `prayer`) keep current local handling.
- `notification_category_theme.dart`: icon/color from API with the current map as fallback.
- Remove the divergent second mute popup in `home_screen/widgets/profile_box_with_slide_animation.dart` (≈170) or make it open the same screen.

### M6. Push handling per channel

- Foreground (`onMessage`): show a local banner for any push with a `notification` block (respect mute, skip active chat as today). Do **not** write pushes into a local inbox when `app_inbox_v2` is on — the server inbox is the source.
- `type == inbox.sync` → refresh badge only, no banner.
- Chat: never stored in the Notification Center (manager: outside only).
- Background handler in `lib/main.dart`: same rule (no local inbox writes under v2).
- When `config.server_task_notifications` is true: stop scheduling local task/ticket notifications (`task_notification_service.dart`, `assignment_push_service.dart`, `add_task.dart`, `task_details.dart`, `tasks_provider.dart`) and cancel already scheduled ones once.
- Remove attendance detection by keywords in title/body; refresh attendance only on the explicit `refresh_attendance` flag.

### M7. Prayer text and platform hygiene

- Prayer: title `Prayer Time`, body `It is time for {prayer}.` (both sound and silent channels) **only when `config.prayer_text_v2` is true**; otherwise today's wording.
- Android: create channel `task_notifications` or align Cloud Functions to `task_notifications_channel` (coordinate with F2); set a monochrome small icon + colour in the manifest.
- iOS `AppDelegate.swift`: `willPresent` must not force banners that Dart also shows (double banner / mute bypass); call `super` in `didReceive` / `didReceiveRemoteNotification`. Test on a device.

---

### M8. Cleanup (phase 5, later release)

Remove the legacy inbox merge code, legacy payload fallbacks no longer sent by any backend path, and local task notification code.

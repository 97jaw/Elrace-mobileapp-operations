---
title: "Elrace Mobile App — Notifications Catalogue and Trigger Points"
subtitle: "Module-wise inventory, backend triggers, app display and tap behaviour, and issues"
date: "15 October 2026"
---

**Scope.** Every notification the Elrace mobile app can show, from three sources:

- **Odoo backend** (`odoo14-clients`, branch `elrace-addons`): FCM pushes and the notification inbox.
- **Firebase Cloud Functions** (`functions/`, `functions-assignment/` in the mobile repo): chat, notes, signed documents, tasks and tickets, and announcement fan-out.
- **The app itself** (`Elrace-mobileapp-operations`, Flutter): locally scheduled notifications (prayer, tasks, check-in reminders).

Line numbers refer to the code as of 15 October 2026.

# 1. Summary

| Item | Count / finding |
|---|---|
| Live push triggers in Odoo | About 35, across 11 business areas |
| Cloud Function push types | 6 (chat, document signed, note shared, task, ticket, announcement/circular) |
| Local notifications scheduled by the app | 7 active types (prayer x2, task x5); check-in/out reminders are disabled |
| Push types that open a screen when tapped | **3 only**: chat, task/ticket, circular/announcement |
| Push types that do nothing when tapped | All Odoo approval, HR request, project, attendance, document expiry, share, widget, admin and note pushes |
| Notification Center row tap | **Does nothing** |
| Confirmed duplicate | Approving an LPO, invoice or petty cash from the app sends two pushes to the requester and two to the next reviewer |
| Confirmed tap bug | After logging in from the sign-in screen, all notification taps are ignored until the app is restarted |

The four highest-impact problems are in section 9.1.

# 2. How a notification reaches the phone

## 2.1 Odoo push path (most notifications)

1. A business event runs in Odoo (for example, a leave request is submitted, or an LPO tier is approved).
2. The code calls `elrace.notification._send_fcm_push(token, title, body, data)` (`elrace_dashboard/models/elrace_notification.py:2603`).
3. That method:
   - finds the user for the token;
   - checks the user's mute settings (`mobile.notification.preference`); if the category is muted, **nothing is sent and nothing is stored**;
   - stores an inbox row (`expo.notifications` + `expo.notification.users`) unless the record is one of the four "push-only" approval models (`employee.requests`, `purchase.order`, `account.move`, `hr.expense.sheet`);
   - sends one FCM HTTP v1 message to the user's `res.users.expo_token`.
4. FCM credentials are read from `operating.unit` record **id 6** (hard-coded).

**The data sent to the phone is always only these keys:** `record_id`, `model`, `status`, `category`, `click_action` (`OPEN_RECORD`), and `notification_id` / `notification_user_id` when an inbox row was stored. Any other key (for example `type`, `request_id`, `vendor_name`) is dropped from the push. A missing key arrives as the literal text `"None"`.

## 2.2 Pending-reviewer path (approvals)

When someone must approve something, `_notify_pending_reviewer` (`elrace_notification.py:2290`) sends three things:

- the FCM push above;
- an inbox row, **always** (it ignores the push-only rule and the mute setting);
- a push to the Elrace Hub web app (`POST {hub}/api/hub/notifications/push`).

## 2.3 Cloud Function path

| Function | File | Fires on |
|---|---|---|
| `onNewChatMessage` | `functions/index.js:58` | New Firestore chat message |
| Note shared | `functions/notes_share_notify.js:62` | A note is shared with a user |
| Document signed | `functions/sign_document_sync.js:136` | A document sent for signing is signed |
| `onAssignedTodoCreated`, `onTodoCompleted`, `onAssignmentPushRequest` | `functions-assignment/index.js:130, 169, 224` | Task/ticket created, completed, or queued by the app |
| `onOdooAnnouncementPushJob` | `functions/odoo_announcement_push.js:101` | Odoo writes a job to Firestore `odoo_push_jobs` when a circular/announcement is published |

These use Firestore tokens (`users/{uid}/fcm_tokens`), not the Odoo token. The announcement function fetches tokens from Odoo (`POST /api/internal/staff_fcm_tokens`).

## 2.4 What the app does with a push

| App state | Handler | Behaviour |
|---|---|---|
| Open (foreground) | `FirebaseService` `onMessage` (`lib/firebase_service.dart:163`) | Works out the category (`category`, then `type`, then `model`). Checks mute. Chat is not bannered here. Everything else is shown as a local notification on channel `high_importance_channel`. Saved to the local inbox. Badge refreshed. |
| Background / killed | `_firebaseMessagingBackgroundHandler` (`lib/main.dart:100`) | The phone's system tray shows the push. The handler saves it to the local inbox. |
| Tapped | `_handleNotificationTap` (`lib/firebase_service.dart:778`) | Routes on `category` or `type`: prayer, chat, task/ticket, circular/announcement. **Anything else is "view only" and nothing opens.** |

# 3. Notification catalogue by module

Column guide:

- **Trigger** — the exact event in code.
- **To** — who receives it.
- **Inbox** — whether it appears in the Notification Center list (server inbox).
- **Tap** — what opens when the user taps it.

## 3.1 HR — Employee requests (leave, sick, short leave, job mission, effective date, temporary permission)

| # | Notification (title / body) | Trigger | To | Inbox | Tap |
|---|---|---|---|---|---|
| HR-1 | "Short Leave Request", "Sick Leave Request", "Job Mission Request", "Effective Date Update Request", "Temporary Permission", "Leave Request" — "{employee} has submitted …". **Annual leave falls back to** "New Request Submitted" / "{employee} submitted a new request." | Request submitted from the app: `/api/submit_request` and `/api/hr/submit_request` → `send_employee_request_notification` (`elrace_notification.py:1695`; text at 1873-1906) | Next pending approver(s) | Yes | Nothing |
| HR-2 | "Request Approved" / "{approver} has approved your request." — or "Request Rejected" / "… has rejected your request." | Approver acts in the app: `/api/approve_reject_hr_request` → `send_employee_request_status_update` (`elrace_notification.py:2933`) | Requester | No (push only) | Nothing |
| HR-3 | "New Request to Approve" / "A new request from {employee} needs your approval." | Same call as HR-2, next approval line (`elrace_notification.py:2979`). **Also sent after a rejection** (likely bug). | Next approver | Yes | Nothing |
| HR-4 | "New Employee Request Approval" / "{request} requires your approval." — or, if no next approver, "Employee Request Processed" / "{request} has been fully processed." (**also sent on rejection**) | Refusal in the Odoo web wizard (`request.refuse.reason`, `elrace_notification.py:1304-1440`) | Next approver, or creator | No | Nothing |
| HR-5 | "New Employee Request" / "{request} requires your approval." | `employee.requests.create` (`elrace_notification.py:1270`). **Probably never fires**: approvers are added after create. | First approver | — | — |
| HR-6 | "New Employee Registered: {name}" / "Employee {name} has been confirmed and added to the system" | Draft employee confirmed (`draft.hr.employee.action_confirm`, `elrace_notification.py:17`) | Direct manager | Yes | Nothing |

## 3.2 Approvals — LPO (`purchase.order`), Invoice (`account.move`), Petty cash (`hr.expense.sheet`)

| # | Notification | Trigger | To | Inbox | Tap |
|---|---|---|---|---|---|
| AP-1 | "New LPO Approval Request" / "New Invoice Approval Request" / "New Petty Cash Approval Request" — "{name} requires your approval." | Record sent for approval: `request_validation()` (PO `elrace_notification.py:996`, invoice 546, petty cash 849) | First reviewer | Yes | Nothing |
| AP-2 | "LPO Approved" / "INVOICE Approved" / "Petty Cash Approved" — "{approver} approved {name}" | Any tier approved, web or app: `validate_tier()` (PO 1042, invoice 568, petty cash 748) | Creator | No | Nothing |
| AP-3 | "New LPO Approval Required" / "New INVOICE Approval Required" / "New Petty Cash Approval Required" — "Please review {name}" | Same, when more tiers remain | Next reviewer | Yes | Nothing |
| AP-4 | PO: "LPI has been issued" / "{vendor}" (the app rewrites it to "LPO has been issued"). Invoice / petty cash: "… Fully Approved" / "{name} has been fully approved." | Same, final tier | All reviewers | No | Nothing |
| AP-5 | "{Purchase Order / Journal Entry / Expense Report} Approved" or "… Rejected" — "{approver} approved/rejected {name}." Then "New Approval Required" to the next reviewer, or "… Fully Approved" to the requester. | Approve/reject **from the app**: `/api/record/tier_review` → `send_tier_review_update` (`elrace_notification.py:2781`) | Requester; next reviewer | Next reviewer only | Nothing |
| AP-6 | "Petty Cash Request Submitted" / "{employee} submitted a petty cash request of {amount} AED." | Petty cash submitted from the app: `/api/submit_expense` (`petty_cash_controller.py:494` → `elrace_notification.py:2890`) | Current reviewer | Yes | Nothing |
| AP-7 | "Petty Cash Paid" / "{sheet} has been paid." | Sheet paid (`approve_expense_sheets`, `elrace_notification.py:871`). With several sheets, every push names the **last** sheet (bug). | Reviewers | No | Nothing |

**Duplicate (confirmed):** `ApprovalService.tier_review` (`elrace_backend_apis/services/approval_service.py:472-483`) calls `validate_tier()`, which already sends AP-2/AP-3/AP-4, then calls `send_tier_review_update`, which sends AP-5. The requester receives "LPO Approved" **and** "Purchase Order Approved". The next reviewer receives "New LPO Approval Required" **and** "New Approval Required".

**Possible duplicate (verify):** if submitting petty cash from the app also runs `request_validation()`, the reviewer gets both AP-6 and AP-1.

## 3.3 Projects

| # | Notification | Trigger | To | Inbox | Tap |
|---|---|---|---|---|---|
| PR-1 | "New Project Assigned" / "You have been added to {project}" | Project created (`project.project.create`, `elrace_notification.py:66`) | Everyone on the staff list, plus **hard-coded user id 874** | Yes | Nothing |
| PR-2 | "Project Completed" / "Project {name} is now completed" | Project status changes to Completed (`elrace_notification.py:209`) | Same as PR-1 | Yes | Nothing |
| PR-3 | "New Project Assigned" / "You have been added to {project}" | Employee added to a project staff list (`elrace_project_new_theme/models/staff_list.py:137, 163, 200`) | That employee | Yes | Nothing |

These three send to **all** the user's devices (Odoo token plus every active `mobile.device` token). Most other senders reach only the last-registered device.

## 3.4 Documents and shared folders

| # | Notification | Trigger | To | Inbox | Tap |
|---|---|---|---|---|---|
| DOC-1 | "Document expiring soon" / "{document} expires on {date}. Please renew it." (several: "You have {n} documents expiring soon …") | **Daily cron** "Mobile: Document Expiry Soon Notifications" (`emp_mobile_conf/models/document_expiry_notify.py:18`). Documents expiring within 30 days. **Repeats every day** until expiry. | The employee | Yes | Nothing |
| DOC-2 | "Shared Folder Update" / "New user has been added to the shared folder '{name}'." — or "A user has been removed …" | `/api/cloud/folder/add_user`, `/remove_user` (`elrace_backend_apis/controllers/cloud_controller.py:308, 355`) | All folder members, including the actor | Yes | Nothing |
| DOC-3 | "Document signed" | A document sent for signing is signed (Cloud Function `sign_document_sync.js:136`) | Sender | Yes | Opens a chat called "Document signed" (wrong). **Not shown at all while the app is open** (it carries `chat_id`, so it is treated as chat). |
| DOC-4 | Note shared | A note is shared (`functions/notes_share_notify.js:62`) | Recipient | Yes | Nothing (no notes route) |

Project document expiry (`om_project_document`) is **email only** and does not reach the app.

## 3.5 Announcements and circulars

| # | Notification | Trigger | To | Inbox | Tap |
|---|---|---|---|---|---|
| ANN-1 | "Circular published" / "Announcement published" — body is the description or text (180 characters) | Announcement made active in Odoo (`odx.announcement.write`, `elrace_notification.py:3182`) → Firestore job → Cloud Function `odoo_announcement_push.js` | All active users (general), or the selected users | Stored locally, but **hidden** from the Notification Center (still counted in the bell badge) | Opens Circulars & Announcements on the right tab and record |

## 3.6 Attendance, face enrolment and timesheet

| # | Notification | Trigger | To | Inbox | Tap |
|---|---|---|---|---|---|
| ATT-1 | "Attendance Updated" / "Your attendance has been synced from BioTime. Please update the Project location." | New attendance from a **manual** BioTime pull (`cubes_biotime/models/attendance_sync.py:1074`). The automatic Lambda crons do **not** push; the live-pull cron is inactive. | The employee | Yes | Nothing (refreshes today's attendance status) |
| FACE-1 | "Face enrollment verified" / "{labor} (File ID: {id}) is ready for attendance matching. Open Site Management to sync if needed." | A labourer's face enrolment becomes ready (`elrace_backend_apis/models/user_face_image.py:12`, processed by a 15-minute cron) | The labourer's foreman | Yes | Nothing (push data is `"None"` for all routing keys) |

There are no timesheet submit/approve pushes. Check-in/check-out reminders are local and disabled (section 4).

## 3.7 App configuration and admin

| # | Notification | Trigger | To | Inbox | Tap |
|---|---|---|---|---|---|
| CFG-1 | "Your app menu changed" / "Your dashboard widgets were updated. Please re-login to see the changes." | An employee's custom widget list is changed (`emp_mobile_conf/models/hr_employee.py:164` → `widget_update_notify.py:25`). **Role template changes do not push**; they force a logout instead. | The employee | Yes | Nothing (no forced re-login) |
| ADM-1 | Admin-written title and message | "Send" on **Mobile Admin Notification** (`emp_mobile_conf/models/mobile_admin_notification.py:89`) | All non-labour staff, or selected employees | Yes | Nothing |

## 3.8 Chat, tasks and tickets (Cloud Functions + app)

| # | Notification | Trigger | To | Inbox | Tap |
|---|---|---|---|---|---|
| CH-1 | Sender name (DM) or "{group} • {sender}" / message text, or 📷 Photo, 📎 File, 🎵 Voice message, 🎬 Video, 📝 Document for signing | New chat message. Background: Cloud Function `onNewChatMessage`. Foreground: the app's Firestore listener (`lib/chat/services/chat_notification_service.dart:124`), which skips own messages, the open chat, muted chats, and messages older than 10 seconds. | Chat members | Yes (even while that chat is open) | Opens the chat |
| TK-1 | New task assigned | Task created and assigned (`functions-assignment/index.js:130, 224`) | Assignee | Yes | Opens task details |
| TK-2 | Task completed | Task completed (`functions-assignment/index.js:169`) | Creator | Yes | Opens task details |
| TK-3 | New / completed ticket | Queued by the app (`assignment_push_service.dart`) | Assignee / creator | Yes | Opens the Tasks list (not the ticket) |

Task and ticket pushes ask for Android channel `task_notifications`, which the app never creates (it creates `task_notifications_channel`), so they fall back to the default channel.

# 4. Notifications scheduled by the app itself (local)

| # | Notification | Schedule / trigger | Channel | Cancelled when | Location |
|---|---|---|---|---|---|
| L-1 | "🕌 Prayer Time" / "🔔 It's now time for {prayer} prayer" (adhan sound) | Today's 5 prayers, scheduled at app start and nightly (WorkManager). Egyptian method, Shafi madhab, last location or Dubai. **Inexact** on Android (exact alarm permission removed). | `prayer_adhan_channel_sound_v3` | App returns to foreground, prayer muted, rescheduled. **Not on logout.** | `lib/data/services/prayer_notification_service.dart:114` |
| L-2 | Same text, silent (audio played in-app) | App open and a prayer is within 5 minutes (30-second timer) | `prayer_adhan_channel_silent_v1` | On tap | `prayer_notification_service.dart:73` |
| L-3 | "📋 New Task Assigned" / "🎫 New Ticket Assigned" | Creating a task assigned to yourself (`add_task.dart:328`); self-assigned ticket (`tasks_provider.dart:418`) | `task_notifications_channel` | Muted via task/ticket | `task_notification_service.dart:89` |
| L-4 | "⏰ Task Deadline Tomorrow" / "{task} is due in 24 hours" | Scheduled on task create, **on the creator's phone only** | same | Task completed on this phone; tasks muted. Not on edit, delete or logout. | `task_notification_service.dart:136` |
| L-5 | "🚨 Task Due Soon!" / "{task} is due in 1 hour" | Same | same | Same | `task_notification_service.dart:163` |
| L-6 | "✅ Task Completed" / "{task} has been completed" | Completing a task — **notifies the person who completed it** | same | — | `task_notification_service.dart:193` |
| L-7 | "💬 New message in {task}" / "{sender}: {text}" | Sending a task comment — **notifies the sender** | same | — | `task_notification_service.dart:229` |
| L-8 | "⏰ Check In Reminder" / "Don't forget to Check In" (08:00–09:00 every 15 min) and "⏰ Check Out Reminder" (16:00–17:00) | **Disabled** (`scheduleCheckInReminders()` returns immediately) | — | Cancelled at start, check-in/out, logout | `checkin_reminder_notification_service.dart:171, 298` |

# 5. Web-only notifications (never reach the app)

| Area | What happens | Location |
|---|---|---|
| Odoo dashboard bell | `elrace.notification` records + Odoo bus (categories: employee request, LPO, employee register, project open/completed, petty cash, widget update, IT custody) | `elrace_notification.py:1657, 1835` |
| Live counters | Pusher channel `private-user-{uid}` (notification and waiting counters). **Pusher keys and secret hard-coded.** | `elrace_realtime/models/pusher_service.py:20` |
| IT custody | "IT Custody Assigned" (web bell only) | `elrace_notification.py:3024` |
| Helpdesk | Odoo bus + `mail.activity` | `pandora_helpdesk_customization/models/helpdesk_ticket.py:28, 87` |
| Delegation | `mail.activity` to the approver group; hourly cron | `delegations/models/delegation.py:101` |
| Elrace Hub | Pending-approval pushes to the Hub web app | `elrace_notification.py:2176` |

# 6. Notification Center, badge and mute

## 6.1 Screens

| Item | Behaviour | Location |
|---|---|---|
| Notification Center | Loads up to 50 items (server + local), **marks everything read on open**, hides circulars and announcements, no category filter. Swipe to delete; "Clear all". **Tapping a row does nothing.** | `lib/ui/presentation/Notification/notification_screen.dart:46, 72, 144` |
| Bell badge | "New since the Notification Center was last opened". Polls the server **every 5 seconds** while the home header is visible. | `home_glass_app_bar.dart:99`; `notification_storage_service.dart:732` |
| App icon badge | iOS only. Android does nothing. | `ios/Runner/AppDelegate.swift:47`; `MainActivity.kt:100` |
| Mute settings | Per category, from Odoo categories plus local ones (chat, prayer, task, ticket). "waiting" covers all four approval models; "alert" covers weather/safety/summer. A second mute popup in the profile card uses different rules. | `notification_mute_settings_screen.dart`; `profile_box_with_slide_animation.dart:170` |

## 6.2 Inbox APIs (Odoo)

| Route | Purpose |
|---|---|
| `POST /api/notifications` | List (limit 50) + unread count. Model `expo.notification.users` for the logged-in user. |
| `POST /api/notifications/read` | Mark one read |
| `POST /api/notifications/delete` | Delete one |
| `POST /api/notifications/clear` | Delete all |
| `POST /api/mobile/notification/categories` | Mute categories (configured in the database, no seed data) |
| `POST /api/mobile/notification/preferences`, `/update` | Read / set mute |
| `POST /api/save_expo_token` | Register the phone's FCM token |

A daily cron keeps the last 50 inbox rows per user. The legacy module `pandora_project_timesheets_apis` registers the same routes; which one runs depends on module load order.

# 7. Device token lifecycle

| Step | Behaviour |
|---|---|
| Registration | App calls `POST /api/save_expo_token` after login, on every resume, and on token refresh. Stored in `res.users.expo_token` (one per user). Login also stores the token per device in `mobile.device.fcm_token`. |
| Which device gets the push | Most senders use only `expo_token`, so **only the last device used receives the push**. Projects (PR-1 to PR-3), widget update and announcements reach all devices. |
| Logout | **The token is not removed.** Neither the app nor the backend clears it, so a logged-out phone keeps receiving that user's pushes. Tokens are removed only when FCM reports them invalid. |
| Chat tokens | Separate list in Firestore `users/{uid}/fcm_tokens`, removed on chat sign-out. |

# 8. Android and iOS setup

| Item | Detail |
|---|---|
| Android channels | `high_importance_channel` (default for FCM), `chat_messages`, `task_notifications_channel`, `prayer_adhan_channel_sound_v3`, `prayer_adhan_channel_silent_v1`. Check-in/out channels are never created. `task_notifications` (used by Cloud Functions) does not exist. |
| Android icon | Full-colour launcher icon used as the small icon; no FCM default icon/colour in the manifest. Usually shows as a white square. |
| Android exact alarms | Permissions removed, so prayer and task reminders can be late. |
| iOS permission | Requested natively at first launch (`AppDelegate.swift:22`), before the splash. |
| iOS foreground | `willPresent` forces banner + sound + badge for **every** notification, while the Dart side also shows its own banner and applies mute. Risk of double banners and muted pushes still showing. **Needs a device test.** |
| iOS delegate | `didReceive` and `didReceiveRemoteNotification` do not call `super`; may stop tap and background handlers. **Needs a device test.** |

# 9. Issues found

## 9.1 High priority

| # | Issue | Where | Effect |
|---|---|---|---|
| 1 | **Taps ignored after login.** `markHomeReady()` is only called from the splash screen. Logging in from the sign-in screen goes straight to `HomeScreen`. | `firebase_service.dart:58`; `sign_in_screen.dart:114` | Every chat, task and circular tap is queued and never opened until the app restarts. |
| 2 | **Most notifications do nothing on tap**, and Notification Center rows do nothing on tap. The backend sends `model` + `record_id` + `click_action: OPEN_RECORD`, but the app does not route them. | `firebase_service.dart:778-811`; `notification_screen.dart:144` | Approvers cannot open the request, LPO, invoice or petty cash from the notification. |
| 3 | **Duplicate approval pushes** when approving from the app. | `approval_service.py:472-483` | Requester and next reviewer each get two notifications. |
| 4 | **Token not cleared on logout.** | App logout helpers; backend | Another user's approvals and HR notifications can reach a shared or handed-over phone. |
| 5 | **Duplicate inbox rows / badge +2** — background handler and tap handler store the same push with different ids. | `main.dart:162`; `firebase_service.dart:700` | Inbox shows the same item twice. |
| 6 | **Legacy token endpoint is open.** `/api/update/expo/token` is `auth="public"` and accepts any `user_id`. | `pandora_tier_validation_apis/controllers/main.py:13`; `pandora_model_based_notifications/controllers/main.py:13` | Anyone can redirect a user's pushes to their own phone. |

## 9.2 Medium priority

| # | Issue | Where |
|---|---|---|
| 7 | "New Request to Approve" is also sent after an HR request is **rejected**; the web refuse wizard sends "fully processed" on rejection. | `elrace_notification.py:2979, 1418` |
| 8 | Annual leave uses the generic text "New Request Submitted". | `elrace_notification.py:1873-1906` |
| 9 | "Document signed" is invisible while the app is open and opens a fake chat when tapped. | `firebase_service.dart:190-198` |
| 10 | Document expiry reminder repeats **every day** for 30 days. | `document_expiry_notify.py:18` |
| 11 | Petty cash "Paid" names the wrong sheet when several are paid together; petty cash final approval reads `amount_total`, which does not exist on `hr.expense.sheet` (may error — verify). | `elrace_notification.py:871, 809-837` |
| 12 | Push data contains the text `"None"` for missing keys (HR-2 `record_id`, FACE-1, CFG-1). | `elrace_notification.py:2712` |
| 13 | Task/ticket channel mismatch (`task_notifications` vs `task_notifications_channel`). | `functions-assignment/index.js:47` |
| 14 | Self-notifications: comment sender and task completer notify themselves; deadline reminders only on the creator's phone. | `task_details.dart:531, 1122`; `add_task.dart:334` |
| 15 | Circulars/announcements raise the bell badge but are hidden from the Notification Center. | `notification_screen.dart:72` |
| 16 | Badge baseline is taken before "mark all read", so the server-driven badge stays at 0 afterwards. | `notification_screen.dart:49-52` |
| 17 | Muted users: some senders skip the inbox row, others still write it; tasks/tickets/prayer mute is phone-only, so background pushes still show. | `elrace_notification.py:2469`; `notification_service.py:28` |
| 18 | Mark-all-read always fires two requests; badge polling every 5 seconds. | `notification_api_service.dart:505`; `home_glass_app_bar.dart:99` |
| 19 | Pushes are sent inside the business transaction; a push can go out for a change that is later rolled back. | Most senders |
| 20 | Hard-coded values: user 874 (projects), `operating.unit` 6 (FCM credentials), Pusher secrets, inbox API base URL in the app. | Various |

## 9.3 Dead or legacy code

- **Expo senders** (tokens are now FCM, so Expo rejects them): `pandora_expo_notifications` (10-minute cron), `pandora_tier_validation_apis`, `pandora_model_based_notifications` (one HTTP call per chatter message), legacy `_create_and_send` in `my_request_apis` / `my_approvals_api`. If these modules are installed they waste a call on every event. Confirm in *Apps* and uninstall.
- **Legacy FCM server-key API** (shut down by Google in 2024): `spiffy_theme_backend/models/mail_channel.py`.
- **Never called / commented out:** `backup_send_fcm_push`, `backup_validate_tier`, `send_to_employee_and_validator`, `_send_request_creation_notifications`, `_send_review_notifications`, `_send_hr_request_notifications`, `restart_validation` push, BioTime `_send_biotime_fcm`.
- **App:** check-in/out reminders (disabled), `checkUpcomingDeadlines` (6-hourly job that only logs), FCM role-topic subscription (no sender).
- **Duplicate routes:** `pandora_project_timesheets_apis` and `elrace_backend_apis` both register `/api/submit_request`, `/api/record/tier_review`, `/api/approve_reject_hr_request`, `/api/submit_expense`, `/api/save_expo_token`, the notification routes and the folder routes.

# 10. Recommended next steps

1. Call `markHomeReady()` after login (sign-in and UAE PASS) and `markHomeNotReady()` on logout. **App release required.**
2. Route Odoo pushes and Notification Center rows by `model` + `record_id` to the matching detail screen (HR request, LPO, invoice, petty cash, project, documents). **App release required.**
3. Remove the second push in `ApprovalService.tier_review` (backend only).
4. Clear `expo_token` and the device token on logout (backend `linked-devices/logout-current`; app `deleteToken()`).
5. Secure or remove `/api/update/expo/token` (backend only).
6. Fix HR rejection texts, the annual-leave title, petty cash "paid" naming, and send `type` in the push data (backend only).
7. Make document expiry reminders fire at 30, 7 and 1 day(s) instead of daily (backend only).
8. Uninstall the Expo modules after confirming they are installed.
9. Test on iOS devices: double banners, mute, and tap handling.

# Appendix — Main source files

**Backend (`odoo14-clients`)**

- `elrace_dashboard/models/elrace_notification.py` — core sender and most triggers
- `elrace_backend_apis/services/notification_service.py`, `approval_service.py`, `request_service.py`, `hr_submit_service.py`, `announcement_push_queue.py`, `face_enrollment_notification_service.py`
- `elrace_backend_apis/controllers/notification_controller.py`, `auth_controller.py`, `approval_controller.py`, `petty_cash_controller.py`, `cloud_controller.py`, `staff_fcm_tokens_controller.py`
- `emp_mobile_conf/models/document_expiry_notify.py`, `mobile_admin_notification.py`, `widget_update_notify.py`, `hr_employee.py`, `mobile_device.py`
- `elrace_project_new_theme/models/staff_list.py`, `cubes_biotime/models/attendance_sync.py`, `elrace_backend_apis/models/user_face_image.py`

**App (`Elrace-mobileapp-operations`)**

- `lib/firebase_service.dart`, `lib/main.dart`
- `lib/core/services/notification_storage_service.dart`, `notification_api_service.dart`
- `lib/ui/presentation/Notification/notification_screen.dart`, `notification_mute_settings_screen.dart`, `notification_category_theme.dart`
- `lib/chat/services/chat_notification_service.dart`
- `lib/data/services/task_notification_service.dart`, `prayer_notification_service.dart`, `checkin_reminder_notification_service.dart`
- `functions/index.js`, `functions/notes_share_notify.js`, `functions/sign_document_sync.js`, `functions/odoo_announcement_push.js`, `functions-assignment/index.js`
- `android/app/src/main/AndroidManifest.xml`, `ios/Runner/AppDelegate.swift`

# 02 — Trigger Matrix: manager's revision → notification types

Target: `../Elrace_Notifications_Inside_Outside_Updated.docx` (28 Oct 2026).
Legacy IDs (`HR-1`, `AP-3`, …) refer to `../NOTIFICATIONS_CATALOGUE_AND_TRIGGERS.md`.

Channel: **push** = OUTSIDE (phone only), **inbox** = INSIDE (Notification Center only), **none** = disabled.
Rows the manager marked `*` are proposals; they are seeded with his proposed channel. Because the
channel is a field on `elrace.notify.type`, changing it later is a config edit — no deploy, no release.

Global rules for every type (dispatcher, not per trigger):
staff only (`exclude_labour`), actor excluded, mute respected unless mandatory,
all active devices, nothing after logout, dedupe, tap opens the exact record after a permission check.

## 1. Types

### 1.1 Waiting approvals (manager §1 — firm: push only)

One type, many sources. Title `New {request_type} Waiting for Your Approval`, body
`{request_type} {reference} is waiting for your approval/action.`, action `open_record`, category `waiting`.

| Code | Source (hook) | Recipients | `model` | `request_type` label | Hub category | Retires |
|---|---|---|---|---|---|---|
| `approval.waiting` | HR: next pending validator after `request.validation.status` create/write; app submit `/api/submit_request`, `/api/hr/submit_request`; web refuse wizard when a next approver exists | Current validator(s) | `employee.requests` | HR request type name + " Request" (e.g. "Annual Leave Request") | `hr` | HR-1, HR-3, HR-4 (next-approver part), HR-5 |
| ″ | LPO/RFQ: `purchase.order.request_validation()`, `validate_tier()` when tiers remain, `/api/record/tier_review` | Next reviewer(s) | `purchase.order` | "LPO" (see OD-4) | `rfq` | AP-1, AP-3, AP-5 (next reviewer) for PO |
| ″ | Petty cash: `hr.expense.sheet.request_validation()`, `validate_tier()`, `/api/submit_expense` | Next / current reviewer | `hr.expense.sheet` | "Petty Cash" | `petty_cash_pending` | AP-1, AP-3, AP-5, AP-6 for petty cash |
| ″ | Invoice: `account.move.request_validation()`, `validate_tier()` — **customer invoices only** (OD-1) | Next reviewer | `account.move` | "Invoice" | existing mapping | AP-1, AP-3, AP-5 for invoice |
| ″ | Signature: document sent for signing (Firestore `signature_documents`) — via ingest | Pending signer | `firestore.signature` | "Signature" | `signature` | "Document for signing" chat text stays as chat; this adds the waiting push (OD-9) |
| ″ | IT Request: pending line on `it.hardware.request.approval` (OD-9) | Pending approver | `it.hardware.request` | "IT Request" | — | — |

Dedupe `event_key`: the tier/validation line id, so the two legacy paths (web tier + app review) can never send twice (catalogue issue #3).

### 1.2 HR — Employee requests (manager §2)

| Code | Channel | When | Recipients | Title | Body | Action | Retires |
|---|---|---|---|---|---|---|---|
| `hr.request.approved` | inbox (firm) | **Final** approval only (no next validator remains) | Requester (`employee_id.user_id`) | `Request Approved` | `Your {request_type} request has been approved.` | `open_record employee.requests` | HR-2 approved (per step), HR-4 "fully processed" |
| `hr.request.rejected` | inbox (firm) | Rejected (app or web wizard) | Requester only — **no next-approver notification** | `Request Rejected` | `Your {request_type} request has been rejected.` | `open_record employee.requests` | HR-2 rejected, HR-3 after rejection, HR-4 on rejection |
| `hr.employee.assigned` | inbox | Draft employee confirmed (`draft.hr.employee.action_confirm`) | Manager (`parent_id.user_id`) | `New Employee Assigned` | `New employee assigned under your team.` | `open_record hr.employee` | HR-6 |

### 1.3 LPO, Invoice, Petty cash (manager §3)

| Code | Channel | When | Recipients | Title | Body | Action | Retires |
|---|---|---|---|---|---|---|---|
| `purchase.lpo.issued` | inbox | PO final tier approved | **Assigned project manager only** (OD-3) | `LPO Issued` | `LPO for {vendor_name} has been issued.` | `open_record purchase.order` | AP-4 (PO, all reviewers), and the client patch `_withLpoIssuedRemap` |
| `account.vendor_invoice` | **none** | Any vendor bill action (`move_type` in `in_invoice`, `in_refund`) | — | — | — | — | AP-1..AP-5 for vendor bills (mobile only; Hub unchanged) |
| `expense.petty_cash.paid` | inbox | Each sheet paid (`approve_expense_sheets`), **per sheet** | Petty cash holder (`employee_id.user_id`) | `Petty Cash Paid` | `Your petty cash request no. {request_number} has been paid.` | `open_record hr.expense.sheet` | AP-7 (reviewers, wrong number) |

Not listed by the manager in this module and **retired when the module is taken over** (OD-2): AP-2 ("… Approved" per level to creator), AP-4 invoice/petty cash "Fully Approved", AP-5 requester messages.

### 1.4 Projects (manager §4)

| Code | Channel | When | Recipients | Title | Body | Action | Retires |
|---|---|---|---|---|---|---|---|
| `project.manager.assigned` | inbox* | `project.project` created with, or written to, a new `user_id` (OD-10) | New project manager | `Project Manager Assigned` | `You are assigned as a project manager to {project_name}.` | `open_record project.project` | — (new) |
| `project.member.added` | inbox* | User added to project staff list (`elrace_project_new_theme/models/staff_list.py`) | Newly added user | `Added to Project` | `You have been added to {project_name}.` | `open_record project.project` | PR-3, and PR-1 (creation fan-out + hard-coded user 874) |

PR-2 "Project Completed" is not in the matrix → stays on legacy (§4).

### 1.5 Documents and shared items (manager §5)

| Code | Channel | When | Recipients | Title | Body | Action | Retires |
|---|---|---|---|---|---|---|---|
| `document.expiry` | inbox* | Daily cron; send only when days-to-expiry ∈ {30, 7, 1}. Renewal changes `expiry_date` → no further reminders for the old date | Document owner | `Document Expiring Soon` | `{document_type} expires on {expiry_date}. Please renew.` | `open_record hr.employee.document` | DOC-1 (daily repeat) |
| `share.note` | inbox* | Note shared (Firebase → ingest) | Recipient | `Document / Note Shared` → render `Note Shared` | `{sender_name} shared a new note with you.` | `open_record firestore.note` | DOC-4 |
| `share.document` | inbox* | Document shared (source to confirm, OD-6) — **seeded inactive** | Recipient | `Document Shared` | `{sender_name} shared a new document with you.` | `open_record` (per source) | — |
| `document.signed` | inbox* | Signature completed (Firebase `sign_document_sync` → ingest) | Sender | `Document Signed` | `{signer_name} signed {file_name}.` | `open_record firestore.signature` | DOC-3 (fake chat tap, hidden in foreground) |

Dedupe for expiry: `event_key = "{doc_id}:{expiry_date}:{threshold}"`.

### 1.6 Circulars and announcements (manager §6)

| Code | Channel | When | Recipients | Title | Body | Action | Retires |
|---|---|---|---|---|---|---|---|
| `circular.published` | inbox* | `odx.announcement` becomes active/published | Selected users, else all active staff (OD-7) | `New Circular` | `New circular for {circular_title} has been announced.` | `open_screen circulars` + `params {id, tab}` | ANN-1 (Firestore job + function path) |

- New field on `odx.announcement`: `x_notify_mandatory` (Boolean). When True, `emit(..., mandatory=True)` → cannot be muted. No acknowledgment.
- Circulars now **appear in the Notification Center** (today hidden but counted in the badge — catalogue issue #15).

### 1.7 Removed (manager §7, §8)

| Code | Channel | Action |
|---|---|---|
| `attendance.checkin_reminder` | none | Already disabled in the app (`scheduleCheckInReminders()` returns). Keep it disabled; no backend work |
| `attendance.biotime_sync` | none | Retires ATT-1 (`cubes_biotime/models/attendance_sync.py`). The app's attendance refresh-on-push becomes irrelevant |

### 1.8 Tasks (manager §9 — Firestore `todos`, via ingest)

| Code | Channel | When | Recipients | Title | Body | Action | Retires |
|---|---|---|---|---|---|---|---|
| `task.assigned` | push* | Task created/assigned (`onAssignedTodoCreated`, `onAssignmentPushRequest`) | Assignee | `New Task Assigned` | `{assigned_by} assigned you: {task_title}.` | `open_record firestore.todo` | TK-1, L-3 |
| `task.comment` | inbox* | Comment added (new Firestore trigger on `comments`) | Task participants (creator + assignees) **except the commenter** | `New Task Comment` | `{sender}: {comment}` | `open_record firestore.todo` | L-7 (self-notify) |
| `task.completed` | inbox* | Task completed (`onTodoCompleted`) | Participants except the completer | `Task Completed` | `{completed_by} completed {task_title}.` | `open_record firestore.todo` | TK-2, L-6 (self-notify) |
| `task.deadline_24h` | push* | Scheduled function: due in 24 h and task still active | Assignee(s) | `Task Deadline Tomorrow` | `{task_title} is due in 24 hours.` | `open_record firestore.todo` | L-4 (creator's phone only) |
| `task.deadline_1h` | push* | Scheduled function: due in 1 h and still active | Assignee(s) | `Task Due Soon` | `{task_title} is due in 1 hour.` | `open_record firestore.todo` | L-5 |

Deadline dedupe: `event_key = "{todo_id}:{due_at}:{24h|1h}"` (a changed due date re-arms the reminder).

### 1.9 Tickets (manager §10 — Firestore `tickets`, via ingest)

| Code | Channel | When | Recipients | Title | Body | Action |
|---|---|---|---|---|---|---|
| `ticket.assigned` | push* | Ticket assigned | Responsible + creator (+ CC, OD-5), except actor | `Ticket Assigned` | `{ticket_title} has been assigned to {assignee}.` | `open_record firestore.ticket` |
| `ticket.updated` | inbox* | Update or comment | Creator, responsible (+ CC), except actor | `Ticket Updated` | `{ticket_title}: {update_summary}` | ″ |
| `ticket.reassigned` | inbox* | Assignee changes | New assignee + participants, except actor | `Ticket Reassigned` | `{ticket_title} reassigned to {assignee}.` | ″ |
| `ticket.closed` | inbox* | Ticket closed | Creator, responsible (+ CC), except actor | `Ticket Closed` | `{ticket_title} has been closed.` | ″ |

Retires TK-3 ("opens the Tasks list") and L-3 for tickets. `{update_summary}` = first 120 characters of the comment, or "Status changed to {status}".

### 1.10 Chat (manager §11) — stays in Firebase

`chat.direct`, `chat.group`: push, unchanged mechanics (`functions/index.js onNewChatMessage`). Changes: add contract keys (`nv`, `type`, `action=open_chat`, `params`), and the app **stops saving chat to the Notification Center** (manager: outside only). Open chat and muted chat skipped as today.

### 1.11 Prayer (manager §12) — stays local

Local schedule unchanged. Text: title `Prayer Time`, body `It is time for {prayer}.` Tap opens the app.

## 2. Notification Center and general rules (manager §13)

| Rule | Where implemented |
|---|---|
| Open exact record | Payload `action/model/res_id` + Flutter router (M1, M2) |
| Permission check before open | `POST /api/v2/notifications/open` (B5) |
| Opening the center marks read | `mark_all_read` on open (B5, M4) |
| Clear All hides, originals kept | `is_hidden` (B5, M4) |
| 90-day searchable/filterable history | `list` with `q`, `category`, dates; retention cron (B5, M4) |
| All devices; stop after logout | `mobile.device` registry, `device/unregister` (B4, M3) |
| No duplicates / wrong recipients | Dedupe key + single path + Android `tag` (B2) |
| Mandatory circulars | `mandatory` on emit (B12) |
| No labour | `exclude_labour` (B2) |

## 3. Category seed (`mobile.notification.category`)

| Code | Name | Mandatory | Local only |
|---|---|---|---|
| `waiting` | Waiting approvals | no | no |
| `hr` | HR requests | no | no |
| `purchase` | LPO | no | no |
| `petty_cash` | Petty cash | no | no |
| `project` | Projects | no | no |
| `document` | Documents | no | no |
| `circular` | Circulars & announcements | no (per-circular mandatory) | no |
| `task` | Tasks | no | no |
| `ticket` | Tickets | no | no |
| `chat` | Chat | no | yes |
| `prayer` | Prayer | no | yes |

Existing category rows in production keep their codes; the seed adds missing ones only (`noupdate="1"`), **inactive**, never renames. Each category is activated with the wave that first uses it, so current users see no change on deploy. The `alert` category (weather/safety) has no sender left; leave it, do not delete.

## 4. Not in the manager's matrix → stay on legacy, untouched

PR-2 Project completed · DOC-2 Shared-folder add/remove · FACE-1 Face enrolment · CFG-1 App menu changed · ADM-1 Admin broadcast (already excludes labour) · Labour-transfer pushes · Timesheets (none exist) · IT custody web bell · Web bell `elrace.notification` · Hub pending pushes (kept via adapter).

They can be migrated later as config rows without app changes because the router already handles `open_record`.

## 5. Open decisions — default used until Jawad confirms

| # | Question | Default implemented |
|---|---|---|
| OD-1 | Waiting lists "Invoice" but §3 says vendor invoice → none | Waiting for **customer** invoices; vendor bills none on mobile. Hub unchanged |
| OD-2 | LPO/petty/invoice per-level "Approved" and "Fully Approved" to requester are not in the matrix | Retired when the module's types are taken over |
| OD-3 | "Assigned Project Manager" for an LPO | `purchase.order.project_id` (analytic account) → `project.project` with that `analytic_account_id` → `user_id`. None found → no send, logged as `skipped_no_recipient` |
| OD-4 | RFQ vs LPO label | "LPO" for all `purchase.order` approvals |
| OD-5 | Ticket CC | No CC field exists in Firestore tickets. Recipients = creator + responsible until CC is added |
| OD-6 | "Document shared" source | Only note sharing exists today. `share.document` seeded inactive |
| OD-7 | Circular "All users" | Selected users if set, otherwise all active staff; labour excluded |
| OD-8 | `*` delivery choices | Manager's proposed values, editable later in config |
| OD-9 | Signature and IT Request waiting sources | Seeded inactive until the hook is confirmed in the task |
| OD-10 | Project manager field | `project.project.user_id` |

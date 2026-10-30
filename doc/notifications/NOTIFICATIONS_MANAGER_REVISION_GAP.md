# Notifications — manager revision vs what is already built

**Date:** 29 October 2026  
**Source of the target:** `Elrace_Notifications_Inside_Outside_Updated.docx` (28 October 2026)  
**Checked against:** current mobile app and Odoo senders (not the 15 October catalogue alone)

The Word file is the target. This note covers only what that file specifies. Modules he did not mention stay as they are.

Delivery words used below:

- **Outside** — phone push only
- **Inside** — in-app Notification Center only
- **None** — do not send

Rows he marked with `*` still need his confirmation on inside vs outside. The event, recipient, title, message, and tap are what this gap check uses.

---

## Already in place

| Item | Status |
|---|---|
| Check-in / check-out reminders | Scheduler returns immediately. Nothing is sent. Matches “removed for now.” `lib/data/services/checkin_reminder_notification_service.dart` |
| Chat (direct and group) | Push goes to the other people. The open chat is skipped. Tap opens that conversation. `functions/index.js`, `lib/chat/services/chat_notification_service.dart`, `lib/firebase_service.dart` |
| Prayer | Fires at prayer time when the user has not muted it. Tap brings the app forward. `lib/data/services/prayer_notification_service.dart` |
| Mark read | Opening the Notification Center marks the loaded items read. `lib/ui/presentation/Notification/notification_screen.dart` |
| Clear All control | The button exists. It deletes the rows. He wants them hidden from the user’s list while the original records stay. `lib/core/services/notification_storage_service.dart` |

---

## Specified, and a version already runs, but it does not match

| What he wants | What runs today |
|---|---|
| One waiting push: `New {Request Type} Waiting for Your Approval`. Staff approver only. Tap opens that record. Covers HR, RFQ, LPO, Invoice, Petty Cash, Signature, IT Request. Outside only. | Separate titles still go out (`New LPO Approval Request`, `New Request to Approve`, `New Petty Cash Approval Request`, and others). Tap opens nothing. Several are also stored in the Notification Center. `elrace_dashboard/models/elrace_notification.py` |
| HR approved or rejected only after the **final** decision, to the employee, inside the app. Message: `Your {Request Type} request has been approved/rejected.` Tap opens the request. | `Request Approved` / `Request Rejected` already exist. They fire on **every** approval step, include the approver’s name, go out as a phone push, and the tap opens nothing. The next approver is also notified on a rejection. `elrace_notification.py` `send_employee_request_status_update` |
| New employee assigned to a manager: `New Employee Assigned`. Tap opens the employee. | The manager already gets `New Employee Registered: {Name}`. Tap opens nothing. |
| LPO issued: assigned project manager only. `LPO Issued` / `LPO for {Vendor Name} has been issued.` Tap opens the LPO. | On final approval every reviewer gets `LPI has been issued` with only the vendor name. Tap opens nothing. `elrace_notification.py` purchase-order final approval |
| Petty cash paid: the holder. `Your petty cash request no. {Request Number} has been paid.` Tap opens the request. | Reviewers get `Petty Cash Paid` / `{name} has been paid.` Tap opens nothing. If several sheets are paid together, they can all show the same number. `elrace_notification.py` `approve_expense_sheets` |
| Project manager assigned, and a user added to a project. Tap opens the project. | “Added to project” already exists as `New Project Assigned` / `You have been added to {Project}`. There is no separate “you are the project manager” message. Tap opens nothing. `elrace_project_new_theme/models/staff_list.py`, `elrace_notification.py` |
| Document expiry at 30, 7, and 1 days, then stop after renewal. Tap opens the document. | A daily job notifies the owner for anything expiring within 30 days, and it repeats every day. Tap opens nothing. `emp_mobile_conf/models/document_expiry_notify.py` |
| Document or note shared, and document signed. Tap opens that item. | Both already send. Note tap opens nothing. Signed-document tap opens a chat screen. `functions/notes_share_notify.js`, `functions/sign_document_sync.js` |
| New circular: `New Circular` / `New circular for {Circular Title} has been announced.` Tap opens it. Important circulars cannot be muted. | Publish already pushes, and the tap opens the circular. The title is `Circular published` and the body is the start of the text. Circulars are hidden from the Notification Center, and they can still be muted. |
| New task to the assignee. Deadline at 24 hours and at 1 hour to the assignee, only while the task is still active. Comment and completion go to the other people, not the person who just acted. Tap opens the task. | New-task push to the assignee exists, and the tap can open the task. The 24-hour and 1-hour reminders are scheduled on the creator’s phone. Comment and completion notify the person who did the action. `functions-assignment/index.js`, `lib/data/services/task_notification_service.dart` |
| Ticket assigned, updated, reassigned, and closed, with the actor excluded. Tap opens the ticket. | Assign and complete exist. Reassignment and a comment/update notification are not separate. A ticket tap can open the tasks list instead of that ticket. |
| Tap opens the exact record, after an Odoo permission check. | Chat, task, ticket, and circular open a screen. HR, LPO, petty cash, projects, and documents do not. There is no permission check before opening. `lib/firebase_service.dart`; Notification Center row tap only closes the swipe chrome (`notification_screen.dart`). |
| 90 days of history, with search and filters. | The center loads the latest 50. There is no search or category filter. |
| Every logged-in device, and stop on that device after logout. | Most Odoo pushes use one saved token, the last phone. Logout revokes the session and does not clear that token, so the phone can still receive pushes. `elrace_backend_apis/controllers/linked_devices_controller.py` `logout-current` |
| No duplicate notifications. No labour users. | Approving an LPO, invoice, or petty cash from the app still sends two notifications (tier validation plus the app review update). There is no global block for labour users. |

---

## He said send nothing, and the code still sends

| Item | Today |
|---|---|
| Vendor invoice actions | Approval and “fully approved” pushes for invoices are still active. He marked this **None**. |
| BioTime attendance sync | A manual BioTime pull can still send `Attendance Updated`. He marked this removed for now. |

Check-in / check-out is already stopped. No change there.

---

## Leave these alone

He did not mention them, so they stay:

- Timesheets
- Face-enrolment alerts
- Project completed
- Shared-folder add / remove
- App-menu changes
- Admin broadcasts
- Labor-transfer pushes

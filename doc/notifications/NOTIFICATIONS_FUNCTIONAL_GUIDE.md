---
title: "Elrace Mobile App — Notifications Guide"
subtitle: "What notifications users receive, when they are sent, and what they say"
date: "15 October 2026"
---

**About this document.** This document lists every notification the Elrace mobile app shows, grouped by module. For each notification, it shows:

- when it is sent;
- who receives it;
- the title and message text the user sees;
- what happens when the user taps it.

Words in *{curly brackets}* are filled in automatically (for example *{Employee name}*).

# 1. How notifications work

## 1.1 Where notifications come from

| Source | Examples |
|---|---|
| **Odoo (ERP)** | HR requests, LPO / invoice / petty cash approvals, projects, documents, attendance, admin messages |
| **Chat and Tasks** | Chat messages, tasks and tickets, shared notes, signed documents |
| **Announcements** | Circulars and announcements published in Odoo |
| **The phone itself** | Prayer times, task reminders |

## 1.2 Notification flow

1. Something happens in the business, for example an employee submits a leave request or a manager approves an LPO.
2. The system checks whether the receiver has **muted** this category in the app settings. If it is muted, nothing is sent.
3. The receiver gets a notification on their phone:
   - **App closed or in background:** it appears in the phone's notification bar.
   - **App open:** it appears as a banner at the top of the screen. Chat messages are not shown for the chat the user currently has open.
4. Most notifications are also saved in the app's **Notification Center** (the bell icon).
5. The **bell badge** shows how many new notifications arrived since the user last opened the Notification Center.
6. When the user opens the Notification Center, all notifications are marked as read.

## 1.3 Muting notifications

Users can mute notifications by category from **Profile → Notification settings**. The categories are:

- **Waiting approvals:** HR requests, LPOs, invoices and petty cash
- **Chat**
- **Tasks**
- **Tickets**
- **Prayer**
- **Alerts:** weather and safety
- other categories configured in Odoo

# 2. Notifications by module

## 2.1 HR — Employee Requests

Covers leave, sick leave, short leave, job mission, effective date update and temporary permission.

| Notification | When it is sent | Who receives it | Title | Message | On tap |
|---|---|---|---|---|---|
| New request | Employee submits a request from the app | Next approver | Depends on type: "Leave Request", "Sick Leave Request", "Short Leave Request", "Job Mission Request", "Effective Date Update Request", "Temporary Permission". Other types: "New Request Submitted" | "*{Employee name}* has submitted a *{request type}*." Other types: "*{Employee name}* submitted a new request." | Nothing opens |
| Request approved | Approver approves the request in the app | Employee who submitted | "Request Approved" | "*{Approver name}* has approved your request." | Nothing opens |
| Request rejected | Approver rejects the request in the app | Employee who submitted | "Request Rejected" | "*{Approver name}* has rejected your request." | Nothing opens |
| Next approval needed | Request moves to the next approver | Next approver | "New Request to Approve" | "A new request from *{Employee name}* needs your approval." | Nothing opens |
| Request rejected (from Odoo web) | Approver rejects with a reason in Odoo web | Next approver, or the employee | "New Employee Request Approval", or "Employee Request Processed" | "*{Request}* requires your approval.", or "*{Request}* has been fully processed." | Nothing opens |
| New employee registered | HR confirms a new employee in Odoo | Employee's direct manager | "New Employee Registered: *{Name}*" | "Employee *{Name}* has been confirmed and added to the system" | Nothing opens |

## 2.2 Approvals — LPO, Invoice and Petty Cash

| Notification | When it is sent | Who receives it | Title | Message | On tap |
|---|---|---|---|---|---|
| Approval request | Document is sent for approval | First reviewer | "New LPO Approval Request" / "New Invoice Approval Request" / "New Petty Cash Approval Request" | "*{Document no.}* requires your approval." | Nothing opens |
| Level approved | A reviewer approves one level | Person who created the document | "LPO Approved" / "INVOICE Approved" / "Petty Cash Approved" | "*{Approver name}* approved *{Document no.}*" | Nothing opens |
| Next level needed | Document needs another approval level | Next reviewer | "New LPO Approval Required" / "New INVOICE Approval Required" / "New Petty Cash Approval Required" | "Please review *{Document no.}*" | Nothing opens |
| Fully approved — LPO | Last level approved | All reviewers | "LPO has been issued" | "*{Vendor name}*" | Nothing opens |
| Fully approved — Invoice / Petty cash | Last level approved | All reviewers | "Invoice Fully Approved" / "Petty Cash Fully Approved" | "*{Document no.}* has been fully approved." | Nothing opens |
| Approved / rejected from the app | Reviewer approves or rejects from the app | Person who requested | "Purchase Order Approved" / "Journal Entry Approved" / "Expense Report Approved" (or "… Rejected") | "*{Approver name}* approved / rejected *{Document no.}*." | Nothing opens |
| Next approval (from the app) | Same as above, when another level remains | Next reviewer | "New Approval Required" | "Please review *{Document no.}*" | Nothing opens |
| Petty cash submitted | Employee submits petty cash from the app | Reviewer | "Petty Cash Request Submitted" | "*{Employee name}* submitted a petty cash request of *{amount}* AED." | Nothing opens |
| Petty cash paid | Petty cash is paid | Reviewers | "Petty Cash Paid" | "*{Petty cash no.}* has been paid." | Nothing opens |

## 2.3 Projects

| Notification | When it is sent | Who receives it | Title | Message | On tap |
|---|---|---|---|---|---|
| New project | A new project is created | Everyone on the project staff list | "New Project Assigned" | "You have been added to *{Project name}*" | Nothing opens |
| Added to project | An employee is added to a project's staff list | That employee | "New Project Assigned" | "You have been added to *{Project name}*" | Nothing opens |
| Project completed | Project status changes to Completed | Everyone on the project staff list | "Project Completed" | "Project *{Project name}* is now completed" | Nothing opens |

## 2.4 Documents and Shared Folders

| Notification | When it is sent | Who receives it | Title | Message | On tap |
|---|---|---|---|---|---|
| Document expiring | Every day, for documents expiring within 30 days | Employee who owns the document | "Document expiring soon" | "*{Document}* expires on *{date}*. Please renew it." If there are several: "You have *{n}* documents expiring soon…" | Nothing opens |
| User added to folder | A user is added to a shared folder | All folder members | "Shared Folder Update" | "New user has been added to the shared folder '*{Folder}*'." | Nothing opens |
| User removed from folder | A user is removed from a shared folder | All folder members | "Shared Folder Update" | "A user has been removed from the shared folder '*{Folder}*'." | Nothing opens |
| Document signed | A document sent for signature is signed | Person who sent it | "Document signed" | "*{Signer name}* signed "*{File name}*"" | Opens a chat screen (incorrect) |
| Note shared | Someone shares a note | Person it was shared with | "Note shared with you" | "*{Owner name}* shared "*{Note title}*"" | Nothing opens |

## 2.5 Circulars and Announcements

| Notification | When it is sent | Who receives it | Title | Message | On tap |
|---|---|---|---|---|---|
| Circular / Announcement | A circular or announcement is published in Odoo | All employees, or the selected employees | "Circular published" / "Announcement published" | First 180 characters of the circular or announcement text | Opens **Circulars & Announcements** on that item |

## 2.6 Attendance and Face Enrolment

| Notification | When it is sent | Who receives it | Title | Message | On tap |
|---|---|---|---|---|---|
| Attendance updated | Attendance is pulled manually from BioTime | Employee | "Attendance Updated" | "Your attendance has been synced from BioTime. Please update the Project location." | Refreshes today's attendance |
| Face enrolment ready | A labourer's face photo is ready for attendance matching | Labourer's foreman | "Face enrollment verified" | "*{Labourer name}* (File ID: *{ID}*) is ready for attendance matching. Open Site Management to sync if needed." | Nothing opens |

There are no notifications for timesheet submission or approval.

## 2.7 App Menu and Admin Messages

| Notification | When it is sent | Who receives it | Title | Message | On tap |
|---|---|---|---|---|---|
| App menu changed | An employee's dashboard widgets are changed in Odoo | That employee | "Your app menu changed" | "Your dashboard widgets were updated. Please re-login to see the changes." | Nothing opens |
| Admin message | Admin sends a message from **Mobile Admin Notification** in Odoo | All staff (not labour), or selected employees | Written by admin | Written by admin | Nothing opens |

## 2.8 Chat

| Notification | When it is sent | Who receives it | Title | Message | On tap |
|---|---|---|---|---|---|
| New message (one-to-one) | Someone sends a chat message | The other person | "*{Sender name}*" | Message text, or "📷 Photo", "📎 File", "🎵 Voice message", "🎬 Video", "📝 Document for signing" | Opens the chat |
| New message (group) | Someone sends a group message | All group members except the sender | "*{Group name}* • *{Sender name}*" | Same as above | Opens the chat |

The user does not get a notification for a chat they already have open, or for a chat they have muted.

## 2.9 Tasks and Tickets

| Notification | When it is sent | Who receives it | Title | Message | On tap |
|---|---|---|---|---|---|
| New task | A task is assigned | Assignee | "📋 New Task Assigned" | "*{Assigned by}* assigned you: "*{Task title}*"" | Opens the task |
| New ticket | A ticket is assigned | Assignee | "🎫 New Ticket Assigned" | "*{Assigned by}* assigned you: "*{Ticket title}*"" | Opens the Tasks list |
| Task completed | A task is completed | Person who created the task | "✅ Task Completed" | "*{Completed by}* completed: "*{Task title}*"" | Opens the task |
| Ticket completed | A ticket is completed | Person who created the ticket | "✅ Ticket Completed" | "*{Completed by}* completed: "*{Ticket title}*"" | Opens the Tasks list |
| Deadline tomorrow | 24 hours before the task due time | Task creator (on the phone used to create it) | "⏰ Task Deadline Tomorrow" | "*{Task title}* is due in 24 hours" | Opens the task |
| Due soon | 1 hour before the task due time | Task creator (on the phone used to create it) | "🚨 Task Due Soon!" | "*{Task title}* is due in 1 hour" | Opens the task |
| New comment | A comment is added to a task | The person who wrote it (should be the others) | "💬 New message in *{Task title}*" | "*{Sender}*: *{Comment}*" | Opens the task |

## 2.10 Prayer Times

| Notification | When it is sent | Who receives it | Title | Message | On tap |
|---|---|---|---|---|---|
| Prayer time | At each of the 5 daily prayer times, based on the phone's location (Dubai if unknown) | Every user who has not muted prayer | "🕌 Prayer Time" | "🔔 It's now time for *{Prayer}* prayer" (with adhan sound) | Opens the app |

## 2.11 Check-in / Check-out Reminders (currently switched off)

| Notification | Planned schedule | Title | Message |
|---|---|---|---|
| Check-in reminder | 08:00–09:00, every 15 minutes, until checked in | "⏰ Check In Reminder" | "Don't forget to Check In" |
| Check-out reminder | 16:00–17:00, every 15 minutes, until checked out | "⏰ Check Out Reminder" | "Don't forget to Check Out" |

# 3. Notification Center (bell icon)

| Feature | Behaviour |
|---|---|
| List | Shows the latest 50 notifications |
| Read status | All notifications are marked as read when the screen is opened |
| Delete | Swipe a notification to delete it, or use **Clear all** |
| Tap on a notification | Nothing opens |
| Circulars and announcements | Not shown in this list (they are in **Circulars & Announcements**), but they are counted in the bell badge |
| Filter by category | Not available |

# 4. Points for functional review

These behaviours are in the app today and need a business decision or a fix:

1. **Most notifications do not open anything when tapped.** Only chat, tasks, tickets and circulars open a screen. Approvers cannot go from an approval notification (HR request, LPO, invoice, petty cash) to the record.
2. **After a normal login, tapping a notification does nothing** until the app is closed and opened again.
3. **Approvals done from the app send two notifications** to the requester (for example "LPO Approved" and "Purchase Order Approved"). The next reviewer also gets two ("New LPO Approval Required" and "New Approval Required").
4. **After logout, the phone still receives that user's notifications.** This matters if a phone is shared or handed over.
5. **The same notification sometimes appears twice** in the Notification Center.
6. **Rejected HR requests** also send "New Request to Approve" to the next approver. From Odoo web, the employee is told the request was "fully processed".
7. **Annual leave** uses the general title "New Request Submitted" instead of "Annual Leave Request".
8. **Document expiry** reminders repeat every day for 30 days. Suggestion: send them 30, 7 and 1 day(s) before expiry.
9. **"Document signed"** is not shown while the app is open, and tapping it opens the wrong screen.
10. **Task comments and task completion** notify the person who did the action instead of the other people on the task.
11. **Task deadline reminders** only appear on the creator's phone, not the assignee's.
12. **When several petty cash requests are paid together**, every notification names the same petty cash number.
13. **Users with more than one phone** receive most notifications only on the phone they used last. Projects, app menu changes and announcements reach all their phones.
14. **No timesheet notifications** (submitted, approved, rejected). Please confirm whether these are needed.
15. **Check-in / check-out reminders** exist but are switched off. Please confirm whether they should be enabled.

**Please confirm for each module:**

- Which screen should open when the user taps the notification?
- Are the titles and messages correct?
- Should any notification be added or removed?

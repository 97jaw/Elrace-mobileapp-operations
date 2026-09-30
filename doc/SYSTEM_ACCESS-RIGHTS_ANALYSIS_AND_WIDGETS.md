# Mobile App — Access Rights, Domains, and Home Widgets

**Audience:** System Analyst  
**Purpose:** Compare what the Elrace mobile APIs are supposed to return with Odoo access rights (`ir.model.access`) and record rules (`ir.rule` domains). Report leaks and gaps. Then configure home widgets per role and per employee before go-live.

**Date:** 29 September 2026 (revised; first issued 24 September)  
**Source:** Mobile app as implemented, plus the `elrace_backend_apis` controllers on branch `elrace-addons`. The phone does not apply Odoo domains. The API must.

**What changed since 24 September:** section 0 is new (routes with no login check). Projects v1 now uses the same portfolio domain as v2 (leak #5 and section 3.3 updated). Media "Projects" now follows a new `x_is_media_role` flag (leak #8 and section 3.9). Task widgets on Odoo 14 now use `project.task.user_id` (section 3.8).

---

## 0. Start here — routes that do not check who is calling

These routes are declared `auth='public'` or `auth='none'`, run with `sudo()`, and do **not** call the mobile token check (`_validate_mobile_request`). There is no global `/api` auth hook in the module. Anyone who can reach the server can call them, and Odoo record rules do not apply because of `sudo()`.

Test each one **without** an `Authorization` header. If it returns data or changes data, it is a critical leak.

**Confirmed by reading the code (critical):**

| Route | What it does without a token |
|---|---|
| `POST /api/timesheet/submit` | Creates timesheet lines for any `employee_ids` on any project |
| `POST /api/copy/timesheet/from/date` | Copies any timesheet ids to another date |
| `POST /api/update/timesheets/status` | Changes the stage (e.g. Approved) of any timesheet ids |
| `POST /api/delete/timesheet` | Deletes any timesheet id inside the 5-day window |
| `POST /api/project/timesheets/list` | Returns all analytic lines for any `project_id` and date range (added 22 Sep for Recent / Show all) |
| `POST /api/task/timesheets/list`, `/api/count/timesheets/by/days`, `/api/timesheet/check/by/date` | Reads timesheet data for any task or employee ids |
| `POST /api/employee/list` (timesheet controller) | Lists every labor and driver with employee code |
| `POST /api/tasks/list`, `/api/get/task/details` | Tasks by a `user_id` the caller supplies |
| `POST /api/survey/submit` | Submits survey answers as any `employee_id` the caller supplies |
| `POST /reports/list` and the other site-report routes | Trust `emp_id` from the request body |
| `GET /api/hub/export/projects` (and other `/api/hub/export/*`) | Exports company data for RCC Hub sync. Confirm whether nginx restricts these to the Hub server IP. If not, they are open |

**Flagged by an automated scan — verify each one:**

- `misc_controller`: `/api/register_face_images`, `/api/compare_face_lambda`, `/api/employee/list`, `/api/qr_code/<emp_id>`
- `purchase_controller`: `/api/purchase/draft_invoices`, `/api/purchase/draft_invoices_preview` (the other purchase routes do call `_auth`)
- `hub_controller`: `/api/hub/partners`, `/api/hub/signature/image/<user_id>/<field>`, `/api/hub/export/signatures`, `/api/hub/export/users`, `/api/hub/export/departments`, `/api/hub/users/update_rcchub_id`
- `site_report_controller`: `/api/operating_units`, `/api/create_report_folder`, `/api/create_report`, `/api/site_reports/*`, `/reports/*`, `/report-items/*`, `/report-cover/*`, `/api/upload_site_report`
- `survey_controller`: `/api/survey/`, `/api/survey/media`, `/api/survey/documents`, `/api/survey/any_published`
- `public_controller`: `/public/invoice/report/<id>`, `/public/po/report/<id>`, `/public/rfq/report/<id>`, `/my/public/file/<id>`. Image routes for employee and partner photos may be public by design. Invoice, PO, RFQ PDFs and generic attachment ids should not be

Login, SSO, UAE PASS callback, and app-config routes are public by design and are not leaks.

---

## How to use this brief

1. For each module below, log in to Odoo as a sample user of that role and note which records the user can open.
2. Call the same user’s mobile API (or open the same screen in the app) and compare the record set.
3. A leak is any record the API returns that the same user cannot open in Odoo, or any action the API accepts that the user’s groups do not allow.
4. A gap is any record the user can open in Odoo that the mobile API hides, or a role that has no widget and no domain defined.
5. Send the report back with: module, role tested, employee file id, Odoo groups, expected domain, actual records returned, and leak or gap.

---

## 1. Where access comes from

Login: `POST /api/login/new`.

The app reads the employee from the session. The phone must not send `employee_id` or a domain. If any mobile route accepts a client-supplied domain or another employee’s id and returns that person’s records, that is a leak.

| Login field | Odoo source to confirm | What the app does with it |
|---|---|---|
| `is_management`, `role_capabilities.x_is_management` | Management role line | Company-wide projects, clients/vendors fallback, drawing studio, company documents |
| `is_hr_manager`, `role_capabilities.x_is_hr_manager` | HR Manager role line | HR manager hub, timesheet company scope, company documents |
| `is_pm`, `role_capabilities.x_is_pm` / `x_is_pm_role` | Project Manager role line | Manager view, timesheet review, company documents, project media |
| `is_foreman`, `role_capabilities.x_is_foreman` | Foreman role line | Timesheet submit for labors |
| `is_fleet` | Fleet role line | HR Requests: treated as employee unless another flag is also true |
| `is_attendance_manager` | Attendance manager group | Attendance team scope — confirm against `user_type` on `/api/attendance/list` |
| `hr_module_manager` | Per-module manager map | `payslip`, `attendance`, `hr_request`, `recruitment`, `evaluation` |
| `role_capabilities` | OR of boolean fields on the user’s role lines | Raw flags. Explicit employee booleans win over the map where both exist |
| `x_labor_ids` | `hr.employee` labors of this foreman | Timesheet team the foreman may capture |
| `x_foreman_ids` | Foremen under this PM | Timesheet team the PM may review |
| `default_widgets.*.is_disabled` | Effective Widgets | Home card on or off. See section 4 |
| `can_see_project_media` | True when the user's role lines have `x_is_management`, `x_is_pm`, or `x_is_media_role` (added 28 Sep) | Media "Projects" favourites. See section 3.9 |
| Global project access | Management role **or** `res.groups` id **632** (`ProjectFilterService.FULL_PROJECT_ACCESS_GROUP_ID`) | Sees every non-internal project in portfolio, client bars, group-by, and project documents. Confirm who is in group 632 |
| Purchase flags | See Purchase module | Tabs and record scope |

**Effective Widgets rule (already agreed):** custom employee override if set, otherwise the role template. There is no management bypass. Removing a widget from the role template must hide it after re-login or after `POST /api/widgets/config`.

---

## 2. Check these first — likely leaks

These are already visible in the app. Confirm each one on the API, not only on the screen.

| # | Risk | What to verify in Odoo |
|---|---|---|
| 1 | If a widget key is missing from login, the home screen shows the card. | Every live role template must set `is_disabled` true or false for every widget key in section 4. A blank key is not “hidden”. |
| 2 | If `hr_module_manager` is missing from login, a line manager (`is_management` or `is_pm`) is treated as manager of **every** HR submodule (payslip, attendance, requests, recruitment, evaluation). | The login payload must always send `hr_module_manager`. Each flag must match the Odoo group for that submodule only. |
| 3 | A user with no HR, PM, or Foreman flag is treated as a **foreman** and the app offers timesheet submit. | `/api/timesheet/submit` must reject anyone who is not a real foreman. Defaulting the UI to foreman is not enough. |
| 4 | A PM or HR user can open the app “as” one of their foremen (read only). Submit from that session must stay blocked. | `/api/timesheet/submit` must record the real user and refuse an impersonated submit. |
| 5 | Projects v1 and v2 now share one domain (aligned 17 Jul, confirmed 23 Sep): non-global users need `staff_list_ids.employee_id = employee` **and** `access = 'project'`. Global users (management or group 632) see all non-internal projects. Since 23 Sep, `get_projects` with `portfolio=1` returns the **whole** portfolio on the first page (no pagination) so client-bar sheets match bar counts. | Non-global users must not see projects where they are only supervisor, labor, or another staff-list line. Confirm group 632 membership is intended. Confirm the unpaginated portfolio response is acceptable for global users. |
| 6 | Purchase Manager in the written spec can see Invoice Receiving. The app shows that tab only for Document Controller, or for a Purchase Officer who is not a manager. | Decide the Odoo rule, then make the API `available_tabs` match it. Do not leave both behaviors. |
| 7 | Clients and Vendors show company figures. If the widget keys are missing, only management sees the section. If the keys exist, `is_disabled` decides. | `/api` client and vendor routes must return `is_authorized: false` and empty figures for anyone outside the intended group, even if the card is visible. |
| 8 | Company Documents opens for HR Manager **or** Management **or** Project Manager. Media “Projects” is gated by `can_see_project_media` (management, PM, or `x_is_media_role`). `/api/media_attachments` then returns **all** favourite project attachments company-wide, not only the user's projects. | A PM must not receive another PM’s project files. Today any PM or media-role user gets every favourite project video. Decide whether that is intended. |
| 9 | Drawing Studio is not a widget flag. It shows for management when Cognito email and pool ids are on the login payload. | Confirm only the intended management users have `x_cognito_email` set. |
| 10 | Face embeddings download is scoped to the foreman’s team in the design. | `POST /api/face_db/embeddings` must not return embeddings for employees outside `staff_list_ids` / `x_labor_ids` for that project. |
| 11 | Petty cash and purchase overview are financial. | Unauthorized users get `is_authorized: false` and no amounts. Each overview fetch should write an access log (employee, time, scope). |

---

## 3. Module access — what the API must enforce

Compare each row with the Odoo access right and the record-rule domain for the same user.

### 3.1 Human Resource

Roles come from login flags. When `hr_module_manager` is present, it decides **whether** the user is a manager of that submodule. Inside that, HR Manager is the wide tier; Management or PM is the team tier; everyone else is employee (own records only).

| Submodule | Employee domain | Manager domain | HR Manager domain | API the app calls |
|---|---|---|---|---|
| HR Requests | Own requests only | Management: direct reports / department. PM: team on their projects. Fleet alone: own only | All departments | `/api/my_requests`, `/api/submit_request`, `/api/hr/team_requests/search`, `/api/get_hr_request_details` |
| Attendance | Own check-in history | Team, from API `user_type` on `/api/attendance/list` — not from a phone-side filter | Company, only if `hr_module_manager.attendance` or attendance-manager group says so | `/api/attendance/today_status`, `/api/attendance/detail`, `/api/attendance/list`, `/api/attendance/records` |
| Attendance widget | Own month: present days, working days, week dots | Same personal card. Team totals are not this card | Same | `POST /api/widgets/attendance/data` |
| HRMS widget | Not company-wide. Live API uses **direct reports** (`hr.employee.parent_id = login employee`). Headline is that count | Same rule: only people who report to this employee | Confirm whether HR Manager should see company totals. The live widget service does **not** use department or company; it uses `parent_id` only | `POST /api/widgets/hrms/data` |
| Payslips | Own payslips | Only if `hr_module_manager.payslip` is true | Only if that flag or HR Manager group allows it | `/api/payslip/list`, `/api/payslip/detail` |
| Recruitment | No access | Only if `hr_module_manager.recruitment` is true. Scope: own requisitions / assigned interviews — confirm in Odoo | All requisitions in the HR Manager group | `/api` recruitment routes used by the HR hub |
| Performance evaluation | Own evaluation | Team evaluations only if `hr_module_manager.evaluation` is true | All evaluations in scope | `/api/performance/my_evaluation`, `/api/performance/evaluations`, `/api/performance/employees` |
| Employee directory | Own card | Direct reports and the fields on `GET /api/employee/listx` (`parent_id`, department, section, job) | Confirm company directory vs direct reports. `listx` must not list the whole company for a normal employee | `/api/employee/list`, `/api/employee/listx` |

**Analyst check:** open payslip, recruitment, and evaluation as a PM who is **not** flagged on `hr_module_manager`. The app should stay on the employee view, and the API should refuse team records.

### 3.2 Timesheet and Site Management

| Role | What they may see | What they may write | Domain |
|---|---|---|---|
| Foreman | Own site, own labors | Submit timesheet for `x_labor_ids` | Project staff list + foreman labor list. Not the whole company |
| Project Manager | Foremen in `x_foreman_ids`, their projects | Review only. No submit while “acting as foreman” | Projects where the employee is PM on staff list (`access = 'project'`) |
| HR Manager | Company timesheet scope (`hrWideScope`) | Review. Submit only if they are also a real foreman and not in an acting session | Confirm this is intentional. If Odoo HR cannot see all analytic lines, the API must not either |
| Site engineer / supervisor | Assigned sites only | As designed for that role | `supervisor_ids` / staff lines on `/api/timesheet/site_projects` |
| Everyone else | Own hours only | No team submit | `account.analytic.line` where the employee is themselves |

| API | Domain to confirm |
|---|---|
| `POST /api/timesheet/submit` | Caller is the foreman; `employee_ids` are in `x_labor_ids` for that project; date and geofence belong to that project |
| `POST /api/timesheet/my_hr_scope` | Returns only this user’s `x_labor_ids` / `x_foreman_ids` |
| `POST /api/timesheet/project_staff` | `staff_list_ids` + supervisors for one project the user can already see |
| `POST /api/timesheet/site_projects` | Supervisor or staff line, filtered by role and status |
| `POST /api/timesheet/labor_list` | Labors and drivers for a project in scope, not the full employee master |
| `POST /api/project/timesheets/list` | Analytic lines for that `project_id` only if the user is on the project. **Today it has no token and no project check — see section 0** |
| `POST /api/tasks/list` | Tasks for projects in the user’s staff list |
| `POST /api/face_db/embeddings` | Employees in the project staff list or the foreman’s labor list |
| `POST /api/register_face_images` | Only employees the caller is allowed to enrol |

### 3.3 Projects

Elrace does **not** use `project.user_id` as “my projects”.

| User | Domain the API must apply |
|---|---|
| Not global | `staff_list_ids.employee_id = employee` **and** `staff_list_ids.access = 'project'` on portfolio, client bars, group hub, and drill-down (v1 and v2) |
| Global (management or group 632) | No staff-list restriction. Internal / general projects (`x_internal_project`) always excluded |
| Home widget (`scope='widget'`) | Non-global: same staff-list rule **plus** `project_status_compute = in_progress` and active |

PM buckets use the **employee id** on the staff list (`access = 'project'`), not `res.users` id.

| API | Notes |
|---|---|
| `GET /api/get_projects` | Without `portfolio`: widget domain (in-progress). With `portfolio=1`: portfolio domain, full list on first page (since 23 Sep) |
| `GET /api/v2/get_projects/` | Portfolio by default. First page returns the full list (since 23 Sep). Rows include `partner_name` |
| `POST /api/v2/clients/list` | Group by agreement, client, project manager, or city. Filter projects **before** counting |
| `POST /api/v2/get_partner_projects` | Drill-down. Same domain and same hub filters |
| `POST /api/project/expense/summary` | Only projects already in the user’s domain |
| Project documents / attachments | Same project domain. Opening by attachment id must not bypass it |

The app does not send a domain. If a route trusts a `domain` parameter from the phone, remove that parameter.

### 3.4 Clients and Vendors

Intended audience: management (and any role you explicitly enable on the widget). Figures are company receivables, payables, LPO, and retention.

| API behaviour required | Check |
|---|---|
| `is_authorized: false` and empty amounts when the employee is outside the role | A site engineer with the card forced on must still get an empty authorized response |
| No client id from the phone can switch the portfolio to another company | Partner lists stay inside the user’s companies |
| Sub-contractors are not a separate card | They are included in Vendors. Do not configure a live Sub-Contractors card |

### 3.5 Purchase (MR, RFQ / LPO, Invoice Receiving)

Read-only. Approve and reject stay in Email Approval (`/api/record/tier_review`), not in this module.

Role source: role-line booleans, or explicit fields on the employee. The explicit field wins.

| Role | MR | RFQ / PO | Invoice Receiving | Record domain |
|---|---|---|---|---|
| Purchase Officer `x_purchase_officer` / `is_purchase_rep` | Own | Own | Own receiving only, and only when they are not also a manager | Employee is purchase rep or requested-by |
| Purchase Manager `x_purchase_manager_role` | Department | Department | **Conflict — see leak #6** | Department, or company if Odoo says company |
| Management / cost control `x_is_management` | All | All | All | Company-wide. `purchase_scope = all` |
| Document Controller `x_is_dc_role` | No | Read context only | Own assignments | Invoices where doc controller is this employee |
| None of the above | No | No | No | `is_authorized: false`, `available_tabs: []` |

`purchase_scope` must be one of: `own`, `department`, `all`, `receiving`, `none`.

| API | Must apply the scope above |
|---|---|
| `POST /api/widgets/lpo/data` | Current-month `purchase.order` totals. No amounts if unauthorized |
| `POST /api/purchase/overview` | Same scope. Write `purchase.mobile.access.log` |
| `POST /api/purchase/requisitions` and `requisition_details` | `purchase.requisition` in scope. Detail by id must re-check the domain |
| `POST /api/purchase/rfqs` and existing `get_rfq_details` | `purchase.order` in scope |
| `POST /api/purchase/invoice_receiving` and `invoice_receiving_details` | `account.move` vendor bills in scope. Base64 file content is sensitive — same domain |

**Detail-by-id test:** take an MR id that belongs to another purchase officer and call `requisition_details` with the first officer’s token. The API must refuse it. Same test for RFQ id and invoice id.

### 3.6 Petty cash

| Role (widget plan) | Domain |
|---|---|
| Site engineer / supervisor | Own allocation and own expenses |
| Project manager | Own allocation, or the project allocation if Odoo stores petty cash per project — confirm which |
| Finance / general manager | Own allocation on the card. Company total only if the Odoo group already has it |
| Anyone else | `is_authorized: false`, no amounts |

| API | Check |
|---|---|
| `POST /api/petty_cash_home` | Scope above |
| `POST /api/expense/lines`, `/api/draft_summary`, `/api/submit_expense` | Only this employee’s sheet, unless the user is the approver in Odoo |
| `POST /api/view_all_hr_expense_sheets` | Must not mean “all company sheets” for a normal employee |
| `POST /api/get_petty_cash_details` | Detail id in the user’s domain |
| Widget data | Access log: employee, time, scope, value shown |

### 3.7 Approvals

Approvals are not a home widget. They follow Odoo approval / tier-review groups.

| API | Domain |
|---|---|
| `POST /api/my_approvals_grouped` | Only documents waiting on **this** user |
| `POST /api/my_delayed_approvals/*` | Same user |
| `POST /api/get_hr_request_details`, `get_invoice_details`, `get_petty_cash_details` | Record is in this user’s approval inbox, or the user already has module access to it |
| `POST /api/record/tier_review` | User is the current reviewer. No approve-on-behalf unless Odoo already allows it |

### 3.8 Productivity

Personal scope. No cross-employee totals.

| Widget / module | Domain | API |
|---|---|---|
| Tasks | `project.task` where the current user is the assignee. On Odoo 14 this is `project.task.user_id` (single user); the fix on 28 Sep stopped using `user_ids`, which does not exist on Odoo 14 | Task list / widget data |
| Notes | This employee’s notes only | Notes widget + My Notes |
| Tickets | Tickets assigned to or opened by this employee | Tickets widget |
| Shared documents | Documents shared **to** this employee, not the company library | Shared Documents widget |

### 3.9 Documents, media, stamps

| Area | Domain |
|---|---|
| My Documents | Attachments and ID documents on this `hr.employee` only |
| Media | Intended: this employee’s own media plus media on projects in their staff list. **Actual (`/api/media_attachments`, 28 Sep):** everyone gets all `is_media` attachments that are not favourite project files. Users with `can_see_project_media` also get every favourite project attachment company-wide. There is no staff-list filter. Report this as a gap if per-project scope is required |
| Company Documents | HR Manager, Management, or PM — and only files those Odoo groups can read |
| My Stamps | `POST /api/users/my_stamps` only when `res.users.x_stamp_user` is true. Signature binaries stay on that user |
| Prayer times | No Odoo records. All employees. No access check beyond login |

### 3.10 Projects reports and site reports

| Area | Domain |
|---|---|
| My Reports widget | Metric depends on role (PM financial, engineer task rate, HR workforce, employee personal). The phone does not choose the metric |
| Site reports | `POST /api/site_reports/list`, `create`, `upload_site_report`, `get_folder_report_list` — folders and reports for projects in the user’s staff list |

---

## 4. Home widgets — configure before go-live

This is a separate task from record rules. Do it in Odoo **Effective Widgets** (`emp_mobile_conf`): one row per widget, `role_ids` for the role template, and an employee override only when one person must differ from their role.

The app reads `default_widgets.<key>.is_disabled` from login and from `POST /api/widgets/config`.

- `is_disabled = false` → card is shown.
- `is_disabled = true` → card is hidden.
- Key absent → card is shown. Do not leave keys blank.

After you change a template, the user must re-login or pull to refresh. Refresh calls `/api/widgets/config` and applies the new flags without a new app build.

`is_hub` stays false for these mobile cards.

### 4.1 Widget keys the app actually reads

Configure these keys. The name in Odoo must match the key, including `taskmanagement_widget` (no extra underscore).

| Home section | Widget | JSON key | Who should have it on | Who should have it off |
|---|---|---|---|---|
| Human Resource | Attendance | `attendance_widget` | All employees | Nobody, unless a role must not see attendance |
| Human Resource | HRMS | `hrms_widget` | Employees who have direct reports, HR, managers | Employees with no team, unless you still want the card |
| Human Resource | Timesheet | `timesheet_widget` | Foremen, supervisors, PMs, HR | Office staff with no timesheet duty |
| Projects | My Projects | `my_projects_widget` | Anyone on a project staff list with access Project, and management | Users with no project assignment |
| Projects | Site Management | `site_management_widget` | Site engineers, supervisors, foremen, PMs | Pure office roles |
| Projects | My Reports | `my_reports_widget` | Roles that have a real KPI. Data inside the card is still scoped | Roles with no report |
| Clients & Vendors | Clients | `clients_widget` | Management, and finance only if Odoo already allows the figures | Everyone else |
| Clients & Vendors | Vendors (includes sub-contractors) | `vendors_widget` | Same as Clients | Everyone else |
| Clients & Vendors | Sub-contractors | `sub_contractors_widget` | Leave disabled. The app never shows this card. It only uses the key if `vendors_widget` is missing on an old login | All roles |
| Purchase | Purchase / LPO | `lpo_widget` | Purchase officer, purchase manager, document controller, management | Everyone else |
| Productivity | Task Management | `taskmanagement_widget` | All employees who receive tasks | Roles with no tasks, if you want a cleaner home |
| Productivity | Notes | `my_notes_widget` | All employees | Optional |
| Productivity | Tickets | `tickets_widget` | All employees who can open tickets | Optional |
| Productivity | Shared Documents | `shared_documents_widget` | Employees who receive shared files | Optional |
| Finance | Petty Cash | `petty_cash_widget` | Employees with an allocation, PMs, finance | Employees with no petty cash |
| Library | My Documents | `my_documents_widget` | All employees | Nobody |
| Library | Media | `media_widget` | Employees on projects, management, and media team (`x_is_media_role`) | Users with no project media |
| Not a home card | Check-in | `checkin_widget` | Legacy key. Confirm it is not required for the v7 home | — |
| Not a home card | My Request | `my_request_widget` | Legacy / HR entry. Align with who may open HR Requests | — |
| Not in the widget map | Prayer times | `prayer_times_widget` | All employees if the card is still shipped | — |
| Not a widget flag | Drawing Studio | Cognito fields on the user, and management role | Named management users only | Everyone else |

### 4.2 Suggested role template (starting point — adjust to Odoo groups)

Use this as the configuration sheet. Mark each cell On or Off, then match it in Effective Widgets.

| Widget | Employee | Foreman | Supervisor / site engineer | Project Manager | HR Manager | Purchase Officer | Purchase Manager | Document Controller | Management |
|---|---|---|---|---|---|---|---|---|---|
| Attendance | On | On | On | On | On | On | On | On | On |
| HRMS | Off unless they have direct reports | Off unless they have direct reports | Off unless they have direct reports | On | On | Off | Off | Off | On |
| Timesheet | Off | On | On | On | On | Off | Off | Off | On |
| My Projects | On if on a project | On | On | On | Off unless they are on a project | Off | Off | Off | On |
| Site Management | Off | On | On | On | Off | Off | Off | Off | On |
| My Reports | On if they have a personal KPI | On | On | On | On | Off | Off | Off | On |
| Clients | Off | Off | Off | Off | Off | Off | Off | Off | On |
| Vendors | Off | Off | Off | Off | Off | Off | Off | Off | On |
| LPO / Purchase | Off | Off | Off | Off | Off | On | On | On | On |
| Tasks | On | On | On | On | On | On | On | On | On |
| Notes | On | On | On | On | On | On | On | On | On |
| Tickets | On | On | On | On | On | On | On | On | On |
| Shared Documents | On | On | On | On | On | On | On | On | On |
| Petty Cash | On only if an allocation exists | On | On | On | Off unless they hold cash | Off | Off | Off | On |
| My Documents | On | On | On | On | On | On | On | On | On |
| Media | On if on a project | On | On | On | Off | Off | Off | Off | On |

Employee-level override: use it when one person must differ from the role (for example a foreman who is also a purchase officer). Do not copy the whole template onto every employee. An override replaces the role template for that widget.

### 4.3 What “configured” means before go-live

For every production role:

1. Role template exists and every key in section 4.1 is present.
2. `is_disabled` is explicitly true or false. No blanks.
3. At least one test employee per role has logged in. Home cards match the template.
4. One employee with an override has logged in. The override wins over the role.
5. Pull to refresh after you change the template. The card appears or disappears without reinstalling the app.
6. A user whose card is off calls the widget URL anyway (Postman, their own token). Financial and client/vendor routes return `is_authorized: false` and no figures. Other routes return only that user’s own domain.

---

## 5. Report to send back

Please return one row per test:

| Module | Role | Employee | Odoo groups | Expected domain | API | Records returned that Odoo would hide | Records Odoo shows that the API hides | Widget on/off correct? | Leak / gap / OK |
|---|---|---|---|---|---|---|---|---|---|

Priority order if time is short:

0. Section 0: call each route with no token. Any data returned, or any timesheet created, changed, or deleted, is critical.
1. Purchase detail-by-id (other people’s MR, RFQ, invoice).
2. Projects v1 vs v2 staff-list access.
3. HR submodule flags (`hr_module_manager`) for payslip, recruitment, evaluation.
4. Timesheet submit as a normal employee, and as a PM acting as a foreman.
5. Clients, vendors, and petty cash amounts for a non-finance user.
6. Face embeddings outside the foreman’s team.
7. Home widget template for each role, including a blank-key check.

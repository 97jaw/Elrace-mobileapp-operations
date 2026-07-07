# Site Management — three-phase plan (mobile + Odoo)

## Phase 1 — Roles, project scope, Maintenance task, foreman date flow *(mobile complete)*

**Goal:** Match legacy task-sheet navigation with live APIs and correct project lists per role.

| Area | Mobile | Backend (Odoo) |
|------|--------|----------------|
| Roles | `is_foreman` / `is_pm` + `role_capabilities.x_is_foreman` / `x_is_pm` | Ensure login `/api/login/new` returns flags |
| Foreman projects | Filter `get_projects` where login `employee_id` ∈ `supervisors[]` | Expose `supervisors` on project payload (already on `get_projects`) |
| PM projects | Filter where login employee ∈ `staff_line_ids` with `access = project` | Add `staff_line_ids: [{employee_id, access}]` on `get_projects` |
| Default task | Resolve task named **Maintenance** per project for all capture/submit | Create `project.task` **Maintenance** on each site project |
| Foreman UX | Project list → date calendar (`count/timesheets/by/days`) → day hub (attendance / submit / shift list) | Existing `timesheet/submit`, `task/timesheets/list`, `count/timesheets/by/days` |

**App entry (foreman):** **Timesheet** card → project → **Dates** → day → **Add timesheet / attendance**. **Site Management** card → project detail → reports, teams, photos, live, enroll.

---

## Dual home cards (Timesheet + Site Management)

| Home card | Route | FM lands on | PM lands on |
|-----------|-------|-------------|-------------|
| **Timesheet** | `/timesheet` | `Fm1ForemanDashboard` → calendar capture | `PmTimesheetHomeScreen` → submissions review |
| **Site Management** | `/site-management` | `FmSiteManagementHomeScreen` → `Fm2ProjectDetail` | `Pm1Dashboard` (site mode) → `Pm2ProjectDetail` |

Widget APIs: `/api/widgets/timesheet/data` (hours/records) and `/api/widgets/site_management/data` (active sites).

---

## Phase 1b — Add request + camera merge *(mobile complete)*

Single hub per day (`FmAddRequestHubScreen`): **Take attendance** (camera AT1–AT4, unchanged) or **Add a new request** (`EmployeeShiftRequestPage`, legacy form). Opened from day hub — matches old `EmptyShiftPage` + button.

Legacy reference (no screenshots needed): home `time_sheet` widget → `TaskSheetPage` → `TaskDetailsPage` (dates) → `EmptyShiftPage` (day) → add request.

---

## Phase 2 — PM review only · foreman labors only *(in progress)*

**Rules**

| Role | Can submit timesheet / camera? | Sees |
|------|-------------------------------|------|
| **Foreman** | Yes — for **`x_labor_ids`** on their `hr.employee` only | Their projects (supervisors list) |
| **PM** | **No** | Timesheet **reports** for labors under their **`x_foreman_ids`** on assigned projects |

**Odoo fields (login + `/employee/list`):**

- `x_labor_ids` on foreman employee → labors they manage  
- `x_foreman_ids` on PM employee → foremen they oversee  

**Mobile:** `TimesheetHrEmployeeScope`, `PmTimesheetSubmissionsScreen`, PM dashboard copy, capture blocked for PM.

| Area | Mobile | Backend |
|------|--------|---------|
| HR mapping | Parse `x_labor_ids` / `x_foreman_ids` on login + roster | Expose on `/api/login/new` and `employee/list` |
| Foreman workers | Filter pickers / capture to labor ids | Maintain M2M on `hr.employee` |
| PM reports | `PmTimesheetSubmissionsScreen` (read-only) | Same `task/timesheets/list` filtered server-side when possible |
| Later | Geofence, sync, enrol | Phase 2b |

---

## Phase 3 — Site Reports (link existing My Reports module)

**Existing app (do not rebuild):**

| Piece | Location | API |
|-------|----------|-----|
| Home widget | `my_report` → `UserReportsScreen` | — |
| Project folders | `ReportProvider.fetchAllFolders()` | `POST /reports/list` (`emp_id`, `company_id`) |
| Reports in folder | `fetchAllReports(folderID)` | `POST /api/get_folder_report_list` |
| Upload / create | `upload_site_report` | `POST /api/upload_site_report` |
| PDF / items | `ReportProvider` + Hive cache | various |

**Site Management integration:**

1. **Site Management → Site Reports** opens themed wrapper around existing report flows.
2. Pass **`project_id`** (Odoo project / folder mapping) when listing folders and creating reports so PM/foreman only see that project’s reports.
3. Map `FolderModel.id` ↔ ERP project (confirm with backend: folder = project or add `project_id` on folder row).
4. Re-skin listing/forms with `TimesheetModule*` tokens (maroon/navy).

**Backend ask:** Confirm folder↔project linkage; add `project_id` filter on `reports/list` and `get_folder_report_list` if missing.

---

## Current phase

**Proceeding with Phase 1** on mobile; backend columns for `staff_line_ids` can land in parallel on `get_projects`.

# Module 6 — Foreman API mapping (existing vs new)

## Core rule

**Site attendance = `POST /api/timesheet/submit`.**

There is no separate mobile “attendance submit” in production today. The HR **Task Sheet** flow (`EmployeeShiftRequestPage`, `add_task_sheet.dart`) and the FM **Take Attendance** flow (`AT1` → `AT2` → `AT4`) must send the **same** `jsonrpc.params` object. Face match, geofence flags, and audit photos are **extra** (local queue + future `POST /api/timesheet/attendance` from Cloud Functions only).

---

## 1. Write path — `POST /api/timesheet/submit`

| Param | Type | HR task sheet | FM capture (AT1–AT4) | Notes |
|-------|------|---------------|----------------------|-------|
| `project_id` | int / string | `widget.project_id` | `TimesheetCaptureArgs.projectId` | FM nav from FM1/FM2/FM3 |
| `task_id` | int / string | `widget.taskId` | `TimesheetCaptureArgs.taskId` | Required before camera |
| `name` | string | Employee name(s) | Matched / target worker name | Group mode: comma-separated names (HR pattern) |
| `break_time` | int (hours) | Break duration picker | **Default `0`** | Optional FM v2: break chip on AT4 |
| `leave_type_id` | int \| `false` | Leave type dropdown | **Default `false`** | Site capture is not leave |
| `employee_ids` | int[] | Odoo employee id(s) | `Worker.odooEmployeeId` | From task roster or face match |
| `date` | `yyyy-MM-dd` | Selected calendar day | Capture local date | |
| `date_time` | `yyyy-MM-dd HH:mm:ss` | Shift **start** | **Check-in:** now · **Check-out:** now − 8h | Mirrors HR “start − 9h” pattern |
| `date_time_end` | `yyyy-MM-dd HH:mm:ss` | Shift **end** (now) | Capture timestamp | |

**Response (existing):**

```json
{ "result": { "success": true, "message": "..." } }
```

**App code:** `TimesheetSubmitRequest` → `TimesheetApiClient.submitTimesheet()` (`lib/core/timesheet/network/timesheet_api_client.dart`).

**Auth:** Bearer token (`SharedPref.getLoginData().result?.token`) — wire when `useMockSubmit: false`.

---

## 2. Read paths — reuse existing Odoo APIs first

| Existing endpoint | Used in app today | FM screen / data | Module 6 plan |
|-------------------|-------------------|------------------|---------------|
| `POST /api/tasks/list` | `task_sheet_screen.dart` | FM1 tasks, **Tasks hub** | **Phase A:** map response → `Task` model; filter by project |
| `GET /api/get_projects` | Home, swipe, projects | FM1/FM2 project list | **Phase A:** until `GET /api/timesheet/projects` ships |
| `POST /api/task/timesheets/list` | `EmptyShiftPage` | FM3 “who has timesheet today” | **Phase A:** `task_id` + `from_date`/`to_date` = today |
| `POST /api/count/timesheets/by/days` | `TaskDetailsPage` | Optional FM2 analytics | Phase B |
| `POST /api/employee/list` | Timesheet report picker | **All labors + drivers** (minimal `{id,name}`) | Prefer `POST /api/timesheet/labor_list` (full cards) |
| `GET /api/employee/listx` | `TeamMembersApiService` | IT / **non-labor** directory | **Do not use** for FM labor report |
| `POST /api/timesheet/labor_list` | `fetchLaborEmployeesForReport()` | Report employee picker | `project_id?`, `include_drivers?` |
| `POST /api/validate_user_location` | Swipe / check-in | AT2 geofence preview | **Phase A:** `project_id`, lat, lon |

---

## 3. New Module 6 APIs (develop on Odoo / Firebase)

| Endpoint | Caller | Purpose |
|----------|--------|---------|
| `GET /api/timesheet/projects?role=foreman` | Mobile | Projects + assignment; can wrap `get_projects` + foreman filter |
| `GET /api/timesheet/projects/{id}` | Mobile | Detail + **geofence** fields |
| `GET /api/timesheet/projects/{id}/tasks` | Mobile | Tasks for project |
| `GET /api/timesheet/tasks/{id}` | Mobile | Task + **assigned workers** with `odoo_employee_id` |
| `GET /api/timesheet/attendance?project_id&date` | Mobile (PM/FM read) | Normalized check-in/out for review & FM3 dots |
| `POST /api/timesheet/attendance` | **Cloud Function only** | Audit record after face match (not mobile submit) |
| `POST /api/timesheet/workers` | PM enrol | Create site worker |
| `POST /api/timesheet/reports` | FM site report | Daily report |
| Callable `matchAttendance` | Mobile AT2 | Face match → `worker_id`, similarity, geofence |
| Callable `enrollWorkerFace` | PM enrol | Rekognition enrolment |

---

## 4. FM screen → API matrix

| Screen | Primary APIs | Data shown / action |
|--------|--------------|---------------------|
| **FM1** Dashboard | `get_projects`, `tasks/list`, pending local queue | Projects, task counts, sync badge |
| **FM-PL** Projects list | Same as FM1 | Search/filter |
| **FM2** Project detail | `get_projects` / `timesheet/projects/{id}`, `tasks/list` | Take attendance → AT1 with `project_id` + first task |
| **FM3** Task detail | `task/timesheets/list` (today), `tasks/{id}` workers (new) | X/N today, status dots, per-worker capture |
| **AT1** Mode | — (local prefs) | `event` check-in/out → drives `date_time` / `date_time_end` on submit |
| **AT2** Camera | `validate_user_location` (optional), callable `matchAttendance` (new) | Draft + match; no submit |
| **AT4** Summary | **`timesheet/submit`** per matched row | Confirm attendance = timesheet row |
| **Sync queue** | `timesheet/submit` retry, offline photos/reports | Drain pending captures |
| **PM review** | `timesheet/attendance` GET (new) | Not submit |

---

## 5. Implementation phases

### Phase A — Link existing APIs (implemented in app)

| Client method | Odoo endpoint | Notes |
|---------------|---------------|-------|
| `getProjects()` | `GET /api/get_projects` | Cached 2 min |
| `getProjectTasks()` | `POST /api/tasks/list` | Aggregates rows per `task_id` + `employee_id` |
| `getTask()` | from tasks cache | |
| `getTaskWorkers()` | `tasks/list` + `task/timesheets/list` + `/employee/list(x)` | |
| `getTaskAttendance()` | `POST /api/task/timesheets/list` | FM3 dots; infers check-in/out from hours/duration |
| `getAttendance()` | per-task timesheet list for project | |
| `submitTimesheet()` | `POST /api/timesheet/submit` | Live when logged in; int ids coerced |

Code: `TimesheetApiClient`, `TimesheetOdooTransport`, `TimesheetOdooMappers`.  
Provider defaults: `useMockData: false`, `useMockSubmit: false`, `fallbackToMockOnError: true` (mock only if API fails or no token).

### Phase B — Module 6 Odoo bridge

1. Replace reads with `GET /api/timesheet/projects|tasks|attendance`
2. Add geofence on project detail
3. Cloud Function writes `POST /api/timesheet/attendance` after match (audit only)

### Phase C — Optional FM UI parity with HR task sheet

1. Break time on AT4 → `break_time`
2. Leave type (rare on site) → `leave_type_id`

---

## 6. Code references

| Concern | Location |
|---------|----------|
| Submit payload model | `lib/core/timesheet/models/timesheet_submit_request.dart` |
| Submit client | `lib/core/timesheet/network/timesheet_api_client.dart` |
| Capture → submit orchestration | `lib/core/timesheet/services/timesheet_capture_flow_service.dart` |
| Endpoint constants | `lib/core/timesheet/network/timesheet_odoo_api_catalog.dart` |
| HR reference implementation | `lib/ui/presentation/task_sheet/EmployeeShiftRequestPage.dart` |
| Capture route context | `lib/ui/presentation/timesheet/timesheet_route_args.dart` |

---

## 7. ID types

Existing task sheet uses **integer** `project_id` / `task_id` / `employee_ids`. FM mocks use **string** ids (`p_midtown`, `t_inspection`). **Backend Phase A:** normalize to integers in API client parsers (`tmIntOrNullFromJson`) before submit.

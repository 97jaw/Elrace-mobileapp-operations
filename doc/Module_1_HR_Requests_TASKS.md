# Module 1 — HR Requests | Cursor Task File

> **How to use this file:** Read it top to bottom before touching any code. Then read the companion SRD: `Module_1_HR_Requests_SRD.docx`. Then start at Task F.0 and work top to bottom. Update task status as you go. Never skip ahead.

---

## 0. About This Project

You are extending an **existing Flutter mobile application** for **Pandora Tech LLC**. The app integrates with **Odoo 14 ERP** (HR module). You are NOT building from scratch — the app already has authentication, navigation shell, notifications, and attachment handling.

You are adding **6 HR modules** as widgets accessible from the existing app home. This task file covers **Module 1: HR Requests** only.

### What this module does
Employees submit HR requests (leave types and asset requests). Managers and HR Managers view team requests, see analytics, and export PDF reports. Approval workflow is **Phase 2** — for now, records are read-only on the status side.

### Stack
- **Framework:** Flutter (existing app)
- **Backend:** Odoo 14 ERP via REST APIs
- **State Management:** Riverpod (use this — do not introduce other state libraries)
- **HTTP:** Dio
- **Charts:** fl_chart
- **PDF:** pdf + printing packages
- **Theme:** Light theme only (Phase 1)
- **Language:** English only (Phase 1)
- **Connectivity:** Online only (Phase 1)

---

## 1. Critical Rules (NEVER violate these)

| Rule | Reason |
|------|--------|
| **Read the SRD section before coding** | The SRD is the source of truth. Cursor must reference section numbers in commits and comments. |
| **Never invent fields** | If a field is not in the SRD, it does not exist. Ask before adding. |
| **Never hardcode colors/strings/spacing** | Use the design tokens defined in this file. |
| **Reuse shared widgets** | Check `/lib/core/widgets/` BEFORE creating any new widget. |
| **No `!` (bang) operator** without a justification comment. |
| **Never read raw Odoo state strings** | Always read the normalized `ui_status` field from API responses. |
| **One task = one commit** | Format: `feat(hr-requests): <TASK_ID> <description> — SRD §<section>` |
| **Empty / Loading / Error states are mandatory** on every list, detail, and dashboard screen. |
| **Approval workflow is OUT of scope** | Do not add Approve/Reject buttons. Reserve space per SRD §4.3. |

---

## 2. Roles & View Selection

The login API response contains these booleans. Render the corresponding view:

| Boolean Flag | View | Scope | Need All Roles selection popup for now on click HR Management so we will see respective screens all in one for test temporary then we will make dynamic condtion
|------|------|-------|
| `is_hr_manager` | HR Manager | All requests company-wide |
| `is_management` | Manager | Direct reports / department |
| `is_pm` | Manager | Project team members |
| `is_fleet` | Treated as Employee for this module (Fleet Manager only matters in Module 6) |
| None of the above | Employee | Own requests only |

If multiple flags are true, **`is_hr_manager` takes precedence** (broadest visibility wins).

---

## 3. ⚠️ DEVELOPMENT-ONLY: Role Toggle Requirement

> **READ THIS CAREFULLY — this saves the architect's testing time.**

On the **HR Request widget entry point**, place **two temporary toggle icons**:

- 👤 **User icon** → forces Employee view
- 👨‍💼 **Manager icon** → forces Manager view

**Behavior:**
- These icons appear **always** during development (not conditional on debug flag in Phase 1)
- Tapping an icon overrides the role detected from the login API response
- The override persists for the current session
- Place icons in a visible but non-intrusive location (top-right header, or a small floating overlay)
- Style them as small circular icons with a subtle background

**Final release behavior (later phase):**
- Remove these icons
- Replace with dynamic role detection from the login API booleans
- Add a TODO comment in the code clearly marking this as the removal point:

```dart
// TODO(release): Remove dev role toggle. Replace with dynamic role
// detection from login API booleans (is_hr_manager, is_management, is_pm).
// Reference: Module 1 TASKS.md §3.
```

This toggle is mandatory. Implement it as part of Task **F.4** in the foundation phase below.

---

## 4. Design System (use these tokens — never hardcode)

### 4.1 Colors

Define in `/lib/core/theme/app_colors.dart`:

| Token | Hex | Usage |
|------|-----|-------|
| primary | `#1F3A5F` | Primary buttons, active filter chip, KPI numbers, headers |
| secondary | `#4A6B8A` | Subheaders, secondary text emphasis |
| accent | `#8B2635` | Required-field asterisks, key callouts |
| lightBg | `#F5F8FB` | Card backgrounds, screen background |
| surface | `#FFFFFF` | Card surface, form input background |
| text | `#1A1A1A` | Body text |
| mutedText | `#6B7280` | Field labels, hint text, timestamps |
| border | `#C5CDD6` | Input borders, dividers |
| success | `#2E7D5B` | Approved status |
| warning | `#C77700` | Pending status |
| danger | `#8B2635` | Rejected status |

### 4.2 Status Badge Color Map

Define in `/lib/core/theme/hr_module_status_colors.dart` (HR module badges; see barrel `hr_module_theme.dart`):

| ui_status | Background | Text |
|-----------|-----------|------|
| DRAFT | `#E5E7EB` | `#374151` |
| PENDING | `#FFF4D6` | `#C77700` |
| APPROVED | `#D6F0E2` | `#2E7D5B` |
| REJECTED | `#F5D6DA` | `#8B2635` |

The mobile app reads only `ui_status` from the API. The backend normalizes Odoo state strings to one of these four buckets.

### 4.3 Typography

Define in `/lib/core/theme/app_typography.dart`:

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| pageTitle | 22sp | w600 | Screen header titles |
| sectionHeading | 16sp | w600 | Section dividers (e.g., 'REQUEST DETAILS') |
| cardTitle | 16sp | w600 | Request type names, employee names |
| body | 14sp | w400 | Default text |
| caption | 12sp | w400 | Timestamps, hints |
| counterNumber | 28sp | w700 | KPI counter card large numbers |
| counterLabel | 12sp | w500 | KPI counter card labels |
| button | 14sp | w600 | Buttons |
| statusBadge | 11sp | w700 | Pill badge text (UPPERCASE) |

### 4.4 Spacing & Layout

| Token | Value |
|-------|-------|
| screenPadding | 16dp horizontal |
| cardSpacing | 12dp vertical |
| cardRadius | 8dp |
| cardShadow | 0dp x, 2dp y, 4dp blur, primary @ 8% opacity |
| formFieldSpacing | 16dp vertical |
| labelToInputGap | 4dp |
| buttonHeight | 48dp |
| chipHeight | 32dp |
| tileAspectRatio | 1:1 |

---

## 5. Folder Structure

```
Make professional strucutre without disturbing the exisiting features like professional and expert developer
---

## 6. Module Roadmap

### Build order (do NOT skip ahead)

| Phase | Tasks | Why this order |
|-------|-------|----------------|
| **Foundation (F)** | F.0 → F.7 | All shared infrastructure must exist before any screen |
| **Employee Screens (E)** | E1 → E2 → E3 | Landing first, then create flow, then detail |
| **Forms (F-prefix)** | F2 → F3 → F4 | Asset request forms (referenced from E2) |
| **Manager Screens (M)** | M1 → M2 → M3 → M4 | Landing, dashboard, detail, search |
| **Polish (P)** | P1 → P3 | PDF export, role toggle verification, edge cases |

### Module screens summary (from SRD)

| ID | Screen | SRD Section | Audience |
|----|--------|-------------|----------|
| E1 | HR Request Landing (Employee) | §3.1 | Employee |
| E2 | New Request Picker | §3.2 | Employee |
| E3 | Request Detail (Employee) | §3.3 | Employee |
| F1 | Leave Form | — | Existing — DO NOT REBUILD |
| F2 | SIM Card Request Form | §5.2 | Employee |
| F3 | Car Rent Request Form | §5.3 | Employee |
| F4 | Car Allowance Form | §5.4 | Employee |
| M1 | Manager Landing | §4.1 | Manager / HR Manager |
| M2 | Manager Dashboard | §4.2 | Manager / HR Manager |
| M3 | Request Detail (Manager) | §4.3 | Manager / HR Manager |
| M4 | Search Older Requests | §4.4 | Manager / HR Manager |

### Out of scope reminder
- **Lifecycle requests** (Transfer, Promotion, Termination, Resignation, Increment) — NOT in Phase 1
---

## 7. Functional Knowledge

### 7.1 Request types in scope

**Frequent leave types (visible by default on the picker):**
- Sick Leave
- Short Leave
- Annual Leave
- Job Mission
- Temporary Permission

**Behind 'More' expansion:**
- Work Compensation (leave)
- SIM Card Request (asset) — uses new form F2
- Car Rent Request (asset) — uses new form F3
- Car Allowance (asset) — uses new form F4

### 7.2 Counter logic (Employee landing E1)

| Counter | Logic |
|---------|-------|
| Pending | Count of own requests where ui_status = PENDING |
| Approved | Count where ui_status = APPROVED |
| Rejected | Count where ui_status = REJECTED |
| Draft | Count where ui_status = DRAFT |

### 7.3 Action availability per status (E3 detail screen)

| Status | Cancel | Duplicate | Edit | Export PDF |
|--------|--------|-----------|------|------------|
| DRAFT | ✓ | ✓ | ✓ | ✓ |
| PENDING | ✓ | ✓ | — | ✓ |
| APPROVED | — | ✓ | — | ✓ |
| REJECTED | — | ✓ | — | ✓ |

### 7.4 Manager visibility scope

| Role | What they see in 'Team Requests' tab |
|------|---------------------------------------|
| is_hr_manager | All requests across all departments |
| is_management | Direct reports only (employee.parent_id chain) |
| is_pm | Team members under their projects |

### 7.5 Manager landing default view
- Shows recent records: Pending requests + Approved/Rejected from the last 30 days
- Older records accessible via 'Show More' → opens M4 (Search Older Requests)

### 7.6 PDF watermark spec

Every exported PDF must carry a watermark:

| Property | Value |
|----------|-------|
| Content | `emp_id` from login response (e.g., 'EMP-4471') |
| Color | Light gray `#C5CDD6` |
| Opacity | 20% |
| Font Size | 60pt |
| Rotation | -45° (diagonal) |
| Position | Centered on every page, behind content |

Implement in `/lib/core/utils/pdf_watermark.dart` as a reusable utility.

---

## 8. API Conventions

### 8.1 Standard response shape
All API responses follow this shape:

```json
{
  "success": true,
  "data": { ... },
  "error": null,
  "ui_status": "PENDING"
}
```

### 8.2 Error handling
- 401 → trigger re-login via existing app auth flow
- 4xx → display error message from `response.error`
- 5xx → show generic 'Something went wrong' with retry button

### 8.3 Mock first, integrate later
**For Phase 1 implementation, mock all API responses with realistic dummy data.** The actual API contracts will be finalized AFTER all design/layout work is complete. Mark every API call site with:

```dart
// TODO(backend): Replace mock with actual API call.
// Endpoint TBD. See /docs/srd/module-1-hr-requests.md §7.3.
```

---

## 9. Tasks (work top to bottom)

> **Status legend:** `[TODO]` `[IN_PROGRESS]` `[DONE]` `[BLOCKED]` `[NEEDS_REVIEW]`
>
> Update this section as you complete each task.

---

### Phase 0 — Foundation

#### `[DONE]` F.0 — Verify project setup
- Confirm `pubspec.yaml` has: `flutter_riverpod`, `dio`, `fl_chart`, `pdf`, `printing`, `intl` — **all present** (no `pubspec` edit required).
- Run `flutter pub get` at repo root.
- Run `dart pub get` in `packages/cunning_document_scanner` so analyzer resolves `mockito` for plugin tests (fixes `uri_does_not_exist` on `mockito.dart`).
- **Definition of done:** `flutter analyze` reports **no errors** (legacy infos/warnings remain across the app; full lint-zero is not Module 1 scope).

#### `[DONE]` F.1 — Design tokens (SRD §6.1–6.4) — *inserted; was missing between F.0 and F.2*
- Added `lib/core/theme/hr_module_colors.dart`, `hr_module_status_colors.dart`, `hr_module_typography.dart`, `hr_module_layout.dart`, barrel `hr_module_theme.dart`.
- **Naming:** `HrModule*` avoids clashing with existing `lib/resources/app_colors.dart`.
- **Definition of done:** Tokens available via static getters; HR screens should import `package:el_race/core/theme/hr_module_theme.dart`.

#### `[DONE]` F.2 — Shared widgets (Phase 1)
- Implemented under `lib/core/widgets/hr_management/` with `Hr` prefix to avoid clashing with existing app widgets.
- Barrel: `package:el_race/core/widgets/hr_management/hr_management_widgets.dart`
- **Sandbox:** `HrModuleWidgetsSandbox` — open from **HR Management** menu via **“F.2 widget sandbox”** (`kDebugMode` only).

1. `HrStatusBadge` — `ui_status` pill (SRD §6.4)
2. `HrKpiCounterCard` — square KPI tile, optional `onTap`, optional `valueColor`
3. `HrFilterChipRow` + `HrFilterOption` — horizontal single-select chips
4. `HrSearchBar` — Stateful, 300ms debounced `onDebouncedChanged`
5. `HrDetailRow` — label / value (or `valueWidget`)
6. `HrEmployeeInfoCard` — avatar initials, name, role line, ID, optional email/phone
7. `HrRequestCard` — employee list / team list with compact employee header when `showEmployeeHeader`

- **Definition of done:** All widgets compile, render in sandbox, use `HrModule*` tokens.

#### `[DONE]` F.3 — Networking layer
- `lib/core/hr_management/network/hr_api_envelope.dart`, `hr_api_client.dart` — Dio client, **mock-first** `fetchMyRequests` / `submitAssetRequest` with `// TODO(backend)` markers.

#### `[DONE]` F.4 — Role provider + Dev role toggle ⚠️ CRITICAL
- `lib/core/hr_management/hr_effective_view.dart` + `providers/hr_management_providers.dart` (`hrDevViewOverrideProvider`, `hrEffectiveViewProvider`).
- `HrRoleDevToggleBar` on **HR Management** menu — **`kDebugMode` only** (SRD production note).
- Login `Data` extended with `is_hr_manager`, `is_management`, `is_pm`, `is_fleet` JSON keys.

#### `[DONE]` F.5 — Routing
- `lib/core/hr_management/routing/hr_route_names.dart` + `lib/utils/generated_routes.dart` entries for SIM, car rent, allowance, widget sandbox.

#### `[DONE]` F.6 — Riverpod base providers
- `ProviderScope` in `main.dart` (`show ProviderScope` import avoids clash with `package:provider`).
- `hrDioProvider`, `hrApiClientProvider`, `hrRequestListProvider` (mock list template).

#### `[DONE]` F.7 — PDF watermark utility
- `lib/core/utils/pdf_watermark.dart` — `PdfWatermark.buildSamplePdf`; preview from F.2 sandbox button.

---

### Phase 1 — Employee Screens

#### `[DONE]` E1 — HR Request Landing (Employee)
- **SRD section:** §3.1
- **Wireframe:** §3.1.1
- **Component spec:** §3.1.2
- **Counter logic:** §3.1.3 and §7.2 of this file

**Implementation (this repo):**
- `lib/ui/presentation/hr_management/hr_employee_landing_screen.dart` — E1 UI
- `lib/core/hr_management/models/hr_request_summary.dart` — list model (+ `secondaryLine`, `sequence`, etc.)
- `lib/core/hr_management/hr_mock_requests.dart` — 10 mock rows; `hrRequestListProvider` loads via `HrApiClient` mock
- Detail tap → `hr_employee_request_detail_stub_screen.dart` until E3
- Home / My Requests entry → `HrEmployeeLandingScreen`; **New request** FAB → `HrManagementMenuPage`
- Named route: `HrRouteNames.employeeLanding`

**Steps (original TASKS — superseded by paths above):**
1. Read SRD §3.1 in full
2. Create `/lib/features/hr_requests/presentation/providers/hr_requests_list_provider.dart`:
   - AsyncNotifier returning `List<HrRequest>` (mock data — 8-10 sample records mixing all statuses and types)
   - Supports filter parameter (status filter)
3. Create `/lib/features/hr_requests/data/models/hr_request_model.dart` — model class with fields: `id, referenceNumber, type, typeIcon, fromDate, toDate, daysCount, uiStatus, submittedAt`
4. Create `/lib/features/hr_requests/presentation/screens/employee/e1_landing_screen.dart`:
   - AppBar: title 'HR Requests', overflow menu with 'Refresh'
   - **Place dev role toggle from F.4 in the AppBar actions area** (per §3 of this file)
   - Body: KPI counter row (4 cards: Pending, Approved, Rejected, Draft), search bar, filter chips, sort dropdown, list of `RequestCard` (employee variant)
   - Bottom: '+ New Request' floating action button
   - States: loading (skeletons), empty ('No requests yet' + create button), error (banner with retry)
5. Wire counter cards to be tappable — tapping a card sets the corresponding filter
6. Tapping a request card navigates to E3 with the request ID

**Definition of done:**
- All states render correctly with mock data
- Counter cards are tappable and filter the list
- Filter chips work
- Search debounces correctly
- Dev role toggle is visible and switches views

**Commit:** `feat(hr-requests): E1 employee landing screen — SRD §3.1`

---

#### `[TODO]` E2 — New Request Picker
- **SRD section:** §3.2
- **Wireframe:** §3.2.1
- **Component spec:** §3.2.2
- **Frequent vs More:** §7.1 of this file

**Steps:**
1. Read SRD §3.2 in full
2. Create `request_type_tile.dart` widget — square tile with icon and label, tappable
3. Create `/lib/features/hr_requests/presentation/screens/employee/e2_picker_screen.dart`:
   - AppBar: 'New Request' title
   - Section heading: 'What would you like to request?'
   - **FREQUENT section** (always visible): 5 tiles in 3-column grid — Sick Leave, Short Leave, Annual Leave, Job Mission, Temporary Permission
   - **More divider** (collapsible, default collapsed): 'More request types' with chevron
   - **LEAVE group** (under More): Work Compensation, Leave Encashment
   - **ASSET group** (under More): Car Rent Request, SIM Card Request, Car Allowance
4. Each tile tap navigation:
   - Frequent leave types + Work Compensation + Leave Encashment → existing leave form (F1) — DO NOT rebuild. Use existing form's route.
   - SIM Card Request → F2 form (next task)
   - Car Rent Request → F3 form
   - Car Allowance → F4 form

**Definition of done:**
- Frequent tiles always visible without scrolling
- More section toggles correctly
- Each tile navigates to the correct destination
- Existing leave form is reused (do not rebuild)

**Commit:** `feat(hr-requests): E2 new request picker — SRD §3.2`

---

#### `[TODO]` E3 — Request Detail (Employee)
- **SRD section:** §3.3
- **Wireframe:** §3.3.1
- **Component spec:** §3.3.2
- **Action matrix:** §3.3.3 and §7.3 of this file

**Steps:**
1. Read SRD §3.3 in full
2. Create 
  — AsyncNotifier taking request ID, returning detail
3. Build the detail model with status_history array
4. Create `status_timeline.dart` shared widget if not yet built — vertical step list with filled/hollow circles
5. Create 
   - AppBar: 'Request Detail', export icon (PDF download with watermark)
   - Header card: type icon, name, ref no., status badge, submitted timestamp
   - Request Details section: two-column DetailRow list — fields vary by request type
   - Attachments section (if any): file rows with View action
   - Status Timeline section
   - Comments section: read-only mail.thread display
   - Bottom action buttons per §3.3.3 / §7.3 (Cancel, Duplicate, Edit by status)
6. Implement PDF export using F.7 utility — pass employee's emp_id from login response

**Definition of done:**
- All sections render correctly
- Action buttons appear/hide correctly per status
- PDF export works with watermark
- Cancel and Edit return to E1 with appropriate state

**Commit:** `feat(hr-requests): E3 request detail employee — SRD §3.3`

---

### Phase 2 — Asset Request Forms

#### `[DONE]` F2 — SIM Card Request Form
- **SRD section:** §5.2
- **Field spec:** §5.2.1
- **Wireframe:** §5.2.2

**Fields to implement:**
| Field | Type | Required |
|-------|------|----------|
| Request Reason | Dropdown (New Hire / Replacement Lost / Replacement Damaged / Plan Upgrade / Plan Downgrade / Other) | ✓ |
| Plan Type | Dropdown (Basic / Standard / Premium / Custom) | ✓ |
| Required By Date | Date Picker (no past dates, default +7 days) | ✓ |
| Justification | Multi-line text, 10-500 chars | ✓ |
| Phone Number | UAE format text, conditional required | — |
| Attachment | File picker | — |

**Steps:**
1. Read SRD §5.2 in full
2. Create asset_request_model.dart if not yet built
3. Create 
4. Use `form_field_wrapper.dart` shared widget for consistent field styling
5. Required field validation: client-side first, show inline errors
6. Bottom: Save Draft (secondary) and Submit Request (primary)
7. On submit: mock API call, on success show toast 'Request submitted — Ref: HR/SIM/2026/NNNN' and navigate back to E1

**Definition of done:**
- All fields render and validate correctly
- Conditional required (Phone Number) works
- Save Draft persists and is retrievable from E1's Draft filter
- Submit shows confirmation and returns to landing

**Commit:** `feat(hr-requests): F2 SIM card form — SRD §5.2`

---

#### `[DONE]` F3 — Car Rent Request Form
- **SRD section:** §5.3
- **Field spec:** §5.3.1
- **Wireframe:** §5.3.2

**Fields:**
| Field | Type | Required |
|-------|------|----------|
| Purpose | Dropdown (Business Trip / Client Visit / Site Visit / Airport / Other) | ✓ |
| From Date & Time | DateTime picker, no past, 30-min granularity | ✓ |
| To Date & Time | DateTime picker, must be after From | ✓ |
| Pickup Location | Text, max 150 | ✓ |
| Drop-off Location | Text, max 150 | ✓ |
| Vehicle Type | Dropdown (Sedan / SUV / Van / Pickup / Any) | — |
| Estimated Distance (km) | Numeric, 0-5000 | — |
| Justification | Multi-line, 10-500 | ✓ |
| Attachment | File | — |

**Steps:** Same pattern as F2. Use the same shared widgets and form structure.

**Commit:** `feat(hr-requests): F3 car rent form — SRD §5.3`

---

#### `[DONE]` F4 — Car Allowance Form
- **SRD section:** §5.4
- **Field spec:** §5.4.1
- **Wireframe:** §5.4.2

**Fields:**
| Field | Type | Required |
|-------|------|----------|
| Allowance Type | Dropdown (Monthly Fixed / Per-Trip / Fuel Reimbursement) | ✓ |
| Requested Amount (AED) | Numeric, decimal 2 places | ✓ |
| Effective From | Date picker, no more than 90 days past | ✓ |
| Justification | Multi-line, 20-1000 | ✓ |
| Vehicle Registration | File (Mulkiya) | — |
| Driving License | File | — |

**Steps:** Same pattern as F2. Two attachment fields instead of one.

**Commit:** `feat(hr-requests): F4 car allowance form — SRD §5.4`

---

### Phase 3 — Manager Screens

#### `[TODO]` M1 — Manager Landing
- **SRD section:** §4.1
- **Wireframe:** §4.1.1
- **Component spec:** §4.1.2
- **Visibility scope:** §4.1.3 and §7.4 of this file

**Steps:**
1. Read SRD §4.1 in full
2. Create 
   - AsyncNotifier returning team requests scoped by current role
   - Default scope: Pending requests + Approved/Rejected last 30 days (per §7.5)
3. Create team variant of `RequestCard` if not yet built — includes EmployeeInfoCard at top
4. Create    - AppBar: title 'HR Requests', dev role toggle visible
   - KPI strip: 'Pending My Action', 'Approved This Month', 'This Month Total'
   - View switcher: Dashboard | Requests (default Requests)
   - Tabs: 'Team Requests' | 'My Own Requests' (My Own renders E1)
   - Search bar with extended placeholder
   - Filter chips + Filter dropdown (Department for HR Manager only, Type, Date Range)
   - List of team request cards
   - 'Show More — Search older requests' row at bottom (opens M4)
5. Tap card → navigate to M3

**Definition of done:**
- KPI counts correctly scoped per role
- Tabs switch between team and own
- 'Show More' opens M4
- Department filter visible only for HR Manager

**Commit:** `feat(hr-requests): M1 manager landing — SRD §4.1`

---

#### `[TODO]` M2 — Manager Dashboard
- **SRD section:** §4.2
- **Wireframe:** §4.2.1
- **Component spec:** §4.2.2

**Charts to build:**
1. Donut chart — Requests by Type (top 5 + 'Other')
2. Bar chart — Requests by Month
3. KPI cards — Total, Pending, Avg Approval Time
4. List — Top 5 Requesters
5. Horizontal bar chart — Department Breakdown (HR Manager only)

**Steps:**
1. Read SRD §4.2 in full
2. Use fl_chart package for all charts
3. Create `chart_container.dart` shared widget — wraps a chart with title, period, error/loading states
4. Create 
   - Period selector dropdown (This Week / Month default / Last Month / Quarter / Year / Custom)
   - All charts and KPIs respond to period change
   - Tappable elements: donut slices and dept bars filter the M1 list
   - Export PDF button — dashboard snapshot with emp_id watermark
5. Provide mock data for all charts that varies by period

**Definition of done:**
- All 5 chart components render
- Period selector updates all charts
- Drill-downs (slice tap, dept tap) navigate to M1 with filter applied
- PDF export captures the entire dashboard

**Commit:** `feat(hr-requests): M2 manager dashboard — SRD §4.2`

---

#### `[TODO]` M3 — Request Detail (Manager)
- **SRD section:** §4.3
- **Wireframe:** §4.3.1
- **Component spec:** §4.3.2

**Difference from E3:**
- Add EmployeeInfoCard at the top (avatar, name, position, employee number, email, phone)
- Add 'Available Balance' row to leave-type requests
- Status timeline shows 'To Approve (You)' when pending on the current manager
- Reserve bottom action area for Phase 2 — leave empty in Phase 1
- PDF export uses **manager's** emp_id, not employee's

**Steps:**
1. Read SRD §4.3 in full
2. Reuse `EmployeeInfoCard` from F.2
3. Create 
   - Reuse most of E3's body
   - Prepend EmployeeInfoCard
   - Add Available Balance row when applicable
   - Adjust timeline labels per role
   - Pass manager's emp_id to PDF export

**Commit:** `feat(hr-requests): M3 request detail manager — SRD §4.3`

---

#### `[TODO]` M4 — Search Older Requests
- **SRD section:** §4.4
- **Wireframe:** §4.4.1
- **Component spec:** §4.4.2

**Steps:**
1. Read SRD §4.4 in full
2. Create 
   - AppBar: 'Search Team Requests'
   - Free-text search (submit-triggered, not keystroke-triggered)
   - Filter form vertically stacked: Employee, Department (HR only), Request Type, Status, Date Range (From + To)
   - Apply Filters / Clear All buttons
   - Results count + paginated list (20 per page, infinite scroll)
3. Tap result → opens M3

**Commit:** `feat(hr-requests): M4 search older requests — SRD §4.4`

---

### Phase 4 — Polish & Verification

#### `[TODO]` P1 — Cross-screen verification
- Navigate every flow end-to-end with each role
- Verify dev role toggle works on every screen of the module
- Verify empty/loading/error states on every list and detail
- Verify PDF watermark on E3, M3, and M2

#### `[TODO]` P2 — Component inventory check
- Confirm no duplicate widgets exist (e.g., two different StatusBadge implementations)
- Confirm all shared widgets in `/lib/core/widgets/` are imported via package import, not relative
- Update any drift back to the design system

#### `[TODO]` P3 — Module 1 sign-off
- Run `flutter analyze` — must be clean
- Run all widget tests — must pass
- Take screenshots of every screen in every state for QA review
- Update this TASKS.md with any decisions/deviations in §10 below
- Mark module as ready for stakeholder review

---

## 10. Decisions Log

> Append a one-line entry every time you make a design or architectural decision not covered explicitly in the SRD or this file.

```
[2026-05-10] F.0 — Decision: Document `dart pub get` inside `packages/cunning_document_scanner` as part of setup. Rationale: Root `flutter analyze` failed on missing `mockito` until plugin dev deps were fetched.
[2026-05-10] F.1 — Decision: HR tokens live under `lib/core/theme/hr_module_*.dart` instead of overwriting `lib/resources/app_colors.dart`. Rationale: SRD §6 applies to HR module; global `AppColors` stays unchanged.
[2026-05-10] F.2 — Decision: Shared widgets use `Hr*` names and live in `lib/core/widgets/hr_management/`. Rationale: TASKS `/lib/core/widgets/` + avoid collision with action screens’ asset-based `_StatusBadge`; team `RequestCard` uses a compact header; full `HrEmployeeInfoCard` reserved for detail (SRD §4.3).
[2026-05-10] F.4–F.7 — Decision: `import flutter_riverpod show ProviderScope` in `main.dart` to avoid `Provider` name clash with `package:provider`. Rationale: Minimal change; full Riverpod elsewhere.
[2026-05-10] Forms — Decision: Asset forms live in `lib/ui/presentation/hr_management/`; drafts use `SharedPref` string keys. Rationale: Match existing app layout; E1 draft filter pending.
[2026-05-10] E1 — Decision: Home HR tile opens `HrEmployeeLandingScreen` first; FAB opens `HrManagementMenuPage` as new-request hub until E2 picker exists. Rationale: SRD §3.1 first screen is landing; reuse existing leave/asset entry points.
```

(Initially empty — fill as you go)

---

## 11. Open Items / Questions for Architect

> Add anything that requires the architect (M Jawad / Pandora Tech) to clarify.

(Initially empty — fill as you encounter blockers)

---

## 12. Definition of Module Complete

This module is complete when:
- [ ] All tasks above marked `[DONE]`
- [ ] `flutter analyze` passes with no warnings
- [ ] All shared widgets used consistently (no duplicates)
- [ ] PDF export with watermark works on E3, M3, M2
- [ ] Dev role toggle (F.4) visible and functional on every Module 1 screen
- [ ] All TODO(release) and TODO(backend) comments are in place where needed
- [ ] Screenshots captured for stakeholder review
- [ ] Decisions log §10 reflects all non-trivial choices

— End of Module 1 Task File —

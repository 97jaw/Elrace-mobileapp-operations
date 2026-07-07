**HR MANAGEMENT MOBILE APPLICATION**

**Module 1: HR Requests**

*Software Requirements Specification*

  ----------------------- ----------------------- -----------------------
                                                  

  ----------------------- ----------------------- -----------------------

  -----------------------------------------------------------------------
  **Field**               **Detail**
  ----------------------- -----------------------------------------------
  Project                 HR Management Mobile Application

  Module                  Module 1 --- HR Requests

  Backend                 Odoo 14 ERP (HR module)

  Frontend                Flutter (existing app, widget integration)

  Document Type           Software Requirements Specification (SRD)

  Version                 1.0

  Prepared By             Pandora Tech LLC

  Audience                Mobile Development Team

  Phase                   Phase 1 --- Layout & Design Requirements
  -----------------------------------------------------------------------

**1. Document Overview**

**1.1 Purpose**

This document defines the design and layout requirements for the HR
Requests module within the existing Pandora HR Management mobile
application. It is intended to guide the mobile development team in
implementing the screens, components, role-based views, and visual
specifications required to deliver Phase 1 of the module.

**1.2 Scope**

This module is accessed via the existing \'HR Request\' widget on the
main application home screen. Tapping this widget enters the HR Requests
module described in this document. Two role-based experiences are
required: an Employee experience and a Manager experience. The Manager
experience further covers Line Managers, Project Managers, and HR
Managers based on Boolean role flags from the login API response.

**1.3 Phase 1 Boundaries**

  -----------------------------------------------------------------------
  **Aspect**              **Phase 1 Position**
  ----------------------- -----------------------------------------------
  **In Scope**            Leave-type requests, Asset requests, listing
                          screens, detail screens, dashboards, KPIs,
                          charts, search, filter, PDF export with
                          watermark.

  **Out of Scope**        Document requests (Passport, Certificate,
                          Clearance), Financial requests (Loan),
                          Lifecycle requests (Transfer, Promotion,
                          Termination, Resignation, Increment, Effective
                          Date, Change Salary).

  **Approval Workflow**   Out of scope for Phase 1. Records are displayed
                          read-only with their current Odoo status.
                          Approve / Reject actions deferred to Phase 2.

  **Submit Forms**        Existing leave form is reused as-is. Three new
                          asset request forms designed in this document.

  **Authentication**      Already handled by existing application. Not in
                          scope.

  **Notifications**       Already handled by existing application. Not in
                          scope.

  **Connectivity**        Online only. No offline mode in Phase 1.

  **Language**            English only.

  **Theme**               Light theme, clean visual style aligned with
                          Pandora branding.
  -----------------------------------------------------------------------

**1.4 Roles & View Selection**

Roles are determined from the login API response based on Boolean
fields. The application renders a different landing experience based on
the first matching role flag.

  -----------------------------------------------------------------------
  **Role Flag (from  **View Rendered**     **Visibility Scope**
  login)**                                 
  ------------------ --------------------- ------------------------------
  is_hr_manager =    HR Manager View       All HR requests across all
  true                                     departments. Full filter and
                                           search capabilities. PDF
                                           export available.

  is_management =    Manager View          Requests submitted by direct
  true                                     reports / department members.
                                           Recent pending and approved by
                                           default.

  is_pm = true       Manager View          Requests submitted by team
                                           members under their projects.
                                           Recent pending and approved by
                                           default.

  is_fleet = true    Fleet Manager View    Covered separately in Module 6
                                           (Fleet). For HR Requests,
                                           treated as Employee unless
                                           combined with another flag.

  None of the above  Employee View         Only own requests. Full
                                           personal history visible.
  -----------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **Development Note**                                                  |
|                                                                       |
| During development, the application must support a manual role-toggle |
| control (e.g., a hidden debug switch) that allows the developer to    |
| switch between Employee, Manager, and HR Manager views without        |
| changing the login credentials. This toggle must be removable or      |
| hidden in production builds. Once dynamic role detection from the     |
| login API is finalized, the toggle becomes redundant.                 |
+-----------------------------------------------------------------------+

**2. Request Types in Scope**

The HR Requests module supports two categories of request types in Phase
1: Leave-type requests and Asset requests. Frequently used types are
surfaced as primary tiles on the request creation screen; less frequent
types are placed behind a \'More\' expansion.

**2.1 Leave-type Requests**

  ----------------------------------------------------------------------------
  **Request Type** **Visibility**   **Description**
  ---------------- ---------------- ------------------------------------------
  **Sick Leave**   **Frequent**     Leave taken due to illness. Submitted via
                                    existing leave form.

  **Short Leave**  **Frequent**     Short-duration leave (typically same-day
                                    or partial day). Submitted via existing
                                    leave form.

  **Annual Leave** **Frequent**     Standard paid annual vacation. Submitted
                                    via existing leave form.

  **Job Mission**  **Frequent**     Off-site work assignment. Treated as a
                                    leave-type request in Odoo. Submitted via
                                    existing leave form.

  **Temporary      **Frequent**     Hourly permission to leave the workplace.
  Permission**                      Submitted via existing leave form.

  **Work           Behind \'More\'  Leave granted as compensation for extra
  Compensation**                    work. Less frequent.

  **Leave          Behind \'More\'  Conversion of unused leave balance to
  Encashment**                      monetary equivalent. Less frequent.
  ----------------------------------------------------------------------------

**2.2 Asset Requests**

  ----------------------------------------------------------------------------
  **Request Type** **Visibility**   **Description**
  ---------------- ---------------- ------------------------------------------
  **Car Rent       Behind \'More\'  Request for a rental vehicle for business
  Request**                         use. New form designed in Section 5.

  **SIM Card       Behind \'More\'  Request for a corporate SIM card or plan
  Request**                         change. New form designed in Section 5.

  **Car            Behind \'More\'  Request for monetary allowance in lieu of
  Allowance**                       company vehicle. New form designed in
                                    Section 5.
  ----------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **Form Reuse Strategy**                                               |
|                                                                       |
| All leave-type requests reuse the existing leave form already         |
| implemented in the application. The mobile team should not rebuild    |
| this form. Asset requests require three new forms detailed in Section |
| 5 of this document.                                                   |
+-----------------------------------------------------------------------+

**3. Employee View**

The Employee view is the default experience for users whose login
response contains none of the manager Boolean flags (is_management,
is_hr_manager, is_pm). The employee can view their own request history,
submit new requests, and export individual requests as PDF.

**3.1 Screen E1 --- HR Request Landing (Employee)**

The landing screen is the first screen rendered when an employee taps
the HR Request widget. It surfaces a snapshot of the user\'s request
activity, provides quick access to creating a new request, and lists
recent requests with filtering and search capabilities.

**3.1.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← HR Requests ⋮ │                                                   |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │               |
|                                                                       |
| │ │ Pending │ │ Approved │ │ Rejected │ │ Draft │ │                   |
|                                                                       |
| │ │ 3 │ │ 12 │ │ 1 │ │ 2 │ │                                          |
|                                                                       |
| │ └──────────┘ └──────────┘ └──────────┘ └──────────┘ │               |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 🔍 Search by reference no. or request type │ │                    |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ All \] \[ Pending \] \[ Approved \] \[ Rejected \] \[ Draft \] │ |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Recent Requests Sort: Newest ▼ │                                    |
|                                                                       |
| │ ──────────────────────────────────────────────────── │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 🏖️ Annual Leave \[PENDING\] │ │                                   |
|                                                                       |
| │ │ Ref: HR/LV/2026/0142 │ │                                          |
|                                                                       |
| │ │ 12 May → 16 May (5 days) Submitted 2d ago│ │                      |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 🚗 Car Rent Request \[APPROVED\] │ │                              |
|                                                                       |
| │ │ Ref: HR/CR/2026/0089 │ │                                          |
|                                                                       |
| │ │ 04 May → 04 May (1 day) Submitted 6d ago│ │                       |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ ⏱️ Temporary Permission \[APPROVED\] │ │                          |
|                                                                       |
| │ │ Ref: HR/TP/2026/0233 │ │                                          |
|                                                                       |
| │ │ 02 May, 14:00 → 16:00 Submitted 8d ago│ │                         |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ + New \] │                                                       |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**3.1.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Header**       Back arrow returns to main app home. Title text \'HR
                   Requests\'. Overflow menu (⋮) reserved for future
                   actions (currently can hold \'Refresh\' only).

  **KPI Counter    Four cards in a single horizontal row. Each card shows
  Cards**          a numeric counter and a status label. Cards are
                   tappable --- tapping a card applies the corresponding
                   status filter to the list below. Counts represent the
                   user\'s own requests only. Card heights are equal. On
                   smaller screens, the row remains horizontally
                   scrollable.

  **Search Bar**   Full-width search input with magnifying glass icon.
                   Placeholder: \'Search by reference no. or request
                   type\'. Search is performed against reference number
                   and request type name. Triggers as the user types
                   (debounced 300ms).

  **Filter Chips** Horizontal scrollable row of status chips. Selected
                   chip uses primary color fill with white text;
                   unselected chips use light fill with primary color
                   text. Default selection: \'All\'. Tapping a counter
                   card auto-selects the corresponding chip.

  **Section        \'Recent Requests\' label on the left, sort dropdown
  Header**         on the right. Sort options: Newest, Oldest, By Status,
                   By Type.

  **Request Card** Each card shows: request type icon (left), request
                   type name (bold), status badge (top-right), reference
                   number, key date or duration line, submission relative
                   timestamp. Cards have light shadow, rounded corners
                   (8px), white background. Tapping the card opens the
                   Request Detail screen (E3).

  **Status Badge** Pill-shaped badge inside each request card. Color
                   mapping defined in Section 6.4.

  **+ New Button** Floating action button (FAB) anchored bottom-right or
                   full-width primary button at the bottom. Opens the New
                   Request Picker screen (E2).

  **Empty State**  When the filtered list returns zero results: centered
                   illustration + message \'No requests yet\' (or \'No
                   requests match this filter\') + a primary action
                   button \'+ Create your first request\'.

  **Loading        Skeleton placeholders for KPI cards and request cards.
  State**          No spinner.

  **Error State**  Inline error banner at the top of the list area with
                   retry button. Counter cards show \'---\' until retry
                   succeeds.
  -----------------------------------------------------------------------

**3.1.3 KPI Counter Logic**

  ------------------------------------------------------------------------
  **Counter**        **Source**             **Description**
  ------------------ ---------------------- ------------------------------
  **Pending**        Count of own requests  Requests awaiting any kind of
                     with status in         action from the company side.
                     {Submitted, To         
                     Approve, Confirmed}    

  **Approved**       Count of own requests  Successfully approved
                     with status = Approved requests.
                     / Validated / Done     

  **Rejected**       Count of own requests  Requests that were declined or
                     with status = Refused  cancelled.
                     / Cancelled            

  **Draft**          Count of own requests  Requests created but not yet
                     with status = Draft    submitted.
  ------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **Status Mapping**                                                    |
|                                                                       |
| The exact Odoo status string for each Phase 1 request type is owned   |
| by the backend (Odoo 14). Status normalization (mapping multiple Odoo |
| states to the four UI buckets above) is also a backend                |
| responsibility. The mobile team consumes a single normalized          |
| \'ui_status\' field from the API response.                            |
+-----------------------------------------------------------------------+

**3.2 Screen E2 --- New Request Picker (Employee)**

The picker presents the five frequently used leave-type requests as
primary tiles immediately visible on screen. Less frequent leave types
and all asset request types are placed behind a \'More\' expansion.
Selecting a tile navigates the user to the corresponding form.

**3.2.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← New Request │                                                     |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ What would you like to request? │                                   |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ FREQUENT │                                                          |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │                |
|                                                                       |
| │ │ 🤒 │ │ ⏱️ │ │ 🏖️ │ │                                              |
|                                                                       |
| │ │ Sick Leave │ │ Short Leave │ │ Annual Leave │ │                   |
|                                                                       |
| │ └──────────────┘ └──────────────┘ └──────────────┘ │                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ │                                 |
|                                                                       |
| │ │ 🚀 │ │ ⏰ │ │                                                     |
|                                                                       |
| │ │ Job Mission │ │ Temporary │ │                                     |
|                                                                       |
| │ │ │ │ Permission │ │                                                |
|                                                                       |
| │ └──────────────┘ └──────────────┘ │                                 |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ────────────── More request types ───────────── ▼ │                 |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ (Expanded view shows additional tiles below) │                      |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ LEAVE │                                                             |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ │                                 |
|                                                                       |
| │ │ Work Comp. │ │ Encashment │ │                                     |
|                                                                       |
| │ └──────────────┘ └──────────────┘ │                                 |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ASSET │                                                             |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │                |
|                                                                       |
| │ │ 🚗 Car Rent │ │ 📱 SIM Card │ │ 💰 Car │ │                        |
|                                                                       |
| │ │ │ │ │ │ Allowance │ │                                             |
|                                                                       |
| │ └──────────────┘ └──────────────┘ └──────────────┘ │                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**3.2.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Header**       Back arrow returns to E1. Title text \'New Request\'.

  **Section        Caption text above the first tile group. Default:
  Heading**        \'What would you like to request?\'.

  **Tile           Square tile (1:1 aspect ratio recommended). Contains a
  (Frequent)**     request-type icon (top, large) and a label (bottom,
                   two lines max). Tapping opens the corresponding
                   existing leave form. Tile uses light fill with subtle
                   shadow; pressed state shows primary color border.

  **Frequent       Five tiles displayed in a 3-column grid (Sick / Short
  Group**          / Annual on row 1; Job Mission / Temporary Permission
                   on row 2). Section label: \'FREQUENT\' in small caps.
                   Always visible without scrolling on a standard mobile
                   viewport.

  **More Divider** Horizontal divider with the label \'More request
                   types\' centered, plus a chevron icon (▼ collapsed, ▲
                   expanded). Tapping toggles the visibility of the
                   additional tile groups below. Default state:
                   collapsed.

  **Leave Group    Section label \'LEAVE\'. Tiles: Work Compensation,
  (under More)**   Leave Encashment. Same tile design as Frequent.

  **Asset Group    Section label \'ASSET\'. Tiles: Car Rent Request, SIM
  (under More)**   Card Request, Car Allowance. Same tile design as
                   Frequent. Tapping these opens the new asset forms
                   specified in Section 5.

  **Tile Tap       On tap: navigate forward to the corresponding form
  Behavior**       with no transition delay. The form loads pre-populated
                   with the selected request type. The user cannot change
                   the request type from within the form (must back out).
  -----------------------------------------------------------------------

**3.3 Screen E3 --- Request Detail (Employee)**

The detail screen displays a single request in read-only mode along with
available actions. The same screen serves both leave-type and asset
requests, with form-specific field sections rendered dynamically based
on the request type.

**3.3.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Request Detail ⤓ Export │                                         |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 🏖️ Annual Leave │ │                                               |
|                                                                       |
| │ │ Ref: HR/LV/2026/0142 \[PENDING\] │ │                              |
|                                                                       |
| │ │ Submitted: 06 May 2026, 09:42 │ │                                 |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ REQUEST DETAILS │                                                   |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Leave Type │ Annual Leave │                                         |
|                                                                       |
| │ From Date │ 12 May 2026 │                                           |
|                                                                       |
| │ To Date │ 16 May 2026 │                                             |
|                                                                       |
| │ Number of Days │ 5 │                                                |
|                                                                       |
| │ Reason │ Family vacation │                                          |
|                                                                       |
| │ Attachment │ 📎 ticket.pdf \[ View \] │                             |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ STATUS TIMELINE │                                                   |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ ● Submitted 06 May 2026, 09:42 │                                    |
|                                                                       |
| │ ● To Approve (Manager) │                                            |
|                                                                       |
| │ ○ Pending HR validation │                                           |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ COMMENTS │                                                          |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ (No comments yet) │                                                 |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌────────────────┐ ┌────────────────┐ │                             |
|                                                                       |
| │ │ Cancel │ │ Duplicate │ │                                          |
|                                                                       |
| │ └────────────────┘ └────────────────┘ │                             |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**3.3.2 Component Specification**

  ------------------------------------------------------------------------
  **Component**     **Specification**
  ----------------- ------------------------------------------------------
  **Header**        Back arrow returns to E1. Title text \'Request
                    Detail\'. Right-side action: Export icon (⤓) opens PDF
                    export with watermark (specified in Section 6.5).

  **Header Card**   Top card with: request type icon and name, reference
                    number, status badge (top-right), submission
                    timestamp. Background uses light fill with a colored
                    left border matching the status (e.g., warning amber
                    for Pending).

  **Request Details Two-column display of all field/value pairs. Left
  Section**         column: field label in muted text. Right column: value
                    in regular text. Field list varies by request type ---
                    see Section 5 for asset request fields, existing leave
                    form for leave fields.

  **Attachments**   Each attachment renders as a row with file icon,
                    filename, file size, and a \'View\' action. Tapping
                    View opens the file in the device\'s default viewer.

  **Status          Vertical list showing the status journey of the
  Timeline**        request. Past steps: filled circle with timestamp.
                    Current step: filled circle, no timestamp. Future
                    steps: hollow circle, dimmed text. In Phase 1, this
                    timeline is populated from a single \'status_history\'
                    array in the API response. The exact structure is
                    owned by the backend.

  **Comments        Read-only list of comments associated with the request
  Section**         (sourced from Odoo mail.thread on the underlying
                    record). Each comment shows: author name, timestamp,
                    body. If no comments: \'No comments yet\' placeholder.
                    In Phase 1, employees cannot add comments.

  **Action          Bottom area shows context-aware actions. Available
  Buttons**         actions per status defined in Section 3.3.3 below.

  **Empty / Error   If detail fetch fails: full-screen error with retry
  States**          button and back action.
  ------------------------------------------------------------------------

**3.3.3 Action Availability by Status**

  ------------------------------------------------------------------------------
  **Status**          **Cancel**   **Duplicate**   **Edit**     **Export PDF**
  ------------------ ------------ --------------- ----------- ------------------
  **Draft**             **✓**          **✓**         **✓**          **✓**

  **Pending**           **✓**          **✓**          ---           **✓**

  **Approved**           ---           **✓**          ---           **✓**

  **Rejected**           ---           **✓**          ---           **✓**
  ------------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **Note on Edit Action**                                               |
|                                                                       |
| Edit is only available while the request is in Draft state. Once      |
| submitted, the user must Cancel and create a new request (Duplicate   |
| is provided as a shortcut). The exact API behavior for edit/cancel is |
| owned by the backend.                                                 |
+-----------------------------------------------------------------------+

**4. Manager View**

The Manager view is rendered when the login response indicates
is_management, is_pm, or is_hr_manager. The view extends the Employee
experience by adding visibility into requests submitted by team members
and a dashboard with KPIs and analytical charts.

**4.1 Screen M1 --- Manager Landing**

The manager landing screen provides a tabbed interface separating team
activity from the manager\'s own requests. Above the tabs is a KPI strip
summarizing key metrics relevant to the manager\'s responsibilities.

**4.1.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← HR Requests ⋮ │                                                   |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │                |
|                                                                       |
| │ │ Pending │ │ Approved │ │ This Month │ │                           |
|                                                                       |
| │ │ My Action: 7 │ │ This Mo: 18 │ │ Total: 24 │ │                    |
|                                                                       |
| │ └──────────────┘ └──────────────┘ └──────────────┘ │                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌────────────────────┐ ┌────────────────────┐ │                     |
|                                                                       |
| │ │ 📊 Dashboard │ │ 📋 Requests │ │                                  |
|                                                                       |
| │ └────────────────────┘ └────────────────────┘ │                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌─────────────────────────────────────────────────┐ │               |
|                                                                       |
| │ │ Team Requests │ My Own Requests │ │                               |
|                                                                       |
| │ └─────────────────────────────────────────────────┘ │               |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 🔍 Search by employee, type, or reference no. │ │                 |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ All \] \[ Pending \] \[ Approved \] \[ Rejected \] │             |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Recent Activity Filter ▼ │                                          |
|                                                                       |
| │ ──────────────────────────────────────────────────── │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Ahmed Al-Rashid Annual Leave \[PENDING\] │ │                   |
|                                                                       |
| │ │ Sales Department 12 May → 16 May (5d) │ │                         |
|                                                                       |
| │ │ Submitted 2d ago │ │                                              |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Fatima Hassan Sick Leave \[APPROVED\] │ │                      |
|                                                                       |
| │ │ Marketing 04 May (1 day) │ │                                      |
|                                                                       |
| │ │ Submitted 6d ago │ │                                              |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ Show More --- Search older requests\... \] │                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**4.1.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **KPI Strip**    Three counter cards: \'Pending My Action\' (count of
                   team requests in Pending state), \'Approved This
                   Month\' (count of team requests approved within the
                   current month), \'This Month Total\' (count of all
                   team requests submitted this month). HR Managers see
                   company-wide totals; Line Managers and PMs see their
                   scoped totals.

  **View           Two large buttons toggle between Dashboard view
  Switcher**       (Section 4.2) and Requests view (default). The
                   selected view button uses primary color fill; the
                   inactive button uses light fill with primary color
                   text.

  **Tabs**         Two tabs: \'Team Requests\' (default) and \'My Own
                   Requests\'. The \'My Own Requests\' tab renders the
                   same content as Screen E1 (Employee landing). The
                   \'Team Requests\' tab is detailed below.

  **Search Bar**   Same as E1 but extended placeholder: \'Search by
                   employee, type, or reference no.\'. Search runs
                   against employee name, request type, and reference
                   number.

  **Filter Chips** Status filter chips identical to E1.

  **Filter         Right-side dropdown opens a filter sheet with options:
  Dropdown**       by Department (HR Manager only), by Request Type, by
                   Date Range. Applied filters show as removable chips
                   above the list.

  **Team Request   Card design extends the Employee card by prepending an
  Card**           Employee block: avatar, employee name, department. The
                   rest of the card (request type, status, dates,
                   submitted timestamp) follows the same layout as E1.

  **Recent Scope** By default, the Team Requests list displays only
                   recent records: requests in Pending state and requests
                   approved/rejected within the last 30 days. Older
                   records are accessible via the \'Show More\' action
                   which expands into a search-driven view.

  **Show More**    Tappable row at the bottom of the list. Opens an
                   expanded search screen with full filter capability
                   across all historical team records.

  **Tap Behavior** Tapping a team request card opens the Request Detail
                   screen (M3) with manager-specific layout.

  **Empty State**  If no team requests exist or match the filter:
                   centered illustration with message \'No team requests
                   to display\'.
  -----------------------------------------------------------------------

**4.1.3 Visibility Scope by Role**

  ------------------------------------------------------------------------
  **Role**            **Team Requests Tab Scope**
  ------------------- ----------------------------------------------------
  **is_hr_manager**   All requests across all departments and all
                      employees in the company. Department filter is
                      enabled.

  **is_management**   Requests submitted by direct reports as defined in
                      the Odoo employee hierarchy (employee.parent_id
                      chain). Department filter is hidden.

  **is_pm**           Requests submitted by team members assigned to the
                      manager\'s projects. Department filter is hidden.

  **Multiple flags    If a user has both is_hr_manager and another flag,
  true**              the HR Manager scope takes precedence (broadest
                      visibility).
  ------------------------------------------------------------------------

**4.2 Screen M2 --- Manager Dashboard**

The dashboard provides a visual analytics view of team request activity.
It is accessed by tapping the \'Dashboard\' button on the Manager
Landing screen. The dashboard is intentionally compact and scrollable on
mobile viewports.

**4.2.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Dashboard This Month ▼ ⤓ │                                        |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │                |
|                                                                       |
| │ │ Total │ │ Pending │ │ Avg Approval │ │                            |
|                                                                       |
| │ │ 24 │ │ 7 │ │ 1.4 days │ │                                         |
|                                                                       |
| │ └──────────────┘ └──────────────┘ └──────────────┘ │                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ REQUESTS BY TYPE │                                                  |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ │ ╭─────╮ │ │                                                       |
|                                                                       |
| │ │ ╱ ╲ ■ Annual Leave 42% │ │                                        |
|                                                                       |
| │ │ │ ◯◯ │ ■ Sick Leave 25% │ │                                       |
|                                                                       |
| │ │ │ ◯◯◯ │ ■ Short Leave 17% │ │                                     |
|                                                                       |
| │ │ ╲ ╱ ■ Job Mission 8% │ │                                          |
|                                                                       |
| │ │ ╰─────╯ ■ Asset Requests 8% │ │                                   |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ REQUESTS BY MONTH │                                                 |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ ▆ │ │                                                             |
|                                                                       |
| │ │ ▆ ▆ │ │                                                           |
|                                                                       |
| │ │ ▆ ▆ ▆ ▆ ▆ ▆ │ │                                                   |
|                                                                       |
| │ │ ▆ ▆ ▆ ▆ ▆ ▆ ▆ ▆ │ │                                               |
|                                                                       |
| │ │ Jan Feb Mar Apr May Jun Jul Aug │ │                               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ TOP REQUESTERS (this month) │                                       |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ 1. Ahmed Al-Rashid │ 4 requests › │                                 |
|                                                                       |
| │ 2. Fatima Hassan │ 3 requests › │                                   |
|                                                                       |
| │ 3. Omar Khalid │ 3 requests › │                                     |
|                                                                       |
| │ 4. Layla Mohammed │ 2 requests › │                                  |
|                                                                       |
| │ 5. Yousef Ibrahim │ 2 requests › │                                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ DEPARTMENT BREAKDOWN (HR Manager only) │                            |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Sales ▆▆▆▆▆▆▆▆▆▆ 28 │                                               |
|                                                                       |
| │ Marketing ▆▆▆▆▆▆ 18 │                                               |
|                                                                       |
| │ Operations ▆▆▆▆▆▆▆▆▆ 24 │                                           |
|                                                                       |
| │ F&B ▆▆▆▆▆▆▆▆▆▆▆▆▆ 34 │                                              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**4.2.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Period         Dropdown in the header allowing the manager to switch
  Selector**       the dashboard time window. Options: This Week, This
                   Month (default), Last Month, This Quarter, This Year,
                   Custom Range. All charts and KPIs reflect the selected
                   window.

  **Export         Export icon (⤓) in the header generates a PDF snapshot
  Action**         of the entire dashboard with the emp_id watermark. PDF
                   specification in Section 6.5.

  **KPI Cards**    Three top-line metrics for the selected period: Total
                   Requests, Pending, Average Approval Time. The
                   \'Average Approval Time\' metric is the mean elapsed
                   time between submission and final approval in days,
                   computed by the backend.

  **Requests by    Donut chart with legend on the right. Top 5 request
  Type Chart**     types displayed individually; remaining grouped as
                   \'Other\'. Each slice tappable --- taps drill down
                   into the Requests view filtered by that type.

  **Requests by    Vertical bar chart showing request counts per month.
  Month Chart**    The X-axis range adapts to the selected period. Bars
                   use primary color. Hover/tap reveals exact count.

  **Top Requesters Ordered list of the five team members with the most
  List**           submissions in the selected period. Each row tappable
                   --- opens Requests view filtered by that employee.

  **Department     Visible only when is_hr_manager. Horizontal bar chart
  Breakdown**      with one row per department. Each bar tappable ---
                   opens Requests view filtered by that department.

  **Loading /      Each chart loads independently. Skeleton placeholders
  Error**          during load. If a chart fails: inline error within
                   that chart\'s container with retry.
  -----------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **Charts Library Recommendation**                                     |
|                                                                       |
| For Flutter, the fl_chart package is recommended for all dashboard    |
| charts. It provides donut charts, bar charts, and line charts with    |
| consistent theming. The charts library is a one-time setup decision   |
| and applies to all manager dashboards across all modules.             |
+-----------------------------------------------------------------------+

**4.3 Screen M3 --- Request Detail (Manager)**

The manager-side request detail screen extends the Employee detail
screen (E3) with an Employee Information card at the top. All other
sections, actions (export, etc.) and read-only treatment remain
identical to the Employee version. In Phase 1, no Approve / Reject
actions are present --- those are deferred to Phase 2.

**4.3.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Request Detail ⤓ Export │                                         |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Ahmed Al-Rashid │ │                                            |
|                                                                       |
| │ │ Sales Manager · Sales Dept · Emp #4471 │ │                        |
|                                                                       |
| │ │ 📧 ahmed@company.ae 📞 +971 50 xxx xxxx │ │                       |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 🏖️ Annual Leave │ │                                               |
|                                                                       |
| │ │ Ref: HR/LV/2026/0142 \[PENDING\] │ │                              |
|                                                                       |
| │ │ Submitted: 06 May 2026, 09:42 │ │                                 |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ REQUEST DETAILS │                                                   |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Leave Type │ Annual Leave │                                         |
|                                                                       |
| │ From Date │ 12 May 2026 │                                           |
|                                                                       |
| │ To Date │ 16 May 2026 │                                             |
|                                                                       |
| │ Number of Days │ 5 │                                                |
|                                                                       |
| │ Available Balance │ 18 days │                                       |
|                                                                       |
| │ Reason │ Family vacation │                                          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ STATUS TIMELINE │                                                   |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ ● Submitted 06 May 2026, 09:42 │                                    |
|                                                                       |
| │ ● To Approve (You) awaiting action │                                |
|                                                                       |
| │ ○ Pending HR validation │                                           |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ COMMENTS │                                                          |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ (No comments yet) │                                                 |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ╔═══════════════════════════════════════════════════╗ │             |
|                                                                       |
| │ ║ Phase 2: Approve / Reject buttons appear here ║ │                 |
|                                                                       |
| │ ╚═══════════════════════════════════════════════════╝ │             |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**4.3.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Employee       Card at top with avatar (initials if no photo), full
  Card**           name, job title and department, employee number,
                   contact email, contact phone. The card is tappable in
                   future phases to open a full employee profile; in
                   Phase 1 it is informational only.

  **Header Card**  Identical to Employee detail (E3.1).

  **Request        Identical to E3.2 plus an additional \'Available
  Details          Balance\' row for leave-type requests, showing the
  Section**        employee\'s remaining balance for that leave type at
                   the time of submission. Backend supplies this value.

  **Status         Same as E3 but with role-aware labels. When the
  Timeline**       current pending step is the manager\'s action, the
                   label reads \'To Approve (You)\' instead of \'To
                   Approve (Manager)\'.

  **Comments       Read-only in Phase 1, identical to E3.
  Section**        

  **Export         PDF export available with emp_id watermark --- emp_id
  Action**         taken from the manager\'s login response, not the
                   employee\'s. Watermark and export specs in Section
                   6.5.

  **Phase 2        The bottom action area is reserved for Phase 2 Approve
  Reservation**    / Reject buttons. In Phase 1, this area is empty (no
                   placeholder shown to the user).
  -----------------------------------------------------------------------

**4.4 Screen M4 --- Search Older Requests (Manager)**

Triggered from the \'Show More --- Search older requests\' action on the
Manager Landing screen. Provides a search-first interface for accessing
historical team requests beyond the default recent window.

**4.4.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Search Team Requests │                                            |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 🔍 Search\... │ │                                                 |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ FILTERS │                                                           |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Employee: \[ Select employee\... ▼ \] │                             |
|                                                                       |
| │ Department: \[ Select department\... ▼ \] (HR only)│                |
|                                                                       |
| │ Request Type: \[ Select type\... ▼ \] │                             |
|                                                                       |
| │ Status: \[ All ▼ \] │                                               |
|                                                                       |
| │ Date Range: \[ From ▼ \] \[ To ▼ \] │                               |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ Clear All \] \[ Apply Filters \] │                               |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Results (47) │                                                      |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Ahmed Al-Rashid Annual Leave \[APPROVED\] │ │                  |
|                                                                       |
| │ │ 08 Mar → 12 Mar 2026 (5d) │ │                                     |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Fatima Hassan Sick Leave \[APPROVED\] │ │                      |
|                                                                       |
| │ │ 14 Feb 2026 (1d) │ │                                              |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \... │                                                              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**4.4.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Search Input** Free-text search across employee name, request type,
                   and reference number. Triggers on submit (search
                   button or enter key) --- not on every keystroke, to
                   avoid unnecessary API calls on a potentially large
                   dataset.

  **Filter Form**  Multiple dropdowns and date pickers stacked
                   vertically. Department filter is hidden for non-HR
                   Manager roles. Date Range supports From and To dates
                   independently.

  **Apply Filters  Primary button. Sends the combined query to the
  Button**         backend and renders results below.

  **Clear All**    Resets all filters and the search input to default
                   state.

  **Results        Number of records matched by the active query.
  Count**          

  **Result Cards** Same design as Manager Landing team request cards.
                   Tapping opens M3.

  **Pagination**   Infinite scroll with page size of 20 records. Loading
                   indicator at the bottom during fetch.

  **Empty / No     If the query returns zero results: centered message
  Results**        \'No requests match your filters\' + suggestion to
                   broaden filters.
  -----------------------------------------------------------------------

**5. Asset Request Forms (New)**

Three new forms are introduced in this module for asset-type requests.
Each form follows the same structural pattern: form header, field
sections, attachment area, and submit/save controls. The visual design
matches the existing leave form to maintain consistency.

**5.1 Common Form Structure**

All three asset request forms share a common shell.

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← \[Form Title\] │                                                  |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[Form Title\] │                                                    |
|                                                                       |
| │ Submit a request for \[type description\] │                         |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[Form-specific fields appear here\] │                              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ATTACHMENT (Optional) │                                             |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 📎 Tap to attach a file │ │                                       |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌────────────────┐ ┌────────────────────────────┐ │                 |
|                                                                       |
| │ │ Save Draft │ │ Submit Request │ │                                 |
|                                                                       |
| │ └────────────────┘ └────────────────────────────┘ │                 |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**5.1.1 Common Components**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Header**       Back arrow returns to the New Request Picker (E2).
                   Title text is the form name (e.g., \'Car Rent
                   Request\').

  **Form Title     Form title in heading style + a one-line description
  Block**          below in muted text.

  **Field          Form fields rendered top to bottom. Required fields
  Sections**       marked with an asterisk and a red color on the
                   asterisk. Inline validation: error text appears below
                   the field when the user attempts to submit with
                   invalid input.

  **Field Types    Text input, multi-line text area, dropdown
  Used**           (single-select), date picker, datetime picker, numeric
                   input. Each has a consistent style with the existing
                   leave form.

  **Attachment     Single optional attachment slot. Tapping opens the
  Block**          device\'s file picker (uses the application\'s
                   existing attachment handling, since attachments are
                   out of scope per Phase 1 foundation decisions).

  **Save Draft     Secondary button. Saves the request in Draft state and
  Button**         returns to E1. The user can resume editing from the
                   Drafts filter on E1.

  **Submit Request Primary button. Calls the submit API. On success,
  Button**         navigates back to E1 with a confirmation toast
                   \'Request submitted successfully --- Ref:
                   HR/XX/YYYY/NNNN\'.

  **Validation**   Client-side validation for required fields and field
                   formats (date, number ranges). Server-side validation
                   messages are displayed inline at the field level when
                   returned by the backend.

  **Loading        On submit, the Submit button shows a spinner and is
  State**          disabled until the response is received.
  -----------------------------------------------------------------------

**5.2 SIM Card Request Form**

Submitted by an employee to request a new corporate SIM, replace an
existing SIM, or upgrade their plan.

**5.2.1 Field Specification**

  ----------------------------------------------------------------------------
  **Field**           **Type**     **Required**    **Notes**
  ------------------- ------------ --------------- ---------------------------
  **Request Reason**  Dropdown     **Required**    Options: New Hire,
                                                   Replacement (Lost),
                                                   Replacement (Damaged), Plan
                                                   Upgrade, Plan Downgrade,
                                                   Other.

  **Plan Type**       Dropdown     **Required**    Options: Basic, Standard,
                                                   Premium, Custom. Plan
                                                   options sourced from a
                                                   configurable backend list.

  **Required By       Date Picker  **Required**    Cannot be a past date.
  Date**                                           Default: 7 days from today.

  **Justification**   Multi-line   **Required**    Free-text reason. Min 10
                      Text                         characters, max 500.

  **Phone Number      Text         Optional        Required only if Reason =
  (current)**                                      Replacement or Plan
                                                   Upgrade/Downgrade. Format:
                                                   UAE phone number.

  **Attachment**      File         Optional        Used for police report
                                                   (lost SIM), damage photo,
                                                   or other supporting docs.
  ----------------------------------------------------------------------------

**5.2.2 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← SIM Card Request │                                                |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ SIM Card Request │                                                  |
|                                                                       |
| │ Submit a request for a corporate SIM card │                         |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Request Reason \* │                                                 |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ Select reason\... ▼ │ │                                           |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Plan Type \* │                                                      |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ Select plan\... ▼ │ │                                             |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Required By Date \* │                                               |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 📅 DD / MM / YYYY │ │                                             |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Justification \* │                                                  |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Current Phone Number (if replacement/upgrade) │                     |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ +971 │ │                                                          |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ATTACHMENT (Optional) │                                             |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 📎 Tap to attach a file │ │                                       |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ Save Draft \] \[ Submit Request \] │                             |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**5.3 Car Rent Request Form**

Submitted by an employee to request a rental vehicle for business use
over a specified period.

**5.3.1 Field Specification**

  ----------------------------------------------------------------------------
  **Field**           **Type**     **Required**    **Notes**
  ------------------- ------------ --------------- ---------------------------
  **Purpose**         Dropdown     **Required**    Options: Business Trip,
                                                   Client Visit, Site Visit,
                                                   Airport Pickup/Drop, Other.

  **From Date &       DateTime     **Required**    Cannot be a past datetime.
  Time**              Picker                       Granularity: 30 minutes.

  **To Date & Time**  DateTime     **Required**    Must be after From Date &
                      Picker                       Time. Granularity: 30
                                                   minutes.

  **Pickup Location** Text         **Required**    Free-text. Max 150 chars.
                                                   Future enhancement:
                                                   dropdown of branches.

  **Drop-off          Text         **Required**    Free-text. Max 150 chars.
  Location**                                       

  **Vehicle Type      Dropdown     Optional        Options: Sedan, SUV, Van,
  Preference**                                     Pickup, Any.

  **Estimated         Numeric      Optional        Numeric input. Min 0, max
  Distance (km)**                                  5000.

  **Justification**   Multi-line   **Required**    Min 10 characters, max 500.
                      Text                         

  **Attachment**      File         Optional        Supporting docs (e.g., trip
                                                   itinerary, client meeting
                                                   confirmation).
  ----------------------------------------------------------------------------

**5.3.2 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Car Rent Request │                                                |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Car Rent Request │                                                  |
|                                                                       |
| │ Request a rental vehicle for business use │                         |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Purpose \* │                                                        |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ Select purpose\... ▼ │ │                                          |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ From Date & Time \* To Date & Time \* │                             |
|                                                                       |
| │ ┌────────────────────┐ ┌────────────────────┐ │                     |
|                                                                       |
| │ │ 📅 Pick datetime │ │ 📅 Pick datetime │ │                         |
|                                                                       |
| │ └────────────────────┘ └────────────────────┘ │                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Pickup Location \* │                                                |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ Enter pickup location │ │                                         |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Drop-off Location \* │                                              |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ Enter drop-off location │ │                                       |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Vehicle Type Estimated Distance (km) │                              |
|                                                                       |
| │ ┌────────────────┐ ┌────────────────────────────┐ │                 |
|                                                                       |
| │ │ Any ▼ │ │ │ │                                                     |
|                                                                       |
| │ └────────────────┘ └────────────────────────────┘ │                 |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Justification \* │                                                  |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ATTACHMENT (Optional) │                                             |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 📎 Tap to attach a file │ │                                       |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ Save Draft \] \[ Submit Request \] │                             |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**5.4 Car Allowance Form**

Submitted by an employee to request a recurring monetary car allowance,
a per-trip allowance, or a fuel reimbursement, in lieu of a
company-provided vehicle.

**5.4.1 Field Specification**

  ----------------------------------------------------------------------------
  **Field**           **Type**     **Required**    **Notes**
  ------------------- ------------ --------------- ---------------------------
  **Allowance Type**  Dropdown     **Required**    Options: Monthly Fixed,
                                                   Per-Trip, Fuel
                                                   Reimbursement.

  **Requested Amount  Numeric      **Required**    Min 0. Decimals allowed (2
  (AED)**                                          places). The label currency
                                                   is fixed to AED.

  **Effective From**  Date Picker  **Required**    Cannot be more than 90 days
                                                   in the past. Default:
                                                   today.

  **Justification**   Multi-line   **Required**    Min 20 characters, max
                      Text                         1000. Used for HR/Finance
                                                   review.

  **Vehicle           File         Optional        Attach vehicle registration
  Registration**                                   card (Mulkiya). Required if
                                                   Allowance Type = Monthly
                                                   Fixed (enforced by
                                                   backend).

  **Driving License** File         Optional        Attach driving license.
                                                   Required by some HR
                                                   policies --- backend
                                                   determines.
  ----------------------------------------------------------------------------

**5.4.2 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Car Allowance Request │                                           |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Car Allowance Request │                                             |
|                                                                       |
| │ Request a vehicle allowance in lieu of company vehicle │            |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Allowance Type \* │                                                 |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ Select type\... ▼ │ │                                             |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Requested Amount (AED) \* │                                         |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ AED │ │                                                           |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Effective From \* │                                                 |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 📅 DD / MM / YYYY │ │                                             |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Justification \* │                                                  |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ SUPPORTING DOCUMENTS │                                              |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 📎 Vehicle Registration (Mulkiya) │ │                             |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 📎 Driving License │ │                                            |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ Save Draft \] \[ Submit Request \] │                             |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**6. Cross-Cutting Specifications**

**6.1 Theme & Visual Style**

The HR Requests module uses a light theme aligned with the existing
Pandora HR application. The palette favors a clean, professional look
with controlled use of accent color.

  ------------------------------------------------------------------------
  **Token**        **Hex**       **Sample**    **Usage**
  ---------------- ------------- ------------- ---------------------------
  **Primary**      #1F3A5F       **■■■■**      Primary buttons, active
                                               filter chip, KPI counter
                                               values, headers, donut
                                               chart main slice.

  **Secondary**    #4A6B8A       **■■■■**      Section subheaders,
                                               secondary text emphasis,
                                               chart secondary slices.

  **Accent**       #8B2635       **■■■■**      Sparingly: error
                                               indicators, required-field
                                               asterisks, key call-outs.

  **Light          #F5F8FB       **■■■■**      Card backgrounds, screen
  Background**                                 background, alternating row
                                               shading.

  **Surface**      #FFFFFF       **■■■■**      Card surface, form input
                                               background.

  **Text**         #1A1A1A       **■■■■**      Body text.

  **Muted Text**   #6B7280       **■■■■**      Field labels, hint text,
                                               secondary timestamps.

  **Border**       #C5CDD6       **■■■■**      Input borders, dividers,
                                               card outlines.

  **Success**      #2E7D5B       **■■■■**      Approved status, success
                                               toasts.

  **Warning**      #C77700       **■■■■**      Pending status, warning
                                               callouts.

  **Danger**       #8B2635       **■■■■**      Rejected status, error
                                               states.
  ------------------------------------------------------------------------

**6.2 Typography**

  -------------------------------------------------------------------------
  **Style**        **Size**      **Weight**   **Usage**
  ---------------- ------------- ------------ -----------------------------
  **Page Title**   20--22 sp     600          Screen header titles.

  **Section        16 sp         600          Section dividers (e.g.,
  Heading**                                   \'REQUEST DETAILS\').

  **Card Title**   16 sp         600          Request type names, employee
                                              names on cards.

  **Body**         14 sp         400          Default text in details, list
                                              items.

  **Caption**      12 sp         400          Timestamps, hints, secondary
                                              metadata.

  **Counter        28 sp         700          KPI counter card large
  Number**                                    numbers.

  **Counter        12 sp         500          KPI counter card labels
  Label**                                     (Pending, Approved, etc.).

  **Button**       14 sp         600          Primary and secondary button
                                              text.

  **Status Badge** 11 sp         700          Pill badge text (uppercase).
  -------------------------------------------------------------------------

**6.3 Spacing & Layout**

  -----------------------------------------------------------------------
  **Aspect**       **Specification**
  ---------------- ------------------------------------------------------
  **Screen         16 dp horizontal padding on all main screens.
  Padding**        

  **Card Spacing** 12 dp vertical gap between cards in lists.

  **Card Radius**  8 dp corner radius on all cards and tiles.

  **Card Shadow**  Subtle elevation: 0 dp x, 2 dp y, 4 dp blur, #1F3A5F
                   at 8% opacity.

  **Form Field     16 dp vertical gap between fields. 4 dp gap between
  Spacing**        label and input.

  **Button         48 dp standard tap target.
  Height**         

  **Filter Chip    32 dp.
  Height**         

  **Tile Aspect    1:1 for request type tiles in the picker.
  Ratio**          
  -----------------------------------------------------------------------

**6.4 Status Badge Color Mapping**

Status badges appear on every request card and request detail header.
The mobile team consumes a normalized \'ui_status\' field from the
backend API and maps it to the visual treatment below.

  --------------------------------------------------------------------------
  **UI Status**   **Background**   **Text Color**  **Sample Odoo States
                                                   Mapped**
  --------------- ---------------- --------------- -------------------------
  **DRAFT**       #E5E7EB          #374151         draft

  **PENDING**     #FFF4D6          #C77700         submit, confirm,
                                                   to_approve, validate1

  **APPROVED**    #D6F0E2          #2E7D5B         approved, validate, done

  **REJECTED**    #F5D6DA          #8B2635         refuse, refused, cancel,
                                                   cancelled
  --------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **Backend Ownership**                                                 |
|                                                                       |
| The backend is responsible for mapping each request type\'s Odoo      |
| state to one of the four UI statuses above and returning it as        |
| \'ui_status\' in API responses. The mobile team should never          |
| interpret raw Odoo state strings directly.                            |
+-----------------------------------------------------------------------+

**6.5 PDF Export with Watermark**

PDF export is available on the Request Detail screens (E3 and M3) and on
the Manager Dashboard (M2). Every exported PDF must include a watermark
of the user\'s emp_id, taken from the login API response of the user
generating the export.

**6.5.1 Watermark Specification**

  -----------------------------------------------------------------------
  **Property**     **Value**
  ---------------- ------------------------------------------------------
  **Content**      Text equal to emp_id from the login response (e.g.,
                   \'EMP-4471\'). Backend may also include a label prefix
                   --- final string format owned by backend.

  **Color**        Light gray (#C5CDD6)

  **Opacity**      20%

  **Font Size**    60 pt

  **Rotation**     -45° (diagonal, bottom-left to top-right)

  **Position**     Centered on every page, behind content

  **Repeated**     Tiled in a 3×3 grid for larger pages, single
                   occurrence on standard A4
  -----------------------------------------------------------------------

**6.5.2 PDF Generation Approach**

  ------------------------------------------------------------------------
  **Option**        **Description**
  ----------------- ------------------------------------------------------
  **Server-side     Backend generates the PDF via an Odoo report template,
  (recommended)**   applies the watermark using the emp_id passed in the
                    request, returns the PDF binary. The mobile app
                    initiates the download. Pros: consistent rendering,
                    lower mobile complexity. Cons: requires Odoo report
                    development.

  **Client-side**   Mobile app generates the PDF locally using a Flutter
                    PDF library (e.g., pdf, printing). Watermark applied
                    in the client. Pros: no backend dependency. Cons:
                    rendering may diverge from backend format.

  **Decision**      Final approach to be confirmed during API design
                    phase. This document does not mandate either approach.
  ------------------------------------------------------------------------

**6.6 Empty, Loading, and Error States**

Every screen in this module must explicitly define behavior for empty,
loading, and error states. The matrix below summarizes the standard
pattern.

  -------------------------------------------------------------------------
  **State**      **Visual**         **Action           **Applies To**
                                    Available**        
  -------------- ------------------ ------------------ --------------------
  **Loading**    Skeleton           None               All list and detail
                 placeholders                          screens during
                 matching the final                    initial load.
                 layout. No                            
                 spinner. Animated                     
                 shimmer.                              

  **Empty (no    Centered           Primary action     Landing screens,
  data)**        illustration +     (e.g., \'+ Create  search results,
                 descriptive        your first         dashboard with no
                 title + helper     request\')         team activity.
                 text + primary                        
                 action button.                        

  **Empty        Centered icon +    Clear filters      Filtered list views.
  (filtered)**   \'No requests                         
                 match your                            
                 filters\' +                           
                 \'Clear filters\'                     
                 link.                                 

  **Error**      Inline banner at   Retry, Back        Any API failure.
                 the top of the                        
                 affected area +                       
                 retry button.                         
                 Other screen                          
                 elements remain                       
                 functional if                         
                 possible.                             

  **No Network** Full-screen        Retry              When the device has
                 \'You\'re                             no network
                 offline\' message                     connectivity.
                 with retry button.                    
                 Phase 1 is online                     
                 only.                                 
  -------------------------------------------------------------------------

**6.7 Component Inventory**

Reusable UI components introduced in this module. Building these as
shared widgets reduces duplication and ensures visual consistency.

  ----------------------------------------------------------------------------
  **Component**          **Used In**        **Notes**
  ---------------------- ------------------ ----------------------------------
  **KpiCounterCard**     E1, M1, M2         Counter card with number, label,
                                            optional tap behavior.
                                            Configurable color.

  **FilterChipRow**      E1, M1             Horizontal scrollable row of
                                            selectable chips.

  **RequestCard          E1                 Card variant without employee
  (Employee)**                              details.

  **RequestCard (Team)** M1, M4             Card variant with employee header
                                            block.

  **StatusBadge**        All cards, detail  Pill-shaped badge. Color set by
                         screens            ui_status.

  **RequestTypeTile**    E2                 Square tile with icon and label.

  **DetailRow**          E3, M3             Two-column field/value display.

  **StatusTimeline**     E3, M3             Vertical step list with filled /
                                            hollow circles.

  **EmployeeInfoCard**   M3                 Avatar, name, contact info.

  **ChartContainer**     M2                 Wrapper for charts with title,
                                            period, error/loading states.

  **FormField**          Asset forms        Wrapper for label + input + error
                                            message.

  **SearchBar**          E1, M1, M4         Standardized search input with
                                            icon and debounce.
  ----------------------------------------------------------------------------

**7. Screen Inventory & Navigation**

**7.1 Screen Inventory**

  -------------------------------------------------------------------------
  **Screen    **Screen Name**        **Audience**   **New / Existing**
  ID**                                              
  ----------- ---------------------- -------------- -----------------------
  **E1**      HR Request Landing     Employee       **New**
              (Employee)                            

  **E2**      New Request Picker     Employee       **New**

  **E3**      Request Detail         Employee       **New**
              (Employee)                            

  **F1**      Leave Form             Employee       Existing --- Reused

  **F2**      SIM Card Request Form  Employee       **New**

  **F3**      Car Rent Request Form  Employee       **New**

  **F4**      Car Allowance Form     Employee       **New**

  **M1**      Manager Landing        Manager / HR   **New**
              (Requests)             Manager        

  **M2**      Manager Dashboard      Manager / HR   **New**
                                     Manager        

  **M3**      Request Detail         Manager / HR   **New**
              (Manager)              Manager        

  **M4**      Search Older Requests  Manager / HR   **New**
                                     Manager        
  -------------------------------------------------------------------------

**7.2 Navigation Flow**

Diagram of screen-to-screen navigation paths within the HR Requests
module.

+-----------------------------------------------------------------------+
| \[ Main App Home \]                                                   |
|                                                                       |
| │                                                                     |
|                                                                       |
| Tap \'HR Request\' widget                                             |
|                                                                       |
| │                                                                     |
|                                                                       |
| ▼                                                                     |
|                                                                       |
| ┌──────────────────────────────────────┐                              |
|                                                                       |
| │ Role detection from login response │                                |
|                                                                       |
| └──────────────────────────────────────┘                              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| Employee │ │ Manager / HR Manager                                     |
|                                                                       |
| ▼ ▼                                                                   |
|                                                                       |
| ┌──────────────┐ ┌──────────────┐                                     |
|                                                                       |
| │ E1 Landing │ │ M1 Landing │                                         |
|                                                                       |
| └──────┬───────┘ └──────┬───────┘                                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| ┌───────┼───────┐ ┌──────┼───────┬─────────┐                          |
|                                                                       |
| ▼ ▼ ▼ ▼ ▼ ▼ ▼                                                         |
|                                                                       |
| \[E2\] \[E3\] \[+New\] \[M2\] \[M3\] \[M4\] \[E1 \'My Own\'\]         |
|                                                                       |
| │ │ │ │ │                                                             |
|                                                                       |
| │ │ │ │ │                                                             |
|                                                                       |
| ┌──┴──┐ ▼ (PDF) ▼ ▼                                                   |
|                                                                       |
| ▼ ▼ (PDF (PDF) M3                                                     |
|                                                                       |
| \[F1\] \[F2/F3/F4\] Export) Export)                                   |
|                                                                       |
| Leave Asset                                                           |
|                                                                       |
| Form Forms                                                            |
+-----------------------------------------------------------------------+

**7.3 Backend API Touchpoints (To Be Defined)**

This section is a placeholder index of the API endpoints required to
support the screens above. Detailed API contracts will be defined in the
next phase, after the layout requirements in this document are signed
off.

  ------------------------------------------------------------------------
  **Capability**     **Used By**                          **Status**
  ------------------ ------------------------------------ ----------------
  **Get my           E1, E1 \'My Own\' tab in Manager     To define
  requests**         view                                 

  **Get team         M1, M4                               To define
  requests (scoped                                        
  by role)**                                              

  **Get request      E3, M3                               To define
  detail**                                                

  **Submit request   F2, F3, F4                           To define
  (asset types)**                                         

  **Submit request   F1                                   Existing --- to
  (leave)**                                               verify

  **Save draft**     F1, F2, F3, F4                       To define

  **Cancel request** E3                                   To define

  **Get dashboard    M2                                   To define
  KPIs and charts**                                       

  **Search requests  M4                                   To define
  with filters**                                          

  **Generate PDF     E3, M3, M2                           To define
  export with                                             
  watermark**                                             

  **Get request type E2                                   To define
  catalog (frequent                                       
  vs more)**                                              
  ------------------------------------------------------------------------

**8. Sign-off & Next Steps**

**8.1 Module 1 Deliverables Summary**

  -----------------------------------------------------------------------
  **Deliverable**        **Status**
  ---------------------- ------------------------------------------------
  **Foundation decisions **✓ Confirmed**
  locked**               

  **Request types in     **✓ Leave + 3 asset types**
  scope**                

  **Employee screens     **✓ Specified**
  (E1, E2, E3)**         

  **Manager screens (M1, **✓ Specified**
  M2, M3, M4)**          

  **Asset request forms  **✓ Specified**
  (F2, F3, F4)**         

  **Theme, typography,   **✓ Specified**
  components**           

  **PDF export with      **✓ Specified**
  watermark**            

  **Approval workflow**  **Phase 2**

  **API contracts**      **Next phase after sign-off**
  -----------------------------------------------------------------------

**8.2 Open Items Owned by Backend Team**

- Status normalization: mapping Odoo states per request type to the four
  UI statuses (Draft / Pending / Approved / Rejected)

- Status timeline structure: format of the \'status_history\' array
  returned in request detail responses

- Frequent vs More request type catalog: whether configured per company
  in Odoo or hardcoded

- Validation rules per request type: backend enforcement of dates,
  balances, conflict checks

- Average approval time computation: formula and time window for the M2
  KPI

- Department visibility scope: how \'department\' is determined for HR
  Manager filtering

- PDF generation approach: server-side report rendering vs client-side
  library

- Reference number format per request type (e.g., HR/LV/YYYY/NNNN,
  HR/CR/YYYY/NNNN)

**8.3 Next Steps**

  ----------------------------------------------------------------------------
  **Step**   **Action**                         **Owner**
  ---------- ---------------------------------- ------------------------------
  **1**      Review Module 1 specification and  Pandora Tech (Architect)
             provide feedback                   

  **2**      Confirm sign-off on Module 1       Pandora Tech (Architect)

  **3**      Proceed to Module 2 ---            Pandora Tech / Mobile Team
             Recruitment requirements           

  **4**      After all modules signed off,      Backend Team (Odoo)
             define API contracts               

  **5**      Begin mobile implementation        Mobile Team (Flutter)
             against finalized specs            
  ----------------------------------------------------------------------------

*--- End of Module 1 ---*

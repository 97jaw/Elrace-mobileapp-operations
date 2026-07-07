**HR MANAGEMENT MOBILE APPLICATION**

**Module 2: Recruitment**

*Software Requirements Specification*

  ----------------------- ----------------------- -----------------------
                                                  

  ----------------------- ----------------------- -----------------------

  -----------------------------------------------------------------------
  **Field**               **Detail**
  ----------------------- -----------------------------------------------
  Project                 HR Management Mobile Application

  Module                  Module 2 --- Recruitment

  Backend                 Odoo 14 ERP (HR module)

  Frontend                Flutter (existing app, widget integration)

  Document Type           Software Requirements Specification (SRD)

  Version                 1.0

  Prepared By             Pandora Tech LLC

  Audience                Mobile Development Team

  Phase                   Phase 1 --- Layout & Design Requirements

  Approach                Option C --- Best-judgment defaults with
                          flagged assumptions
  -----------------------------------------------------------------------

**1. Document Overview**

**1.1 Purpose**

This document defines the design and layout requirements for the
Recruitment module within the Pandora HR Management mobile application.
The module covers job requisition (recruitment requests), candidate
assessments, and offer letter tracking.

**1.2 Scope**

Recruitment is accessed from the **HR Management hub** in the existing app
(the same general entry area as HR requests / manager HR flows --- not a
separate tile on the app home). This is a manager-only module --- Employees
do not have access to Recruitment screens. Three role-based experiences are supported:
Hiring Manager (line manager raising a requisition), HR Manager
(managing the full pipeline), and read-only stakeholders.

**1.3 Phase 1 Boundaries**

  -----------------------------------------------------------------------
  **Aspect**              **Phase 1 Position**
  ----------------------- -----------------------------------------------
  **In Scope**            Recruitment Request (job requisition),
                          Candidate listing per requisition, Assessment
                          scorecards (internal evaluation of candidates
                          by interviewers), Offer Letter tracking and PDF
                          download.

  **Out of Scope**        Candidate-facing screens (candidates are
                          external, do not use the app). Online tests /
                          quizzes for candidates. Offer letter generation
                          and editing (mobile only views and downloads).
                          Job board posting integrations.

  **Approval Workflow**   Out of scope for Phase 1 (consistent with
                          Module 1).

  **PDF Export**          Yes --- Offer Letter PDF download with emp_id
                          watermark of the user generating the export.

  **Theme / Auth /        Inherits from foundation: light theme, online
  Notifications /         only, English only, existing auth and
  Connectivity /          notification handling.
  Language**              
  -----------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| Recruitment is HR Manager + Hiring Manager only. Employees (no        |
| manager flags) do not see this widget. If you want employees to also  |
| see internal job postings or apply internally, that becomes a         |
| separate Phase 2 employee-facing flow.                                |
+-----------------------------------------------------------------------+

**1.4 Roles & View Selection**

  -----------------------------------------------------------------------
  **Role Flag (from  **View Rendered**     **Visibility Scope**
  login)**                                 
  ------------------ --------------------- ------------------------------
  is_hr_manager =    HR Manager View       All recruitment requests
  true                                     company-wide. Full pipeline
                                           visibility, all candidates,
                                           all offer letters.

  is_management =    Hiring Manager View   Own raised requisitions +
  true                                     candidates assigned to them as
                                           interviewers. Cannot see other
                                           departments\' requisitions.

  is_pm = true       Hiring Manager View   Same as is_management. Treated
                                           identically in this module.

  None of the above  No Access             Recruitment widget is hidden
                                           or disabled for non-manager
                                           users.
  -----------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **Development Note**                                                  |
|                                                                       |
| Reuse the same dev-only role toggle introduced in Module 1 to switch  |
| between Hiring Manager and HR Manager views during development.       |
+-----------------------------------------------------------------------+

**2. Module Structure**

The Recruitment module is organized into three connected sub-modules.
Each sub-module has its own listing screen and detail screen, with
cross-links between them.

  -----------------------------------------------------------------------
  **Sub-module**   **Description**
  ---------------- ------------------------------------------------------
  **Recruitment    Job requisitions raised by hiring managers. Each
  Requests**       request defines an open position the company wants to
                   fill. Visible to the requester and HR Manager.

  **Candidates**   Applicants linked to a recruitment request. Mobile
                   users browse candidates per requisition, view
                   profiles, and complete assessment scorecards.

  **Offer          Documents generated for selected candidates. Mobile
  Letters**        users track status (Draft / Sent / Accepted / Declined
                   / Expired) and download the PDF.
  -----------------------------------------------------------------------

**2.1 Navigation Entry Point**

Eligible managers open **HR Management** (employee landing, manager landing,
or equivalent hub screen). From that hub they choose **Recruitment**, which
navigates to Screen **R1 --- Recruitment Landing**. There is **no**
standalone Recruitment entry on the app home grid; access is only through
the HR Management hub.

+-----------------------------------------------------------------------+
| **✓ CONFIRMED --- Stakeholder**                                       |
|                                                                       |
| Entry is **inside the HR Management hub** (not a separate home       |
| widget). Implementation: add a hub action (e.g. list row, tile, or    |
| menu item) visible only when `is_hr_manager` / `is_management` /        |
| `is_pm` per §1.4.                                                     |
+-----------------------------------------------------------------------+

**3. Recruitment Requests**

A Recruitment Request is a request to open a new position. It captures
the position details, justification, and approval state. In Odoo this
maps to hr.recruitment / hr.job records.

**3.1 Screen R1 --- Recruitment Landing**

The landing screen presents a KPI strip of recruitment activity, tabs
separating active requests from closed ones, and a list of recruitment
requests scoped by the user\'s role.

**3.1.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Recruitment ⋮ │                                                   |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │                |
|                                                                       |
| │ │ Open │ │ Candidates │ │ Offers │ │                                |
|                                                                       |
| │ │ Positions: 8 │ │ in Pipeline:42│ │ Pending: 3 │ │                 |
|                                                                       |
| │ └──────────────┘ └──────────────┘ └──────────────┘ │                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌────────────────────┐ ┌────────────────────┐ │                     |
|                                                                       |
| │ │ 📊 Dashboard │ │ 📋 Requisitions │ │                              |
|                                                                       |
| │ └────────────────────┘ └────────────────────┘ │                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌─────────────────────────────────────────────────┐ │               |
|                                                                       |
| │ │ Active │ Closed │ Drafts │ │                                      |
|                                                                       |
| │ └─────────────────────────────────────────────────┘ │               |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 🔍 Search by position or department │ │                           |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ All \] \[ In Recruitment \] \[ Hold \] \[ Filled \] │            |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 💼 Senior Software Engineer │ │                                   |
|                                                                       |
| │ │ Sales · 2 vacancies │ │                                           |
|                                                                       |
| │ │ \[IN RECRUITMENT\] 14 candidates · 2 offers │ │                   |
|                                                                       |
| │ │ Opened 12 days ago │ │                                            |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 💼 Marketing Coordinator │ │                                      |
|                                                                       |
| │ │ Marketing · 1 vacancy │ │                                         |
|                                                                       |
| │ │ \[IN RECRUITMENT\] 8 candidates · 1 offer │ │                     |
|                                                                       |
| │ │ Opened 5 days ago │ │                                             |
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
  **KPI Strip**    Three counter cards: \'Open Positions\' (active
                   requisitions in scope), \'Candidates in Pipeline\'
                   (applicants across all active requisitions), \'Offers
                   Pending\' (offer letters in Sent state awaiting
                   candidate response).

  **View           Toggle between Dashboard (Section 5) and Requisitions
  Switcher**       list (default).

  **Tabs**         Three tabs: \'Active\' (default), \'Closed\',
                   \'Drafts\'. Active = state In Recruitment / Hold.
                   Closed = Filled / Cancelled. Drafts = state Draft.

  **Status Filter  Visible inside the Active tab to further narrow by
  Chips**          sub-state. Hidden in Closed and Drafts tabs.

  **Search Bar**   Free-text search by position title or department name.

  **Requisition    Each card shows: position icon, position title (bold),
  Card**           department + number of vacancies, status badge,
                   candidate count, offers count, days since opened. Tap
                   opens R2 (Requisition Detail).

  **+ New Button** Floating action button. Opens Screen R3 (New
                   Requisition Form). Visible only to roles permitted to
                   raise requisitions (Hiring Manager and HR Manager).

  **Empty /        Same patterns as Module 1 Section 6.6.
  Loading /        
  Error**          
  -----------------------------------------------------------------------

**3.1.3 Counter Logic**

  -----------------------------------------------------------------------
  **Counter**        **Logic**
  ------------------ ----------------------------------------------------
  **Open Positions** Count of recruitment requests in \'In Recruitment\'
                     or \'Hold\' state, scoped by role (HR Manager: all;
                     Hiring Manager: own only).

  **Candidates in    Sum of candidates linked to the user\'s visible
  Pipeline**         active requisitions, excluding candidates in
                     terminal states (Hired, Rejected, Withdrawn).

  **Offers Pending** Count of offer letters in \'Sent\' state (awaiting
                     candidate response), within the user\'s visible
                     scope.
  -----------------------------------------------------------------------

**3.2 Screen R2 --- Requisition Detail**

Displays a single recruitment request with its position details, current
pipeline summary, candidate list, and any associated offer letters. This
is the central screen of the module --- most navigation funnels through
here.

**3.2.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Requisition ⤓ ⋮ │                                                 |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 💼 Senior Software Engineer │ │                                   |
|                                                                       |
| │ │ Sales · Riyadh \[IN RECRUITMENT\] │ │                             |
|                                                                       |
| │ │ Ref: REQ/2026/0042 │ │                                            |
|                                                                       |
| │ │ Raised by: Ahmed Al-Rashid · 12 days ago │ │                      |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ PIPELINE SUMMARY │                                                  |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ │                      |
|                                                                       |
| │ │ 14 │ │ 6 │ │ 3 │ │ 2 │ │ 1 │ │                                    |
|                                                                       |
| │ │Apply │ │Screen│ │Inter │ │Offer │ │Hired │ │                      |
|                                                                       |
| │ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘ │                      |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ POSITION DETAILS │                                                  |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Department │ Sales │                                                |
|                                                                       |
| │ Job Title │ Senior Software Engineer │                              |
|                                                                       |
| │ Location │ Riyadh, KSA │                                            |
|                                                                       |
| │ Vacancies │ 2 │                                                     |
|                                                                       |
| │ Salary Range │ AED 18,000 -- 24,000 │                               |
|                                                                       |
| │ Required By │ 30 June 2026 │                                        |
|                                                                       |
| │ Description │ \[ Read more \] │                                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌─────────────────────────────────────────────────┐ │               |
|                                                                       |
| │ │ Candidates │ Offers │ Activity │ │                                |
|                                                                       |
| │ └─────────────────────────────────────────────────┘ │               |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ All \] \[ Applied \] \[ Screening \] \[ Interview \] \[ \... \]  |
| │                                                                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Sarah Ahmed \[INTERVIEW\] │ │                                  |
|                                                                       |
| │ │ sarah.ahmed@example.com │ │                                       |
|                                                                       |
| │ │ Applied 8 days ago · Avg score: 4.2 / 5 │ │                       |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Omar Khalid \[INTERVIEW\] │ │                                  |
|                                                                       |
| │ │ omar.k@example.com │ │                                            |
|                                                                       |
| │ │ Applied 6 days ago · Avg score: 3.8 / 5 │ │                       |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**3.2.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Header**       Back arrow, export icon (PDF of full requisition with
                   watermark), overflow menu (Edit, Hold, Cancel ---
                   visibility per role and state).

  **Header Card**  Position icon, title, department + location, status
                   badge, reference number, requester name, days since
                   opened.

  **Pipeline       Five horizontally-aligned mini-cards showing candidate
  Summary**        count per stage: Applied, Screening, Interview, Offer,
                   Hired. Each card tappable --- drills into the
                   candidate list filtered by that stage.

  **Position       Two-column field/value list. Description field is
  Details**        collapsible --- long descriptions expand on tap.

  **Sub-tabs**     \'Candidates\' (default), \'Offers\', \'Activity\'.
                   Each tab renders a different list below.

  **Candidates     Stage filter chips + candidate cards. Each card shows:
  Tab**            avatar/initials, full name, contact email, applied
                   date, average assessment score (if assessments
                   completed). Tap opens C2 (Candidate Detail).

  **Offers Tab**   List of offer letters generated for this requisition.
                   Each row shows candidate name, offer status, sent
                   date. Tap opens O1 (Offer Detail).

  **Activity Tab** Chronological feed: requisition opened, candidate
                   applied, candidate moved to stage, offer sent, offer
                   accepted/declined, etc. Read-only.

  **Status Badge** Color mapping for requisition states defined in
                   Section 8.
  -----------------------------------------------------------------------

**3.3 Screen R3 --- New Requisition Form**

Form used by Hiring Managers and HR Managers to raise a new recruitment
request.

**3.3.1 Field Specification**

  ---------------------------------------------------------------------------
  **Field**            **Type**     **Required**    **Notes**
  -------------------- ------------ --------------- -------------------------
  **Job Title**        Dropdown /   **Required**    Searchable dropdown
                       Text                         sourced from hr.job.
                                                    Free-text \'Other\'
                                                    option creates a new job
                                                    record (HR Manager only).

  **Department**       Dropdown     **Required**    Auto-populated from
                                                    selected Job Title;
                                                    editable by HR Manager.

  **Number of          Numeric      **Required**    Min 1, max 50.
  Vacancies**                                       

  **Location**         Dropdown     **Required**    List of company locations
                                                    (UAE branches, Riyadh,
                                                    etc.).

  **Employment Type**  Dropdown     **Required**    Options: Full-time,
                                                    Part-time, Contract,
                                                    Internship.

  **Experience Level** Dropdown     Optional        Options: Junior, Mid,
                                                    Senior, Lead, Manager.

  **Salary Range ---   Numeric      Optional        Visible to HR Manager
  Min (AED)**                                       only by default;
                                                    visibility for hiring
                                                    managers configurable.

  **Salary Range ---   Numeric      Optional        Must be ≥ Min.
  Max (AED)**                                       

  **Required By Date** Date         Optional        Target date to fill the
                                                    position.

  **Job Description**  Multi-line   **Required**    Min 50 characters. Rich
                       Text                         text not required in
                                                    Phase 1.

  **Key                Multi-line   Optional        Bulleted list (separated
  Responsibilities**   Text                         by newlines).

  **Required Skills**  Tag Input    Optional        Free-text tags. User
                                                    types and presses
                                                    comma/enter to add.

  **Justification**    Multi-line   **Required**    Why is this position
                       Text                         needed? Used in approval
                                                    review.

  **Replacement For**  Dropdown     Optional        If this is a replacement,
                                                    select the departing
                                                    employee.

  **Attachment**       File         Optional        Detailed JD document, org
                                                    chart, etc.
  ---------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| Salary range fields default to HR-Manager-only visibility on the      |
| requisition list and detail. Hiring Managers see the salary range     |
| only on requisitions they raised themselves. Adjust if your policy    |
| differs.                                                              |
+-----------------------------------------------------------------------+

**3.3.2 Form Layout**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← New Requisition │                                                 |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ POSITION │                                                          |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Job Title \* \[ Search or select\... ▼ \] │                         |
|                                                                       |
| │ Department \* \[ Auto / Select\... ▼ \] │                           |
|                                                                       |
| │ Location \* \[ Select\... ▼ \] │                                    |
|                                                                       |
| │ Vacancies \* \[ 1 \] │                                              |
|                                                                       |
| │ Employment Type \* \[ Full-time ▼ \] │                              |
|                                                                       |
| │ Experience Level \[ Senior ▼ \] │                                   |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ COMPENSATION (HR / Requester only) │                                |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Salary Min (AED) \[ \] │                                            |
|                                                                       |
| │ Salary Max (AED) \[ \] │                                            |
|                                                                       |
| │ Required By \[ DD/MM/YYYY \] │                                      |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ POSITION DESCRIPTION │                                              |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Job Description \* │                                                |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Key Responsibilities │                                              |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Required Skills \[ +Add tag \] │                                    |
|                                                                       |
| │ \[ Java \] \[ Spring Boot \] \[ AWS \] \[ × \] │                    |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ JUSTIFICATION │                                                     |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Justification \* │                                                  |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Replacement For \[ Select employee\... ▼ \] │                       |
|                                                                       |
| │ Attachment \[ 📎 Tap to attach \] │                                 |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ Save Draft \] \[ Submit Request \] │                             |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**4. Candidates & Assessments**

**4.1 Screen C1 --- Candidates List**

Accessed from R2 (via the Candidates sub-tab) or from the global
Candidates entry on R1\'s overflow menu. Lists all candidates within the
user\'s scope, with filtering by stage and search.

**4.1.1 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Stage Filter   Applied, Screening, Interview, Offer, Hired, Rejected,
  Chips**          Withdrawn. Each chip shows count when filtered list is
                   active.

  **Search Bar**   Search by candidate name or email.

  **Sort Options** Newest first (default), Oldest first, Highest score,
                   Lowest score.

  **Candidate      Avatar / initials, full name, contact email, current
  Card**           stage badge, applied date, average assessment score
                   (if any), requisition link (if accessed from global
                   list).

  **Tap Behavior** Opens C2 (Candidate Detail).
  -----------------------------------------------------------------------

**4.2 Screen C2 --- Candidate Detail**

Single candidate view showing profile, attached CV, application history,
assessment scores, and quick links to offer letter (if any).

**4.2.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Candidate ⤓ ⋮ │                                                   |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Sarah Ahmed │ │                                                |
|                                                                       |
| │ │ Senior Software Engineer · Sales │ │                              |
|                                                                       |
| │ │ Ref: CAN/2026/0381 \[INTERVIEW\] │ │                              |
|                                                                       |
| │ │ 📧 sarah@ex.com 📞 +971 50 xxx xxxx │ │                           |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ PROFILE │                                                           |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Source │ LinkedIn │                                                 |
|                                                                       |
| │ Applied On │ 01 May 2026 │                                          |
|                                                                       |
| │ Years Experience │ 6 years │                                        |
|                                                                       |
| │ Current Company │ TechCorp │                                        |
|                                                                       |
| │ Expected Salary │ AED 22,000 │                                      |
|                                                                       |
| │ Notice Period │ 30 days │                                           |
|                                                                       |
| │ CV / Resume │ 📎 sarah-cv.pdf \[ View \] │                          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌─────────────────────────────────────────────────┐ │               |
|                                                                       |
| │ │ Assessments │ Activity │ Notes │ │                                |
|                                                                       |
| │ └─────────────────────────────────────────────────┘ │               |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ASSESSMENTS (Average: 4.2 / 5) │                                    |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ Round 1: Phone Screening Ahmed Al-Rashid │ │                      |
|                                                                       |
| │ │ Score: ★★★★☆ 4.0 / 5 03 May 2026 │ │                              |
|                                                                       |
| │ │ \"Strong communication, good technical basics\" │ │               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ Round 2: Technical Interview Fatima Hassan │ │                    |
|                                                                       |
| │ │ Score: ★★★★☆ 4.4 / 5 06 May 2026 │ │                              |
|                                                                       |
| │ │ \"Solid system design, hands-on coding strong\" │ │               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ + Add Assessment \] │                                            |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌────────────────────────────────────────────────────┐ │            |
|                                                                       |
| │ │ ASSOCIATED OFFER │ │                                              |
|                                                                       |
| │ │ Offer Letter sent 08 May 2026 \[SENT\] │ │                        |
|                                                                       |
| │ │ \[ View Offer \] │ │                                              |
|                                                                       |
| │ └────────────────────────────────────────────────────┘ │            |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**4.2.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Header Card**  Avatar, name, applied position + department, candidate
                   reference, current stage badge, contact email and
                   phone (tap to open mail/dial).

  **Profile        Two-column field/value list with all candidate
  Section**        metadata. CV row has a \'View\' action that opens the
                   file in the device\'s default viewer.

  **Sub-tabs**     Assessments (default), Activity, Notes.

  **Assessments    Shows the average score at the section header. Lists
  Tab**            individual assessment scorecards in chronological
                   order. Each card shows round name, interviewer, score
                   (star rating), date, and a one-line summary. Tap opens
                   A1 (Assessment Detail).

  **+ Add          Opens A2 (Assessment Form). Visible only to users
  Assessment**     included in the candidate\'s interview panel or HR
                   Manager.

  **Activity Tab** Chronological feed: applied, stage moved, assessment
                   added, offer sent, etc.

  **Notes Tab**    Read-only Phase 1: list of internal notes added in
                   Odoo backend.

  **Associated     Shows below the tabs only if an offer letter exists
  Offer Card**     for this candidate. Quick link to O1 (Offer Detail).

  **Overflow       Move to next stage (read-only display in Phase 1; no
  Menu**           action). Reserved for Phase 2 stage-change actions.
  -----------------------------------------------------------------------

**4.3 Screen A1 --- Assessment Detail**

Read-only view of a single completed assessment scorecard. Accessible
from C2\'s Assessments tab.

**4.3.1 Component Specification**

  ---------------------------------------------------------------------------
  **Component**        **Specification**
  -------------------- ------------------------------------------------------
  **Header Card**      Round name (e.g., \'Round 2: Technical Interview\'),
                       candidate name, interviewer name, date completed,
                       overall score.

  **Criteria Scores**  List of evaluation criteria with individual scores
                       (e.g., Technical Knowledge 4/5, Problem Solving 5/5,
                       Communication 4/5, Cultural Fit 4/5). Visual: star
                       rating per row.

  **Strengths**        Read-only text block.

  **Concerns**         Read-only text block.

  **Recommendation**   Single value: Strong Hire / Hire / No Hire / Strong No
                       Hire.

  **Overall Comments** Free-text from interviewer.

  **Edit Action**      Visible only to the original interviewer when the
                       assessment is in Draft state. Read-only once
                       submitted.
  ---------------------------------------------------------------------------

**4.4 Screen A2 --- Assessment Form (Add)**

Form used by an interviewer or panel member to score a candidate after a
screening or interview round.

**4.4.1 Field Specification**

  ---------------------------------------------------------------------------
  **Field**            **Type**     **Required**    **Notes**
  -------------------- ------------ --------------- -------------------------
  **Round / Stage**    Dropdown     **Required**    Options: Phone Screening,
                                                    Technical Interview, HR
                                                    Interview, Final
                                                    Interview, Other (custom
                                                    label).

  **Interview Date**   Date         **Required**    Defaults to today.

  **Technical          Star Rating  **Required**    Tap stars to set rating.
  Knowledge**          (1-5)                        

  **Problem Solving**  Star Rating  **Required**    Tap stars to set rating.
                       (1-5)                        

  **Communication**    Star Rating  **Required**    Tap stars to set rating.
                       (1-5)                        

  **Cultural Fit**     Star Rating  **Required**    Tap stars to set rating.
                       (1-5)                        

  **Strengths**        Multi-line   Optional        Min 0, max 1000 chars.
                       Text                         

  **Concerns**         Multi-line   Optional        Min 0, max 1000 chars.
                       Text                         

  **Recommendation**   Radio Group  **Required**    Strong Hire / Hire / No
                                                    Hire / Strong No Hire.

  **Overall Comments** Multi-line   Optional        Free-text additional
                       Text                         feedback.
  ---------------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| The four scoring criteria (Technical Knowledge, Problem Solving,      |
| Communication, Cultural Fit) are defaults. If your Odoo configuration |
| uses a different set of criteria per round or per job, the form       |
| should pull these dynamically from a backend criteria template.       |
| Confirm whether criteria are fixed or template-driven.                |
+-----------------------------------------------------------------------+

**4.4.2 Form Layout**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Assessment --- Sarah Ahmed │                                      |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Senior Software Engineer · Sales │                                  |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Round / Stage \* \[ Technical Interview ▼ \] │                      |
|                                                                       |
| │ Interview Date \* \[ 09 May 2026 \] │                               |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ SCORE THE CANDIDATE │                                               |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Technical Knowledge \* ★ ★ ★ ★ ☆ │                                  |
|                                                                       |
| │ Problem Solving \* ★ ★ ★ ★ ★ │                                      |
|                                                                       |
| │ Communication \* ★ ★ ★ ★ ☆ │                                        |
|                                                                       |
| │ Cultural Fit \* ★ ★ ★ ★ ☆ │                                         |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ FEEDBACK │                                                          |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Strengths │                                                         |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Concerns │                                                          |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ RECOMMENDATION \* │                                                 |
|                                                                       |
| │ ( ) Strong Hire ( • ) Hire ( ) No Hire ( ) Strong No Hire           |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Overall Comments │                                                  |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ Save Draft \] \[ Submit Assessment \] │                          |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**5. Offer Letters**

Mobile users can view and download offer letters generated by the HR
team. Phase 1 does not include offer letter creation or editing ---
those remain in the Odoo backoffice. The mobile app provides visibility
into offer status and PDF download.

**5.1 Screen O1 --- Offer Letter Detail**

Read-only view of an offer letter. Accessible from R2 (Offers sub-tab),
C2 (Associated Offer card), or a global Offers list.

**5.1.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Offer Letter ⤓ │                                                  |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 📜 Offer Letter │ │                                               |
|                                                                       |
| │ │ Sarah Ahmed · Senior Software Engineer │ │                        |
|                                                                       |
| │ │ Ref: OFR/2026/0089 \[SENT\] │ │                                   |
|                                                                       |
| │ │ Sent: 08 May 2026 · Expires: 15 May 2026 │ │                      |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ OFFER DETAILS │                                                     |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Position │ Senior Software Engineer │                               |
|                                                                       |
| │ Department │ Sales │                                                |
|                                                                       |
| │ Reporting To │ Ahmed Al-Rashid │                                    |
|                                                                       |
| │ Location │ Riyadh, KSA │                                            |
|                                                                       |
| │ Joining Date │ 01 June 2026 │                                       |
|                                                                       |
| │ Employment Type │ Full-time │                                       |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ COMPENSATION (HR Manager only) │                                    |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Basic Salary │ AED 14,000 │                                         |
|                                                                       |
| │ Housing Allowance │ AED 5,000 │                                     |
|                                                                       |
| │ Transport Allowance │ AED 1,500 │                                   |
|                                                                       |
| │ Other Allowances │ AED 1,500 │                                      |
|                                                                       |
| │ Gross Monthly │ AED 22,000 │                                        |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ STATUS TIMELINE │                                                   |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ ● Draft created 05 May 2026 │                                       |
|                                                                       |
| │ ● Sent to candidate 08 May 2026 │                                   |
|                                                                       |
| │ ○ Awaiting response │                                               |
|                                                                       |
| │ ○ Accepted / Declined │                                             |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ATTACHED DOCUMENT │                                                 |
|                                                                       |
| │ 📎 offer_sarah_ahmed.pdf \[ Download with Watermark \] │            |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ Resend \] \[ Mark Expired \] (HR Manager actions) │              |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**5.1.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Header Card**  Offer icon, candidate name, applied position,
                   reference number, current status badge, sent date,
                   expiry date.

  **Offer Details  Two-column field/value list of position-related terms:
  Section**        department, reporting manager, location, joining date,
                   employment type.

  **Compensation   Two-column field/value list of salary breakdown.
  Section**        Visible to HR Manager always; visibility for Hiring
                   Manager configurable per company policy.

  **Status         Vertical step list showing offer journey. States:
  Timeline**       Draft → Sent → Accepted / Declined / Expired.

  **Attached       Link to download the offer letter PDF. The downloaded
  Document**       PDF includes the emp_id watermark of the user
                   generating the download (consistent with Module 1
                   Section 6.5).

  **HR Manager     Resend (re-deliver to candidate), Mark Expired. Both
  Actions**        are placeholders in Phase 1 if backend doesn\'t expose
                   these actions yet --- render as disabled with a
                   tooltip \'Available in Phase 2\'.
  -----------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| Compensation breakdown visibility is HR-Manager-only by default. If   |
| hiring managers in your company should also see the compensation      |
| details on offers they raised, change this rule. Document the         |
| decision in your final answer.                                        |
+-----------------------------------------------------------------------+

**6. Recruitment Dashboard**

The dashboard provides a visual analytical view of recruitment activity.
Accessed by tapping the Dashboard button on the Recruitment Landing
screen (R1). Visible to both Hiring Manager and HR Manager, with HR
Manager seeing aggregated company-wide data and Hiring Manager seeing
scoped data.

**6.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Recruitment Dashboard This Quarter ▼ ⤓ │                          |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │                |
|                                                                       |
| │ │ Open Reqs │ │ Hired (Q) │ │ Time-to-Hire │ │                      |
|                                                                       |
| │ │ 8 │ │ 12 │ │ 28 days │ │                                          |
|                                                                       |
| │ └──────────────┘ └──────────────┘ └──────────────┘ │                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ PIPELINE FUNNEL │                                                   |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ Applied ████████████████████████ 142 │ │                          |
|                                                                       |
| │ │ Screening ████████████████ 76 │ │                                 |
|                                                                       |
| │ │ Interview █████████ 38 │ │                                        |
|                                                                       |
| │ │ Offer ████ 18 │ │                                                 |
|                                                                       |
| │ │ Hired ██ 12 │ │                                                   |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ OPEN REQUISITIONS BY DEPARTMENT (HR Manager only) │                 |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Sales ▆▆▆▆▆▆▆▆▆▆ 3 │                                                |
|                                                                       |
| │ Marketing ▆▆▆▆▆▆ 2 │                                                |
|                                                                       |
| │ Operations ▆▆▆ 1 │                                                  |
|                                                                       |
| │ F&B ▆▆▆▆▆▆▆ 2 │                                                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ AVG TIME PER STAGE │                                                |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Applied → Screening 1.8 days │                                      |
|                                                                       |
| │ Screening → Interview 3.2 days │                                    |
|                                                                       |
| │ Interview → Offer 8.5 days │                                        |
|                                                                       |
| │ Offer → Hired 14.6 days │                                           |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ TOP SOURCES │                                                       |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ 1. LinkedIn 54% ●●●●●●●●●●● │                                       |
|                                                                       |
| │ 2. Referrals 22% ●●●●● │                                            |
|                                                                       |
| │ 3. Job Portals 16% ●●● │                                            |
|                                                                       |
| │ 4. Direct 8% ● │                                                    |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**6.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**      **Specification**
  ------------------ ----------------------------------------------------
  **Period           This Week, This Month, This Quarter (default), This
  Selector**         Year, Custom Range. Affects all KPIs and charts.

  **KPI Cards**      Open Requisitions (count of in-recruitment
                     positions), Hired (count of candidates hired in the
                     period), Time-to-Hire (average days from req opened
                     to candidate hired).

  **Pipeline         Horizontal bar chart showing candidate count at each
  Funnel**           stage. Bars proportional to count. Tap a stage to
                     drill down to the candidate list filtered by that
                     stage.

  **Open             HR Manager only. Horizontal bar chart, one row per
  Requisitions by    department. Tap to drill into requisitions filtered
  Department**       by department.

  **Avg Time per     List showing average duration between consecutive
  Stage**            stages. Used to identify bottlenecks.

  **Top Sources**    Ranked list of candidate sources (LinkedIn,
                     Referrals, Job Portals, Direct). Each row shows
                     percentage and visual bar.

  **Export PDF**     Generates PDF snapshot of the entire dashboard with
                     the user\'s emp_id watermark.
  -----------------------------------------------------------------------

**7. Screen Inventory & Navigation**

**7.1 Screen Inventory**

  -------------------------------------------------------------------------
  **Screen    **Screen Name**            **Audience**   **Purpose**
  ID**                                                  
  ----------- -------------------------- -------------- -------------------
  **R1**      Recruitment Landing        Manager, HR    Main entry, list of
                                         Manager        requisitions, KPIs

  **R2**      Requisition Detail         Manager, HR    Single
                                         Manager        requisition +
                                                        pipeline + sub-tabs

  **R3**      New Requisition Form       Manager, HR    Create a new
                                         Manager        requisition

  **C1**      Candidates List            Manager, HR    Cross-requisition
                                         Manager        candidate browse

  **C2**      Candidate Detail           Manager, HR    Profile +
                                         Manager        assessments + offer
                                                        link

  **A1**      Assessment Detail          Interviewer,   Read-only scorecard
                                         HR Manager     

  **A2**      Assessment Form            Interviewer,   Submit a new
                                         HR Manager     assessment

  **O1**      Offer Letter Detail        Manager, HR    View + PDF download
                                         Manager        

  **D1**      Recruitment Dashboard      Manager, HR    Funnel + KPIs +
                                         Manager        charts
  -------------------------------------------------------------------------

**7.2 Navigation Flow**

+-----------------------------------------------------------------------+
| \[ Main App Home \]                                                   |
|                                                                       |
| │                                                                     |
|                                                                       |
| Tap \'Recruitment\'                                                   |
|                                                                       |
| │                                                                     |
|                                                                       |
| ▼                                                                     |
|                                                                       |
| ┌──────────────┐                                                      |
|                                                                       |
| │ R1 Landing │ ◄── Tab: My / All                                      |
|                                                                       |
| └──────┬───────┘                                                      |
|                                                                       |
| │                                                                     |
|                                                                       |
| ┌─────────────────┼──────────────────┐                                |
|                                                                       |
| ▼ ▼ ▼                                                                 |
|                                                                       |
| \[D1 Dashboard\] \[+ New\] \[R2\]                                     |
|                                                                       |
| │ \[R3 Form\] │                                                       |
|                                                                       |
| │                                                                     |
|                                                                       |
| ┌──────────────────┼──────────────┐                                   |
|                                                                       |
| ▼ ▼ ▼                                                                 |
|                                                                       |
| \[Candidates Tab\] \[Offers Tab\] \[Activity Tab\]                    |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| ▼ ▼                                                                   |
|                                                                       |
| \[C2\] \[O1\]                                                         |
|                                                                       |
| / \\ │                                                                |
|                                                                       |
| ▼ ▼ ▼                                                                 |
|                                                                       |
| \[A1\] \[A2\] (PDF)                                                   |
|                                                                       |
| (New)                                                                 |
+-----------------------------------------------------------------------+

**7.3 Backend API Touchpoints**

  ------------------------------------------------------------------------
  **Capability**     **Used By**                          **Status**
  ------------------ ------------------------------------ ----------------
  **Get requisitions R1                                   To define
  list (scoped)**                                         

  **Get requisition  R2                                   To define
  detail + pipeline                                       
  counts**                                                

  **Submit / save    R3                                   To define
  draft                                                   
  requisition**                                           

  **Get candidates   R2 candidates tab, C1                To define
  per requisition /                                       
  global**                                                

  **Get candidate    C2                                   To define
  detail**                                                

  **Get assessments  C2 assessments tab, A1               To define
  for candidate**                                         

  **Submit / save    A2                                   To define
  draft assessment**                                      

  **Get offer        R2 offers tab, O1                    To define
  letters per                                             
  requisition /                                           
  candidate**                                             

  **Download offer   O1                                   To define
  letter PDF with                                         
  watermark**                                             

  **Get recruitment  D1                                   To define
  dashboard data**                                        
  ------------------------------------------------------------------------

**8. Status Badge Reference**

Recruitment introduces several status types beyond the four-state model
used in Module 1. Backend normalizes Odoo state strings to the labels
below.

**8.1 Requisition States**

  -----------------------------------------------------------------------
  **State**        **Background**   **Text Color**   **Meaning**
  ---------------- ---------------- ---------------- --------------------
  **DRAFT**        #E5E7EB          #374151          Not yet submitted

  **IN             #D6E4F5          #1F3A5F          Open and actively
  RECRUITMENT**                                      sourcing candidates

  **HOLD**         #FFF4D6          #C77700          Temporarily paused

  **FILLED**       #D6F0E2          #2E7D5B          All vacancies hired

  **CANCELLED**    #F5D6DA          #8B2635          Closed without
                                                     hiring
  -----------------------------------------------------------------------

**8.2 Candidate Stages**

  -----------------------------------------------------------------------
  **Stage**        **Background**   **Text Color**   **Meaning**
  ---------------- ---------------- ---------------- --------------------
  **APPLIED**      #E5E7EB          #374151          New application
                                                     received

  **SCREENING**    #D6E4F5          #1F3A5F          Initial review in
                                                     progress

  **INTERVIEW**    #D6E4F5          #4A6B8A          Interview rounds
                                                     underway

  **OFFER**        #FFF4D6          #C77700          Offer extended

  **HIRED**        #D6F0E2          #2E7D5B          Joined the company

  **REJECTED**     #F5D6DA          #8B2635          Not selected

  **WITHDRAWN**    #E5E7EB          #6B7280          Candidate withdrew
  -----------------------------------------------------------------------

**8.3 Offer Letter States**

  -----------------------------------------------------------------------
  **State**        **Background**   **Text Color**   **Meaning**
  ---------------- ---------------- ---------------- --------------------
  **DRAFT**        #E5E7EB          #374151          Created, not yet
                                                     sent

  **SENT**         #FFF4D6          #C77700          Delivered to
                                                     candidate, awaiting
                                                     response

  **ACCEPTED**     #D6F0E2          #2E7D5B          Candidate accepted

  **DECLINED**     #F5D6DA          #8B2635          Candidate declined

  **EXPIRED**      #E5E7EB          #6B7280          Past expiry date
                                                     with no response
  -----------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **Backend Ownership**                                                 |
|                                                                       |
| All state mapping (Odoo state → UI status) is owned by the backend.   |
| The mobile app consumes a normalized \'ui_status\' field from the API |
| response.                                                             |
+-----------------------------------------------------------------------+

**9. Sign-off & Open Items**

**9.1 Assumptions Recap**

Below are all assumptions made in this document. Each marked \'CONFIRM\'
inline above. Mark each as Accepted or Adjusted in your review pass.

  ---------------------------------------------------------------------------
  **\#**   **Assumption**                                        **Status**
  -------- ----------------------------------------------------- ------------
  **1**    Recruitment is HR Manager + Hiring Manager only.      Pending
           Employees do not see this widget.                     

  **2**    Entry point is **Recruitment** inside the **HR       Accepted
           Management hub** (not a separate home widget).       

  **3**    Salary range fields are HR-Manager-only by default.   Pending
           Hiring Managers see salary only on requisitions they  
           raised.                                               

  **4**    Four scoring criteria (Technical Knowledge, Problem   Pending
           Solving, Communication, Cultural Fit) are fixed       
           defaults. Could be template-driven if needed.         

  **5**    Compensation breakdown on offer letter visible to HR  Pending
           Manager only by default.                              

  **6**    Offer letter generation/editing remains in Odoo       Pending
           backoffice. Mobile app is view + download only.       

  **7**    Online tests / quizzes for candidates are out of      Pending
           scope. Mobile assessments are interviewer scorecards  
           only.                                                 
  ---------------------------------------------------------------------------

**9.2 Open Items Owned by Backend**

- Requisition reference number format (e.g., REQ/YYYY/NNNN)

- Candidate reference number format

- Offer letter reference number format

- Status normalization mapping for requisition, candidate, and offer
  states

- Pipeline funnel time-to-stage computation logic and time window

- Offer letter PDF generation: server-side report rendering vs
  client-side

- Whether assessment criteria are fixed or template-driven per round /
  job

- Visibility rules for compensation across roles

**9.3 Next Steps**

  ----------------------------------------------------------------------------
  **Step**   **Action**                         **Owner**
  ---------- ---------------------------------- ------------------------------
  **1**      Review Module 2 specification,     Pandora Tech (Architect)
             mark assumptions as                
             Accepted/Adjusted                  

  **2**      Sign off on Module 2               Pandora Tech (Architect)

  **3**      Continue to remaining modules (3,  Mobile Team / Backend
             4, 5, 6) --- already drafted       

  **4**      Define API contracts after all     Backend Team (Odoo)
             modules signed off                 
  ----------------------------------------------------------------------------

*--- End of Module 2 ---*

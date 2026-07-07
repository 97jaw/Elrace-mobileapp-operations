# Module 2 — Recruitment | Cursor Task File

> **How to use this file:** Read it top to bottom before touching any code. Then read the companion SRD: `Module_2_Recruitment_SRD.docx`. Then start at Task F.0 and work top to bottom. Update task status as you go. Never skip ahead.

---

## 0. About This Module

You are extending an **existing Flutter mobile application** for **Pandora Tech LLC**, integrated with **Odoo 14 ERP**. This task file covers **Module 2: Recruitment** only.

### What this module does
Hiring Managers raise job requisitions (recruitment requests). HR Managers and hiring managers track candidates through pipeline stages, complete interview assessment scorecards, and view/download offer letters. **Employees do not have access to this module.**

### Three sub-modules
1. **Recruitment Requests** — job requisitions
2. **Candidates & Assessments** — pipeline tracking and interviewer scorecards
3. **Offer Letters** — view and PDF download (no creation/editing in mobile)

---

## 1. Critical Rules (NEVER violate these)

| Rule | Reason |
|------|--------|
| Read the SRD section before coding | SRD is source of truth |
| Never invent fields | If not in SRD, doesn't exist |
| Never hardcode colors/strings/spacing | Use design tokens |
| Reuse shared widgets | Check `/lib/core/widgets/` first |
| No `!` (bang) without justification | Null safety |
| Never read raw Odoo state strings | Use normalized `ui_status` only |
| One task = one commit | `feat(recruitment): <TASK_ID> ... — SRD §<section>` |
| Empty / Loading / Error states mandatory | Every list and detail |
| **Employees have NO access to this module** | Hide the entry point if user is not HR Manager / Manager / PM |

---

## 2. Roles & View Selection

| Boolean Flag | View | Scope |
|------|------|-------|
| `is_hr_manager` | HR Manager | All requisitions, candidates, offers — company-wide. Department filter enabled. |
| `is_management` | Hiring Manager | Own raised requisitions + candidates assigned to them as interviewers. |
| `is_pm` | Hiring Manager | Same as is_management. |
| None of above | **No access** | Recruitment action hidden in HR Management hub |

If multiple flags true, **`is_hr_manager` takes precedence**.

---

## 3. ⚠️ DEVELOPMENT-ONLY: Role Toggle

The dev role-toggle from Module 1 (Task F.4) extends to this module too. On the **HR Management hub** entry to Recruitment (and on R1 AppBar as needed):

- 👨‍💼 **Manager icon** → Hiring Manager view
- 💼 **HR Manager icon** → HR Manager view
- 👤 **User icon** → "No Access" placeholder screen (since employees can't enter this module)

**Final release behavior:** Remove icons, use dynamic role detection. TODO comment marker:

```dart
// TODO(release): Remove dev role toggle. Replace with dynamic role
// detection from login API booleans (is_hr_manager, is_management, is_pm).
// Reference: Module 2 TASKS.md §3.
```

If the role toggle was already implemented in Module 1's F.4 task, **reuse the same component** — do not duplicate.

---

## 4. Design System (inherits from Module 1 — DO NOT redefine)

All design tokens (colors, typography, spacing) are defined during **Module 1 Task F.1**. This module **reuses them as-is**.

### Status Badge Colors — Module 2 specific

#### Requisition States
| State | Background | Text |
|-------|-----------|------|
| DRAFT | `#E5E7EB` | `#374151` |
| IN RECRUITMENT | `#D6E4F5` | `#1F3A5F` |
| HOLD | `#FFF4D6` | `#C77700` |
| FILLED | `#D6F0E2` | `#2E7D5B` |
| CANCELLED | `#F5D6DA` | `#8B2635` |

#### Candidate Stages
| Stage | Background | Text |
|-------|-----------|------|
| APPLIED | `#E5E7EB` | `#374151` |
| SCREENING | `#D6E4F5` | `#1F3A5F` |
| INTERVIEW | `#D6E4F5` | `#4A6B8A` |
| OFFER | `#FFF4D6` | `#C77700` |
| HIRED | `#D6F0E2` | `#2E7D5B` |
| REJECTED | `#F5D6DA` | `#8B2635` |
| WITHDRAWN | `#E5E7EB` | `#6B7280` |

#### Offer Letter States
| State | Background | Text |
|-------|-----------|------|
| DRAFT | `#E5E7EB` | `#374151` |
| SENT | `#FFF4D6` | `#C77700` |
| ACCEPTED | `#D6F0E2` | `#2E7D5B` |
| DECLINED | `#F5D6DA` | `#8B2635` |
| EXPIRED | `#E5E7EB` | `#6B7280` |

Add these mappings to `/lib/core/theme/hr_module_status_colors.dart` (or extend the HR `StatusBadge` / shared theme) as separate map functions per state type, or extend the widget to accept a state-type parameter.

---

## 5. Folder Structure

On your own be professional about it 

---

## 6. Module Roadmap

| Phase | Tasks | Why |
|-------|-------|-----|
| **Foundation (F)** | F.0 → F.2 | Module-specific shared widgets and state colors |
| **Requisitions (R)** | R1 → R2 → R3 | Landing, detail, then create form |
| **Candidates (C)** | C1 → C2 | List, then detail (referenced from R2) |
| **Assessments (A)** | A1 → A2 | Read scorecard, then create one |
| **Offers (O)** | O1 | Read-only with PDF download |
| **Dashboard (D)** | D1 | After other screens exist (drill-downs) |
| **Polish (P)** | P1 → P3 | Verification, sign-off |

### Module screens summary

| ID | Screen | SRD Section | Audience |
|----|--------|-------------|----------|
| R1 | Recruitment Landing | §3.1 | Hiring Manager, HR Manager |
| R2 | Requisition Detail | §3.2 | Hiring Manager, HR Manager |
| R3 | New Requisition Form | §3.3 | Hiring Manager, HR Manager |
| C1 | Candidates List | §4.1 | Hiring Manager, HR Manager |
| C2 | Candidate Detail | §4.2 | Hiring Manager, HR Manager |
| A1 | Assessment Detail | §4.3 | Interviewer, HR Manager |
| A2 | Assessment Form | §4.4 | Interviewer, HR Manager |
| O1 | Offer Letter Detail | §5.1 | Hiring Manager, HR Manager |
| D1 | Recruitment Dashboard | §6 | Hiring Manager, HR Manager |

---

## 7. Functional Knowledge

### 7.1 Requisition lifecycle
`Draft → In Recruitment → (Hold) → Filled / Cancelled`

### 7.2 Candidate pipeline stages
`Applied → Screening → Interview → Offer → Hired`
With terminal branches: `Rejected` and `Withdrawn`

### 7.3 Pipeline summary on R2
Five mini-cards showing candidate count per stage. Each tappable — drills into C1 filtered by that stage.

### 7.4 Counter logic (R1 KPI strip)

| Counter | Logic |
|---------|-------|
| Open Positions | Count of requisitions where ui_status IN (IN_RECRUITMENT, HOLD), scoped to role |
| Candidates in Pipeline | Sum of candidates linked to user's visible active requisitions, excluding HIRED, REJECTED, WITHDRAWN |
| Offers Pending | Count of offer letters where ui_status = SENT, in user's visible scope |

### 7.5 Salary visibility rules (assumption)

| User | Sees salary on requisitions |
|------|----------------------------|
| HR Manager | All requisitions |
| Hiring Manager | Only requisitions they raised themselves |
| Anyone else | Hidden |

This is the default per SRD §3.3.1 assumption #3. If architect adjusts, update here.

### 7.6 Offer letter compensation visibility (assumption)
- HR Manager sees full breakdown
- Hiring Manager: hidden by default (per SRD §5.1.2 assumption #5)

### 7.7 Assessment scoring
- 5-point star rating per criterion
- Default 4 criteria: **Technical Knowledge, Problem Solving, Communication, Cultural Fit**
- Recommendation field: Strong Hire / Hire / No Hire / Strong No Hire
- Average score = mean of all completed assessments per candidate

### 7.8 Assessment edit lock
Assessments are editable only by the original interviewer while in **Draft** state. Once submitted, read-only.

### 7.9 Offer letter PDF download
Mobile is **view + download only**. Generation happens in Odoo backoffice. Download includes emp_id watermark of the user generating the download (not the candidate).

---

## 8. API Conventions

Same as Module 1 §8. Mock all responses for Phase 1. Mark with TODO(backend) comments. The backend normalizes all state strings to `ui_status`.

---

## 9. Tasks (work top to bottom)

> **Status legend:** `[TODO]` `[IN_PROGRESS]` `[DONE]` `[BLOCKED]` `[NEEDS_REVIEW]`

---

### Phase 0 — Foundation

#### `[TODO]` F.0 — Verify Module 1 foundation is complete
Before starting this module, verify:
- Theme tokens exist 
- Shared widgets exist  KpiCounterCard, FilterChipRow, StatusBadge, EmployeeInfoCard, SearchBar, DetailRow, StatusTimeline
- Networking layer exists 
- Role provider + dev toggle exists 
- PDF watermark utility exists 

If any are missing, **stop and complete Module 1 first**. Do not duplicate work.

#### `[TODO]` F.1 — Extend StatusBadge for recruitment states
- Open `/lib/core/theme/hr_module_status_colors.dart`
- Add three new state-color maps: `requisitionStateColors`, `candidateStageColors`, `offerStateColors`
- Each map: state-string → `{bg: Color, text: Color}`
- Color values per §4 of this file
- Update StatusBadge widget to accept a `stateType` enum: `request`, `requisition`, `candidate`, `offer`
- **Definition of done:** Badge correctly renders all 17 states across the four state types

#### `[TODO]` F.2 — Module-specific shared widgets


1. **`star_rating_input.dart`** — interactive 5-star rating, onChange callback, supports half-star (optional), accessible
2. **`star_rating_display.dart`** — read-only star rating display, takes 0-5 value
3. **`tag_input.dart`** — chip-based tag entry, types comma or enter to add, X to remove
4. **`pipeline_summary.dart`** — 5 mini-counter cards (Applied / Screening / Interview / Offer / Hired), each tappable
5. **`candidate_card.dart`** — avatar, name, email, stage badge, applied date, avg score (if any), optional requisition link
6. **`pipeline_funnel_chart.dart`** — horizontal bar funnel with 5 stages, proportional width, tappable bars

**Definition of done:** All widgets compile, render in a sandbox, follow design system.

---

### Phase 1 — Requisitions

#### `[TODO]` R1 — Recruitment Landing
- **SRD section:** §3.1
- **Wireframe:** §3.1.1
- **Component spec:** §3.1.2
- **Counter logic:** §3.1.3 + §7.4 of this file
- **Navigation:** R1 is opened **from the HR Management hub** only (SRD §2.1). Add a hub action (tile, list row, or overflow item) on `HrEmployeeLandingScreen` / `HrManagerLandingScreen` (or shared hub shell), visible only when the user has recruitment access per §2.

**Steps:**
1. Read SRD §3.1 in full
2. Create `requisitions_provider.dart` — AsyncNotifier returning `List<Requisition>` with mock data (8-10 sample records mixing all states)
3. Create `requisition_model.dart` with fields: `id, referenceNumber, jobTitle, department, location, vacancies, candidateCount, offerCount, uiStatus, raisedBy, openedAt`
4. Create `r1_landing_screen.dart`:
   - AppBar: 'Recruitment' + dev role toggle
   - **If user is Employee (no manager flags), show 'No Access' placeholder and back navigation**
   - KPI strip: Open Positions / Candidates in Pipeline / Offers Pending
   - View switcher: Dashboard | Requisitions
   - Tabs: Active (default) | Closed | Drafts
   - Status filter chips inside Active tab
   - Search bar
   - List of requisition cards (use `RequestCard` shared widget or extend it)
   - + New FAB → opens R3
5. Tap card → R2

**Definition of done:**
- All states render with mock data
- Tabs filter correctly
- + New FAB visible to all roles with module access
- 'No Access' shown for employees

**Commit:** `feat(recruitment): R1 landing — SRD §3.1`

---

#### `[TODO]` R2 — Requisition Detail
- **SRD section:** §3.2
- **Wireframe:** §3.2.1
- **Component spec:** §3.2.2

**Steps:**
1. Read SRD §3.2 in full
2. Build requisition detail provider (AsyncNotifier with id parameter)
3. Mock data: include 14 sample candidates per requisition spread across pipeline stages
4. Create `r2_requisition_detail_screen.dart`:
   - AppBar: 'Requisition' + export icon (PDF) + overflow menu (Edit, Hold, Cancel — visibility per role/state)
   - Header card: position icon, title, dept+location, status badge, ref no., requester, days since opened
   - Pipeline Summary (use F.2 widget) — 5 tappable mini-cards
   - Position Details: two-column DetailRow list. Description collapsible.
   - Sub-tabs: Candidates (default) | Offers | Activity
   - Candidates tab: stage filter chips + list of `candidate_card` widgets
   - Offers tab: list of offer letter rows, tap → O1
   - Activity tab: chronological feed (mock entries)
5. Salary visibility: hide salary range from Hiring Manager unless they raised it (§7.5)

**Definition of done:**
- Pipeline summary cards drill into Candidates tab filtered by stage
- All sub-tabs render with mock data
- Salary visibility rule honored

**Commit:** `feat(recruitment): R2 requisition detail — SRD §3.2`

---

#### `[TODO]` R3 — New Requisition Form
- **SRD section:** §3.3
- **Field spec:** §3.3.1
- **Wireframe:** §3.3.2

**Fields:**
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| Job Title | Searchable dropdown | ✓ | Source: hr.job (mock list) |
| Department | Dropdown | ✓ | Auto-fill from job title |
| Number of Vacancies | Numeric 1-50 | ✓ | |
| Location | Dropdown | ✓ | UAE branches + Riyadh |
| Employment Type | Dropdown | ✓ | Full-time / Part-time / Contract / Internship |
| Experience Level | Dropdown | — | Junior / Mid / Senior / Lead / Manager |
| Salary Min (AED) | Numeric | — | HR Manager visible always |
| Salary Max (AED) | Numeric | — | Must be ≥ Min |
| Required By Date | Date | — | |
| Job Description | Multi-line, min 50 chars | ✓ | |
| Key Responsibilities | Multi-line | — | |
| Required Skills | Tag input (use F.2 tag_input) | — | |
| Justification | Multi-line | ✓ | |
| Replacement For | Employee dropdown | — | |
| Attachment | File | — | |

**Steps:**
1. Read SRD §3.3 in full
2. Build form using existing `form_field_wrapper.dart` from Module 1
3. Section dividers: POSITION / COMPENSATION / POSITION DESCRIPTION / JUSTIFICATION
4. Validation: client-side first, inline errors
5. Save Draft + Submit Request buttons
6. On submit: mock API, success toast 'Requisition submitted — Ref: REQ/2026/NNNN', return to R1

**Commit:** `feat(recruitment): R3 new requisition form — SRD §3.3`

---

### Phase 2 — Candidates

#### `[TODO]` C1 — Candidates List
- **SRD section:** §4.1
- **Component spec:** §4.1.1

**Steps:**
1. Read SRD §4.1 in full
2. Reachable from R2 (Candidates sub-tab) AND as global entry from R1's overflow menu
3. Stage filter chips at top
4. Search by candidate name or email
5. Sort options: Newest / Oldest / Highest score / Lowest score
6. List of `candidate_card` widgets — when accessed globally, include requisition link
7. Tap card → C2

**Commit:** `feat(recruitment): C1 candidates list — SRD §4.1`

---

#### `[TODO]` C2 — Candidate Detail
- **SRD section:** §4.2
- **Wireframe:** §4.2.1
- **Component spec:** §4.2.2

**Steps:**
1. Read SRD §4.2 in full
2. Mock candidate detail with 2 completed assessments and 1 sent offer
3. Create `c2_candidate_detail_screen.dart`:
   - Header card: avatar, name, applied position, ref, stage badge, contact (tap to mail/dial)
   - Profile section: source, applied date, years experience, current company, expected salary, notice period, CV/resume row with View action
   - Sub-tabs: Assessments (default) | Activity | Notes
   - Assessments tab: average score header + list of assessment cards (each card → A1) + '+ Add Assessment' button → A2
   - Notes tab: read-only mail.thread display
   - Associated Offer card (below tabs, only if offer exists) → O1
   - Overflow menu: 'Move to next stage' (disabled placeholder for Phase 2)

**Commit:** `feat(recruitment): C2 candidate detail — SRD §4.2`

---

### Phase 3 — Assessments

#### `[TODO]` A1 — Assessment Detail
- **SRD section:** §4.3
- **Component spec:** §4.3.1

**Steps:**
1. Read SRD §4.3 in full
2. Read-only view of one assessment scorecard
3. Header card: round name, candidate name, interviewer, date, overall score
4. Criteria scores section: 4 rows with star rating displays (use F.2 widget)
5. Strengths (read-only text block)
6. Concerns (read-only text block)
7. Recommendation pill (Strong Hire / Hire / No Hire / Strong No Hire — color per recommendation)
8. Overall comments
9. Edit button: visible only if current user is original interviewer AND assessment is in Draft state

**Commit:** `feat(recruitment): A1 assessment detail — SRD §4.3`

---

#### `[TODO]` A2 — Assessment Form
- **SRD section:** §4.4
- **Field spec:** §4.4.1
- **Wireframe:** §4.4.2

**Fields:**
| Field | Type | Required |
|-------|------|----------|
| Round / Stage | Dropdown (Phone Screening / Technical / HR / Final / Other) | ✓ |
| Interview Date | Date, default today | ✓ |
| Technical Knowledge | Star rating 1-5 (use F.2 widget) | ✓ |
| Problem Solving | Star rating 1-5 | ✓ |
| Communication | Star rating 1-5 | ✓ |
| Cultural Fit | Star rating 1-5 | ✓ |
| Strengths | Multi-line, 0-1000 | — |
| Concerns | Multi-line, 0-1000 | — |
| Recommendation | Radio group (Strong Hire / Hire / No Hire / Strong No Hire) | ✓ |
| Overall Comments | Multi-line | — |

**Steps:**
1. Read SRD §4.4 in full
2. Sections: round/date / SCORE THE CANDIDATE / FEEDBACK / RECOMMENDATION
3. Save Draft + Submit Assessment buttons
4. On submit: mock API, return to C2 with new assessment in list

**Commit:** `feat(recruitment): A2 assessment form — SRD §4.4`

---

### Phase 4 — Offers

#### `[TODO]` O1 — Offer Letter Detail
- **SRD section:** §5.1
- **Wireframe:** §5.1.1
- **Component spec:** §5.1.2

**Steps:**
1. Read SRD §5.1 in full
2. Header card: offer icon, candidate name, position, ref, status badge, sent date, expiry date
3. Offer Details section: position, department, reporting manager, location, joining date, employment type
4. Compensation section: salary breakdown (visible only to HR Manager per §7.6)
5. Status Timeline: Draft → Sent → Accepted/Declined/Expired
6. Attached Document: download button using PDF watermark utility (manager's emp_id)
7. HR Manager actions: Resend / Mark Expired (placeholder buttons disabled with 'Available in Phase 2' tooltip)

**Commit:** `feat(recruitment): O1 offer letter detail — SRD §5.1`

---

### Phase 5 — Dashboard

#### `[TODO]` D1 — Recruitment Dashboard
- **SRD section:** §6
- **Wireframe:** §6.1
- **Component spec:** §6.2

**Steps:**
1. Read SRD §6 in full
2. Period selector: This Week / This Month / This Quarter (default) / This Year / Custom
3. KPI cards: Open Reqs / Hired (period) / Time-to-Hire (avg days)
4. Pipeline funnel chart (use F.2 widget) — taps drill into C1 by stage
5. Open Requisitions by Department horizontal bar (HR Manager only)
6. Avg Time per Stage list (Applied → Screening → Interview → Offer → Hired)
7. Top Sources ranked list with bars (LinkedIn / Referrals / etc.)
8. PDF export button — dashboard snapshot with emp_id watermark

**Commit:** `feat(recruitment): D1 dashboard — SRD §6`

---

### Phase 6 — Polish & Verification

#### `[TODO]` P1 — Cross-screen verification
- Navigate every flow with each role (Hiring Manager / HR Manager)
- Verify Employee role sees 'No Access' on R1
- Verify all empty/loading/error states
- Verify salary visibility rules (§7.5)
- Verify offer letter compensation visibility (§7.6)

#### `[TODO]` P2 — Component reuse audit
- Check no duplicate widgets created
- All shared widgets imported via package import
- All status badges use centralized color maps

#### `[TODO]` P3 — Module 2 sign-off
- `flutter analyze` clean
- All widget tests pass
- Screenshots of every screen for stakeholder review
- Decisions log §10 updated

---

## 10. Decisions Log

```
[2026-05-10] Navigation — Decision: Recruitment entry is **inside the HR Management hub** only (no separate app-home tile). Rationale: Stakeholder direction; aligns with Module 1 hub pattern (`HrManagementEntryScreen` / employee & manager HR flows).
```

(Initially empty — fill as you go)

---

## 11. Open Items / Questions for Architect

(Initially empty)

Note: SRD §9.1 lists 7 assumptions awaiting architect confirmation. Implement based on the documented defaults; track any deviations here.

---

## 12. Definition of Module Complete

- [ ] All tasks marked `[DONE]`
- [ ] `flutter analyze` passes
- [ ] All shared widgets reused (no duplicates)
- [ ] PDF export with watermark works on R2, O1, D1
- [ ] Dev role toggle visible and functional
- [ ] Employee user gets 'No Access' on R1
- [ ] All TODO(release) and TODO(backend) comments in place
- [ ] Screenshots captured
- [ ] Decisions log §10 reflects choices

— End of Module 2 Task File —

# Module 3 — Performance Evaluation | Cursor Task File

> **How to use this file:** Read top to bottom before coding. Read companion SRD: `Module_3_Performance_Evaluation_SRD.docx`. Start at F.0 and work top to bottom. Update task status as you go.

---

## 0. About This Module

You are extending an **existing Flutter mobile application** for **Pandora Tech LLC**, integrated with **Odoo 14 ERP**. This task file covers **Module 3: Performance Evaluation** only.

### What this module does
Periodic employee performance reviews — self-assessment, manager assessment, KPI/goals tracking with target vs achieved, competency ratings, narrative feedback, and final scoring. All three roles (Employee, Manager, HR Manager) have distinct experiences.

### Key concept
A single evaluation moves through states: Goal Setting → Self-Assessment → Manager Assessment → HR Review → Closed. Mobile app renders read-only or write UI per state and per role.

---

## 1. Critical Rules (NEVER violate these)

| Rule | Reason |
|------|--------|
| Read SRD section before coding | SRD is source of truth |
| Never invent fields | If not in SRD, doesn't exist |
| Never hardcode colors/strings/spacing | Use design tokens |
| Reuse shared widgets | Check `/lib/core/widgets/` first |
| No `!` (bang) without justification | Null safety |
| Never read raw Odoo state strings | Use `ui_status` only |
| One task = one commit | `feat(performance): <TASK_ID> ... — SRD §<section>` |
| Empty / Loading / Error states mandatory | Every list and detail |
| **Cycles configured in Odoo backoffice** | Mobile does NOT create cycles |
| **Acknowledgement is read-only display in Phase 1** | Action button is Phase 2 |

---

## 2. Roles & View Selection

| Boolean | View | Scope |
|---------|------|-------|
| `is_hr_manager` | HR Manager | All evaluations company-wide. Calibration view. |
| `is_management` | Manager | Own + evaluations conducted for direct reports |
| `is_pm` | Manager | Own + evaluations for project team |
| None | Employee | Own evaluations only |

If multiple flags true, **`is_hr_manager` takes precedence**.

---

## 3. ⚠️ DEVELOPMENT-ONLY: Role Toggle

Reuse the same dev role-toggle component from Module 1 Task F.4. On the Performance widget entry point, show:

- 👤 **User icon** → Employee view (E1)
- 👨‍💼 **Manager icon** → Manager view (M1)
- 💼 **HR Manager icon** → HR Manager view (M1 with extended scope)

**Final release behavior:** Remove icons, use dynamic role detection. TODO marker:

```dart
// TODO(release): Remove dev role toggle. Replace with dynamic role
// detection from login API booleans (is_hr_manager, is_management, is_pm).
// Reference: Module 3 TASKS.md §3.
```

If toggle was implemented in Module 1's F.4, **reuse it** — do not duplicate.

---

## 4. Design System (inherits from Module 1)

All design tokens (colors, typography, spacing) are defined during Module 1 Task F.1. **Reuse as-is.**

### Status Badge Colors — Module 3 specific (Evaluation States)

Add to `/lib/core/theme/status_colors.dart`:

| State | Background | Text | Meaning |
|-------|-----------|------|---------|
| GOAL SETTING | `#E5E7EB` | `#374151` | KPIs being defined |
| AWAITING SELF-ASSESSMENT | `#FFF4D6` | `#C77700` | Employee needs to fill |
| AWAITING MANAGER ASSESSMENT | `#D6E4F5` | `#1F3A5F` | Manager needs to evaluate |
| HR REVIEW | `#D6E4F5` | `#4A6B8A` | HR Manager review |
| CLOSED | `#D6F0E2` | `#2E7D5B` | Final, no edits |

Final score band colors (descriptive labels):

| Score Range | Label | Color |
|-------------|-------|-------|
| 4.5 – 5.0 | Outstanding | success `#2E7D5B` |
| 3.5 – 4.4 | Exceeds | secondary `#4A6B8A` |
| 2.5 – 3.4 | Meets | primary `#1F3A5F` |
| 1.5 – 2.4 | Partially Meets | warning `#C77700` |
| 1.0 – 1.4 | Below Expectations | danger `#8B2635` |

---

## 5. Folder Structure

```
On your own be professional about it 

---

## 6. Module Roadmap

| Phase | Tasks | Why |
|-------|-------|-----|
| **Foundation (F)** | F.0 → F.2 | Module-specific shared widgets |
| **Employee (E)** | E1 → E2 | Landing + dual-mode detail/form screen |
| **Manager (M)** | M1 → M2 → M3 | Landing, evaluation form, read-only detail |
| **Dashboard (D)** | D1 | After M screens (drill-downs) |
| **HR Manager (H)** | H1 | Extended views on top of Manager screens |
| **Polish (P)** | P1 → P3 | Verification, sign-off |

### Module screens summary

| ID | Screen | SRD Section | Audience | Mode |
|----|--------|-------------|----------|------|
| E1 | My Performance Landing | §3.1 | Employee, Manager (in 'My Own'), HR Manager | Read |
| E2 | Evaluation Detail / Self-Assessment | §3.2 | Employee | Read or Write (state-driven) |
| M1 | Manager Performance Landing | §4.1 | Manager, HR Manager | Read + actions |
| M2 | Manager Evaluation Form | §4.2 | Manager, HR Manager | Write |
| M3 | Evaluation Detail (Manager Read) | — | Manager, HR Manager | Read |
| D1 | Performance Dashboard | §5 | Manager, HR Manager | Read |

---

## 7. Functional Knowledge

### 7.1 Evaluation lifecycle

`Goal Setting → Self-Assessment → Manager Assessment → (HR Review) → Closed`

| State | Owner | Mobile Behavior |
|-------|-------|-----------------|
| Goal Setting | Manager + Employee | KPIs visible read-only (set in backoffice in Phase 1) |
| Self-Assessment | Employee | Form opens for employee. Manager sees 'Awaiting Self-Assessment' |
| Manager Assessment | Manager | Form opens for manager. Self-assessment values shown read-only as context |
| HR Review | HR Manager | Read-only for employee + manager |
| Closed | — | Read-only for everyone. Final score visible. PDF export available. |

### 7.2 Evaluation structure

Each evaluation contains:
- **Header:** cycle, period, employee, evaluator, state
- **KPIs / Goals:** list with target / achieved / weight (%) / rating
- **Competencies:** list with rating per competency
- **Self-Assessment:** employee narrative answers (achievements, challenges, dev needs)
- **Manager Assessment:** manager rating + narrative
- **Final Score:** computed by backend (weighted avg)
- **Comments / Feedback**
- **Acknowledgement:** read-only display in Phase 1

### 7.3 Scoring scale (SRD assumption #2)

5-point scale for both KPIs and competencies:
- 1 = Below Expectations
- 2 = Partially Meets
- 3 = Meets Expectations
- 4 = Exceeds
- 5 = Outstanding

Final score = weighted average computed by backend.

If your Odoo configuration uses a different scale, the form must adapt to a backend-supplied scale definition. For now, hardcode the 5-point scale and mark with TODO comment.

### 7.4 Standard competencies (SRD assumption #4)

Default 5 competencies:
1. Communication
2. Leadership
3. Technical Skills
4. Teamwork
5. Problem Solving

Treat as defaults but allow the model to accept any list from the backend (do not hardcode the list in UI logic).

### 7.5 KPI structure

Each KPI has:
- Title
- Weight (%)
- Target value (read-only, set during goal setting)
- Achieved value (employee fills during self-assessment)
- Self-rating (1-5 stars)
- Self-note
- Manager rating (1-5 stars)
- Manager note
- Final rating (computed)

### 7.6 Provisional final score (M2 form)

Live-updated on the manager evaluation form as ratings change. Backend computes; mobile displays. Visual treatment matches the closed-mode final score block.

### 7.7 Performance trend (E1)

Line chart of final scores across past closed evaluations. X-axis: cycle/year. Y-axis: 1-5.

### 7.8 KPI logic for M1

| Counter | Source |
|---------|--------|
| Pending My Action | Count of evaluations in 'Awaiting Manager Assessment' state where current user is manager |
| Team Avg Score | Mean final score across closed evaluations in current cycle |
| Cycle Progress | % of team evaluations closed in current cycle |

---

## 8. API Conventions

Same as Module 1 §8. Mock all responses for Phase 1. Mark with TODO(backend) comments. Backend computes provisional and final scores.

---

## 9. Tasks (work top to bottom)

> **Status legend:** `[TODO]` `[IN_PROGRESS]` `[DONE]` `[BLOCKED]` `[NEEDS_REVIEW]`

---

### Phase 0 — Foundation

#### `[TODO]` F.0 — Verify Module 1 foundation
Same checklist as Module 2 F.0. If anything missing, complete Module 1 first.

#### `[TODO]` F.1 — Extend StatusBadge for evaluation states
- Add evaluation state colors to `/lib/core/theme/status_colors.dart` per §4 of this file
- Add final score band colors per §4

#### `[TODO]` F.2 — Module-specific shared widgets



1. **`evaluation_header_card.dart`** — cycle name, period, manager name, state badge. In closed mode, embeds final score block.
2. **`kpi_goal_card.dart`** — title, weight, target, achieved (input field in form mode, read-only in display mode), star rating, notes. Two modes: form / display
3. **`competency_row.dart`** — competency name + star rating. Two modes: form (interactive) / read (display only). Comparison mode (3-column: self / manager / final)
4. **`final_score_block.dart`** — large prominent display of score + descriptive label. Color-coded by score band per §4.
5. **`progress_stepper.dart`** — horizontal step indicator (KPIs → Comp → Notes → Submit), tappable steps, completed step indicators
6. **`score_distribution_chart.dart`** — horizontal bar chart of employee count per score band
7. **`competency_avg_chart.dart`** — per-competency team average with progress-bar visualization
8. **`performance_trend_chart.dart`** — line chart of final scores across cycles

Reuse `star_rating_input.dart` and `star_rating_display.dart` from Module 2 if already built. If not, build them here and place in `/lib/core/widgets/` (they are cross-module shared widgets).

**Definition of done:** All widgets compile, render in sandbox, follow design system.

---

### Phase 1 — Employee Screens

#### `[TODO]` E1 — My Performance Landing
- **SRD section:** §3.1
- **Wireframe:** §3.1.1
- **Component spec:** §3.1.2

**Steps:**
1. Read SRD §3.1 in full
2. AsyncNotifier returning current cycle + past evaluations (mock 3-4 records)
3. Create `e1_landing_screen.dart`:
   - AppBar: 'My Performance' + dev role toggle
   - **Current Evaluation Card** (prominent, top): cycle name, period, state badge, due-by countdown, primary action button (text varies by state):
     - 'Awaiting Self-Assessment' → 'Start Self-Assessment'
     - In progress → 'Continue Self-Assessment'
     - 'Awaiting Manager Assessment' → 'View Manager Assessment'
     - 'Closed' → 'View Final Evaluation'
   - If no active cycle: muted card 'No active evaluation cycle'
   - **Performance Trend Chart** (use F.2 widget) — taps drill into past evaluation
   - **Past Evaluations List** — cards: cycle name, final score, descriptive label, close date. Tap → E2 in read mode.
4. Empty state: 'You don't have any evaluations yet. Your manager will set your goals at the start of the next cycle.'

**Commit:** `feat(performance): E1 my performance landing — SRD §3.1`

---

#### `[TODO]` E2 — Evaluation Detail / Self-Assessment Form (DUAL MODE)
- **SRD section:** §3.2
- **Wireframe (form mode):** §3.2.1
- **Wireframe (read mode):** §3.2.2
- **Component spec:** §3.2.3

**This is the most complex screen in the module.** It has two modes:

**Form mode** — when state = 'Awaiting Self-Assessment' for the current employee:
- Header card with state badge (no final score)
- Progress stepper (KPIs → Comp → Notes → Submit)
- KPI cards in form mode (each: target read-only, achieved input, self-rating star input, notes input)
- Competencies in form mode (star rating inputs)
- Narrative text areas: Top Achievements (required), Challenges Faced (required), Development Needs (optional)
- Save Draft + Submit Self-Assessment buttons
- Auto-save every 30 seconds

**Read mode** — when state is anything else:
- Header card with state badge AND final score block (if Closed)
- KPIs as 3-column comparison (Self / Manager / Final)
- Competencies as 3-column comparison
- Manager's Feedback (read-only text)
- Your Acknowledgement section (read-only display: 'Acknowledged on date' or 'Pending acknowledgement')
- Export PDF action in header (with emp_id watermark)

**Steps:**
1. Read SRD §3.2 in full
2. AsyncNotifier with evaluation ID
3. Create `e2_evaluation_screen.dart`:
   - Determine mode from evaluation state
   - Render appropriate sections per mode
4. Implement auto-save with debounce (30 sec timer)
5. Implement form validation: all KPI ratings + all competency ratings + 2 required narrative answers
6. PDF export available only in read mode (closed evaluations)

**Definition of done:**
- Form mode renders correctly when state = Awaiting Self-Assessment
- Read mode renders correctly for all other states
- Auto-save persists drafts
- Submit transitions state to Manager Assessment via mock API
- 3-column comparison shows correctly in read mode
- Final score block shows correctly when Closed

**Commit:** `feat(performance): E2 evaluation screen dual mode — SRD §3.2`

---

### Phase 2 — Manager Screens

#### `[TODO]` M1 — Manager Performance Landing
- **SRD section:** §4.1
- **Wireframe:** §4.1.1
- **Component spec:** §4.1.2

**Steps:**
1. Read SRD §4.1 in full
2. AsyncNotifier returning team evaluations scoped by role
3. Create `m1_landing_screen.dart`:
   - AppBar + dev role toggle
   - **KPI strip:** Pending My Action / Team Avg Score / Cycle Progress (per §7.8)
   - **View switcher:** Dashboard | Team
   - **Tabs:** Team Evaluations (default) | My Own (renders E1)
   - **Cycle Selector:** dropdown of cycles (default current)
   - **Filter chips:** All | Awaiting Action | Completed
   - **Team Evaluation Card:** avatar, name, position, state badge, sub-line context, action button
   - Action button label varies by state: 'Set Goals' / 'Evaluate' / 'Review'
   - Tap card → M2 (form) or M3 (read), depending on state
4. HR Manager: department filter visible, scope is company-wide

**Commit:** `feat(performance): M1 manager performance landing — SRD §4.1`

---

#### `[TODO]` M2 — Manager Evaluation Form
- **SRD section:** §4.2
- **Wireframe:** §4.2.1
- **Component spec:** §4.2.2

**Steps:**
1. Read SRD §4.2 in full
2. 
   - **Employee header card** (avatar, name, position, cycle, state)
   - **KPI cards (Manager Mode):** each card shows employee's self-input (target, achieved, self-rating, self-note) read-only, then separator, then manager input area (rating star input + manager note text)
   - **Competencies — Comparison form:** 2-column layout (Self read-only / Manager interactive)
   - **Employee Narrative section** (read-only): show employee's Top Achievements, Challenges
   - **Manager Feedback:** Overall Comments (required) + Areas for Development (optional)
   - **Provisional Final Score block:** live-updated from backend on each save
   - Save Draft + Submit Evaluation buttons
3. On submit: mock API transitions state to HR Review or Closed

**Definition of done:**
- Self-input visually distinguished as muted/read-only
- Provisional score updates live as ratings change
- Submit locks edits and transitions state

**Commit:** `feat(performance): M2 manager evaluation form — SRD §4.2`

---

#### `[TODO]` M3 — Evaluation Detail (Manager Read Mode)
- **SRD reference:** Reuses E2 read-mode layout with employee info card on top

**Steps:**
1. Build as a thin wrapper around E2 in read mode
2. Add EmployeeInfoCard at the top
3. Same final score block, KPI/competency comparison, manager feedback section, acknowledgement display
4. PDF export uses **manager's** emp_id watermark

**Commit:** `feat(performance): M3 evaluation read mode manager — SRD §4.3`

---

### Phase 3 — Dashboard

#### `[TODO]` D1 — Performance Dashboard
- **SRD section:** §5
- **Wireframe:** §5.1
- **Component spec:** §5.2

**Steps:**
1. Read SRD §5 in full
2. 
   - Cycle selector + 'All Cycles' option
   - **KPI cards:** Team Avg Score / Completion / Top Score (with name)
   - **Score Distribution Chart** (use F.2 widget) — taps drill into M1 by band
   - **Competency Averages** (use F.2 widget)
   - **Top Performers** (top 3 by final score) — tap → M3
   - **Attention Needed** (final < 3.0 OR overdue) — tap → M2 or M3
   - **Department Comparison** (HR Manager only) — bar chart, tap to filter team list
   - PDF export with emp_id watermark

**Commit:** `feat(performance): D1 dashboard — SRD §5`

---

### Phase 4 — HR Manager Extensions

#### `[TODO]` H1 — HR Manager Additional Views
- **SRD section:** §6
- **Component spec:** §6.1

**Steps:**
1. On M1 for HR Manager: enable department filter, show all employees
2. Add **Cycle Overview Card** at top of M1 (HR Manager only): per active cycle — name, period, % completion, count overdue, drill-down
3. Add **Calibration View**: read-only matrix showing score distribution across departments (identifies outliers)
4. Aggregate PDF export — bulk PDF combining individual evaluation PDFs (backend operation; if not yet supported, treat as Phase 2 per SRD assumption #6)

**Commit:** `feat(performance): H1 hr manager extensions — SRD §6`

---

### Phase 5 — Polish & Verification

#### `[TODO]` P1 — Cross-screen verification
- Switch through all states using dev toggle
- Verify form mode vs read mode in E2 transitions correctly with state
- Verify auto-save in E2 form mode
- Verify provisional score updates in M2
- Verify all PDF exports

#### `[TODO]` P2 — Component reuse audit
- Confirm star rating widgets are shared across modules (not duplicated)
- All status badges use centralized maps
- Final score block reused everywhere

#### `[TODO]` P3 — Module 3 sign-off
- `flutter analyze` clean
- All widget tests pass
- Screenshots of every screen and state
- Decisions log §10 updated

---

## 10. Decisions Log

```
[YYYY-MM-DD] TASK_ID — Decision: <what>. Rationale: <why>.
```

(Initially empty)

---

## 11. Open Items / Questions for Architect

(Initially empty)

Note: SRD §9.1 lists 6 assumptions awaiting confirmation. Implement based on documented defaults; track deviations here.

---

## 12. Definition of Module Complete

- [ ] All tasks marked `[DONE]`
- [ ] `flutter analyze` passes
- [ ] No duplicate widgets
- [ ] PDF export with watermark works on E2 (read mode), M3, D1
- [ ] Dev role toggle visible and functional
- [ ] E2 dual-mode (form vs read) correctly state-driven
- [ ] Provisional final score updates live in M2
- [ ] Auto-save works in E2 form mode
- [ ] All TODO(release) and TODO(backend) comments in place
- [ ] Screenshots captured
- [ ] Decisions log §10 updated

— End of Module 3 Task File —

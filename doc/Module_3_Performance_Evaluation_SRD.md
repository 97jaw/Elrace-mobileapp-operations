**HR MANAGEMENT MOBILE APPLICATION**

**Module 3: Performance Evaluation**

*Software Requirements Specification*

  ----------------------- ----------------------- -----------------------
                                                  

  ----------------------- ----------------------- -----------------------

  -----------------------------------------------------------------------
  **Field**               **Detail**
  ----------------------- -----------------------------------------------
  Project                 HR Management Mobile Application

  Module                  Module 3 --- Performance Evaluation

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
Performance Evaluation module. The module supports periodic employee
performance reviews including self-assessment, manager assessment, KPI
tracking, competency rating, and final scoring.

**1.2 Scope**

  -----------------------------------------------------------------------
  **Aspect**              **Phase 1 Position**
  ----------------------- -----------------------------------------------
  **In Scope**            Employee self-assessment forms, Manager
                          evaluation forms, KPI/Goals tracking with
                          target vs achieved, Competency ratings,
                          Comments and final scores, Evaluation history,
                          Manager team analytics dashboard.

  **Out of Scope**        Goal-setting workflow (assumed defined in Odoo
                          backoffice and pulled into mobile). 360° peer
                          reviews. Calibration meetings. Compensation
                          linkage.

  **Approval Workflow**   Out of scope for Phase 1.

  **PDF Export**          Yes --- Evaluation PDF download with emp_id
                          watermark.

  **Theme / Auth /        Inherits from foundation: light theme, online
  Notifications /         only, English only.
  Connectivity /          
  Language**              
  -----------------------------------------------------------------------

**1.3 Roles & View Selection**

  -----------------------------------------------------------------------
  **Role Flag**      **View Rendered**     **Visibility Scope**
  ------------------ --------------------- ------------------------------
  is_hr_manager      HR Manager View       All evaluations company-wide.
                                           Run cycles, view aggregates,
                                           export reports.

  is_management /    Manager View          Own evaluations + evaluations
  is_pm                                    they conduct for their direct
                                           reports / team.

  None of the above  Employee View         Own evaluations only --- view
                                           past, fill self-assessment
                                           when active.
  -----------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| Evaluation cycles are configured in Odoo backoffice (annual,          |
| semi-annual, quarterly, etc.) and the mobile app surfaces whatever    |
| cycle is currently active. Employees and managers do not create or    |
| schedule cycles from the mobile app.                                  |
+-----------------------------------------------------------------------+

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| Scoring uses a 5-point scale (1=Below Expectations, 2=Partially       |
| Meets, 3=Meets Expectations, 4=Exceeds, 5=Outstanding) for both KPIs  |
| and competencies. Final score is a weighted average computed by the   |
| backend. If your Odoo configuration uses a different scale (e.g.,     |
| 1-10 or letter grades), the form rendering must adapt to a            |
| backend-supplied scale definition.                                    |
+-----------------------------------------------------------------------+

**2. Evaluation Structure**

A single evaluation record is composed of multiple sections that
together produce a final score. The structure is consistent across all
employees within a cycle.

  ----------------------------------------------------------------------------
  **Section**           **Description**
  --------------------- ------------------------------------------------------
  **Header**            Cycle name (e.g., \'Annual Review 2026\'), period
                        dates, employee, evaluator, current state.

  **KPIs / Goals**      List of pre-defined goals per employee with target
                        value, achieved value, weight (%), and rating (1-5).
                        KPIs are typically set during goal-setting at cycle
                        start.

  **Competencies**      Standard or role-specific competencies (Communication,
                        Leadership, Technical Skills, Teamwork, etc.) rated
                        1-5.

  **Self-Assessment**   Employee fills first: ratings for own KPIs, own
                        competencies, plus narrative answers to predefined
                        questions (achievements, challenges, development
                        needs).

  **Manager             Manager fills after self-assessment is submitted: same
  Assessment**          rating fields plus narrative feedback.

  **Final Score**       Computed by backend: weighted average across KPIs and
                        competencies. Displayed on summary screen.

  **Comments /          Free-text fields for both employee and manager.
  Feedback**            

  **Acknowledgement**   Employee acknowledges the manager assessment (read +
                        acknowledge action). Phase 1: read-only display,
                        acknowledgement action deferred to Phase 2.
  ----------------------------------------------------------------------------

**2.1 Evaluation Lifecycle**

An evaluation record progresses through the following states. Backend
owns state transitions; mobile renders read or write UI per state.

  ----------------------------------------------------------------------------
  **State**             **Owner**        **Mobile Behavior**
  --------------------- ---------------- -------------------------------------
  **Goal Setting**      Manager +        KPIs visible read-only (set in
                        Employee         backoffice in Phase 1).

  **Self-Assessment**   Employee         Form opens for the employee to fill
                                         ratings + narrative answers. Manager
                                         view shows \'Awaiting
                                         Self-Assessment\'.

  **Manager             Manager          Form opens for the manager.
  Assessment**                           Self-assessment values become
                                         read-only context.

  **Calibration / HR    HR Manager       Read-only for employee and manager.
  Review**                               HR can see all.

  **Final / Closed**    ---              Read-only for everyone. Final score
                                         visible. PDF export available.
  ----------------------------------------------------------------------------

**3. Employee View**

**3.1 Screen E1 --- Performance Landing**

**3.1.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← My Performance ⋮ │                                                |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ CURRENT EVALUATION │ │                                            |
|                                                                       |
| │ │ Annual Review 2026 │ │                                            |
|                                                                       |
| │ │ Period: 01 Jan 2026 → 31 Dec 2026 │ │                             |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ │ Status: \[ AWAITING SELF-ASSESSMENT \] │ │                        |
|                                                                       |
| │ │ Due by: 30 May 2026 (21 days remaining) │ │                       |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ │ \[ Start Self-Assessment \] │ │                                   |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ MY PERFORMANCE TREND │                                              |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 5 ┤ │ │                                                           |
|                                                                       |
| │ │ 4 ┤ ●────●────● │ │                                               |
|                                                                       |
| │ │ 3 ┤● │ │                                                          |
|                                                                       |
| │ │ 2 ┤ │ │                                                           |
|                                                                       |
| │ │ 1 ┤ │ │                                                           |
|                                                                       |
| │ │ 2022 2023 2024 2025 │ │                                           |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ PAST EVALUATIONS │                                                  |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 📊 Annual Review 2025 \[CLOSED\] │ │                              |
|                                                                       |
| │ │ Final Score: 4.2 / 5 · Exceeds Expectations │ │                   |
|                                                                       |
| │ │ Closed 15 Jan 2026 │ │                                            |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 📊 Mid-Year Review 2025 \[CLOSED\] │ │                            |
|                                                                       |
| │ │ Final Score: 4.0 / 5 · Exceeds Expectations │ │                   |
|                                                                       |
| │ │ Closed 30 Jul 2025 │ │                                            |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**3.1.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Current        Prominent card showing the active cycle. Displays
  Evaluation       cycle name, period, current state, due date with
  Card**           countdown, and a primary action button. Action button
                   text varies by state: \'Start Self-Assessment\',
                   \'Continue Self-Assessment\', \'View Manager
                   Assessment\', \'View Final Evaluation\'. If no active
                   cycle: card shows \'No active evaluation cycle\' with
                   muted styling.

  **Performance    Line chart of final scores across past evaluations.
  Trend Chart**    X-axis: years/cycles. Y-axis: final score (1-5). Tap a
                   point to open that evaluation.

  **Past           Cards for closed evaluations sorted newest first. Each
  Evaluations      shows cycle name, final score, descriptive label
  List**           (Below/Meets/Exceeds/Outstanding), close date. Tap
                   opens E2.

  **Empty State**  If the employee has no evaluations: centered message
                   \'You don\'t have any evaluations yet. Your manager
                   will set your goals at the start of the next cycle.\'
  -----------------------------------------------------------------------

**3.2 Screen E2 --- Evaluation Detail / Self-Assessment Form**

Single screen handles both reading a closed evaluation and filling an
active self-assessment. Mode is determined by evaluation state.

**3.2.1 Layout Wireframe --- Self-Assessment Mode**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Annual Review 2026 ⤓ │                                            |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ Annual Review 2026 │ │                                            |
|                                                                       |
| │ │ 01 Jan 2026 → 31 Dec 2026 │ │                                     |
|                                                                       |
| │ │ Manager: Ahmed Al-Rashid │ │                                      |
|                                                                       |
| │ │ \[ AWAITING SELF-ASSESSMENT \] │ │                                |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ PROGRESS │                                                          |
|                                                                       |
| │ ───────────────────────────────────────────────── │                 |
|                                                                       |
| │ ●━━━●━━━●━━━○ │                                                     |
|                                                                       |
| │ KPIs Comp Notes Submit │                                            |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ KPIs / GOALS │                                                      |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 1. Increase regional sales by 15% │ │                             |
|                                                                       |
| │ │ Weight: 30% │ │                                                   |
|                                                                       |
| │ │ Target: AED 1.5M Achieved: \[ AED 1.7M \] │ │                     |
|                                                                       |
| │ │ Self-Rating: ★ ★ ★ ★ ★ (5 - Outstanding) │ │                      |
|                                                                       |
| │ │ Notes: │ │                                                        |
|                                                                       |
| │ │ \[ \]│ │                                                          |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 2. Mentor 2 junior team members │ │                               |
|                                                                       |
| │ │ Weight: 20% │ │                                                   |
|                                                                       |
| │ │ Target: 2 mentees Achieved: \[ 2 \] │ │                           |
|                                                                       |
| │ │ Self-Rating: ★ ★ ★ ★ ☆ (4 - Exceeds) │ │                          |
|                                                                       |
| │ │ Notes: │ │                                                        |
|                                                                       |
| │ │ \[ \]│ │                                                          |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ COMPETENCIES │                                                      |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Communication ★ ★ ★ ★ ☆ (4) │                                       |
|                                                                       |
| │ Leadership ★ ★ ★ ★ ☆ (4) │                                          |
|                                                                       |
| │ Technical Skills ★ ★ ★ ★ ★ (5) │                                    |
|                                                                       |
| │ Teamwork ★ ★ ★ ★ ★ (5) │                                            |
|                                                                       |
| │ Problem Solving ★ ★ ★ ★ ☆ (4) │                                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ NARRATIVE │                                                         |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Top 3 Achievements \* │                                             |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Challenges Faced \* │                                               |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Development Needs │                                                 |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ Save Draft \] \[ Submit Self-Assessment \] │                     |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**3.2.2 Layout Wireframe --- Read-Only Mode (Closed Evaluation)**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Annual Review 2025 ⤓ │                                            |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ Annual Review 2025 │ │                                            |
|                                                                       |
| │ │ Manager: Ahmed Al-Rashid \[ CLOSED \] │ │                         |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ │ FINAL SCORE │ │                                                   |
|                                                                       |
| │ │ ╔══════════════════╗ │ │                                          |
|                                                                       |
| │ │ ║ 4.2 / 5 ║ │ │                                                   |
|                                                                       |
| │ │ ║ Exceeds ║ │ │                                                   |
|                                                                       |
| │ │ ╚══════════════════╝ │ │                                          |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ KPIs / GOALS │                                                      |
|                                                                       |
| │ ───────────────────────────────────────────────── │                 |
|                                                                       |
| │ Self Manager Final │                                                |
|                                                                       |
| │ 1. Sales 15% 5 4 4.5 │                                              |
|                                                                       |
| │ 2. Mentor 4 4 4.0 │                                                 |
|                                                                       |
| │ 3. Process 4 3 3.5 │                                                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ COMPETENCIES │                                                      |
|                                                                       |
| │ ───────────────────────────────────────────────── │                 |
|                                                                       |
| │ Self Manager Final │                                                |
|                                                                       |
| │ Communication 4 4 4 │                                               |
|                                                                       |
| │ Leadership 4 4 4 │                                                  |
|                                                                       |
| │ \... │                                                              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ MANAGER\'S FEEDBACK │                                               |
|                                                                       |
| │ ───────────────────────────────────────────────── │                 |
|                                                                       |
| │ \"Strong year overall. Sales targets met\...\" │                    |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ YOUR ACKNOWLEDGEMENT │                                              |
|                                                                       |
| │ ───────────────────────────────────────────────── │                 |
|                                                                       |
| │ ☑ Acknowledged on 15 Jan 2026 │                                     |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**3.2.3 Component Specification**

  --------------------------------------------------------------------------
  **Component**       **Specification**
  ------------------- ------------------------------------------------------
  **Header Card**     Cycle name, period, manager name, current state badge.
                      In closed mode, also shows the prominent Final Score
                      block with descriptive label.

  **Progress          Visible only in form (write) mode. Four steps: KPIs →
  Stepper**           Competencies → Notes → Submit. Steps are tappable to
                      jump between sections. Filled circles indicate
                      completed sections.

  **KPI Card (Form    For each KPI: title, weight, target (read-only),
  Mode)**             achieved (numeric input), self-rating (5-star input),
                      notes (text). Cards stack vertically.

  **KPI Row (Read     Three-column compact display: Self rating, Manager
  Mode)**             rating, Final rating. Tap to expand for full details
                      and notes.

  **Competency        Form mode: list of competencies with star-rating
  Section**           inputs. Read mode: three-column comparison (self /
                      manager / final).

  **Narrative         Form mode: three required text areas. Read mode: each
  Section**           section displayed as a card with employee response and
                      manager response side by side or stacked.

  **Final Score       Read mode only. Large prominent display of final score
  Block**             with descriptive label color-coded
                      (Outstanding=success, Below=danger).

  **Acknowledgement   Read mode only. Shows whether the employee has
  Block**             acknowledged the evaluation. Phase 1: display only.
                      Phase 2: action button.

  **Save Draft**      Saves current form state without submitting. Available
                      throughout the form. Auto-save every 30 seconds during
                      editing.

  **Submit            Validates required fields, then transitions evaluation
  Self-Assessment**   to Manager Assessment state via backend API.

  **Export PDF**      Download icon in header. Available in read mode
                      (closed evaluations). PDF carries emp_id watermark.
  --------------------------------------------------------------------------

**4. Manager View**

**4.1 Screen M1 --- Manager Performance Landing**

**4.1.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Performance ⋮ │                                                   |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │                |
|                                                                       |
| │ │ Pending My │ │ Team Avg │ │ Cycle │ │                             |
|                                                                       |
| │ │ Action: 4 │ │ Score: 4.1 │ │ Progress: 68%│ │                     |
|                                                                       |
| │ └──────────────┘ └──────────────┘ └──────────────┘ │                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌────────────────────┐ ┌────────────────────┐ │                     |
|                                                                       |
| │ │ 📊 Dashboard │ │ 📋 Team │ │                                      |
|                                                                       |
| │ └────────────────────┘ └────────────────────┘ │                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌─────────────────────────────────────────────────┐ │               |
|                                                                       |
| │ │ Team Evaluations │ My Own │ │                                     |
|                                                                       |
| │ └─────────────────────────────────────────────────┘ │               |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ CURRENT CYCLE: Annual Review 2026 │                                 |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ All \] \[ Awaiting Action \] \[ Completed \] │                   |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Sarah Ahmed │ │                                                |
|                                                                       |
| │ │ Software Engineer │ │                                             |
|                                                                       |
| │ │ \[ AWAITING MANAGER ASSESSMENT \] │ │                             |
|                                                                       |
| │ │ Self-assessment submitted 2 days ago │ │                          |
|                                                                       |
| │ │ \[ Evaluate \] │ │                                                |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Omar Khalid │ │                                                |
|                                                                       |
| │ │ Software Engineer │ │                                             |
|                                                                       |
| │ │ \[ AWAITING SELF-ASSESSMENT \] │ │                                |
|                                                                       |
| │ │ Reminder sent 3 days ago │ │                                      |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Layla Mohammed │ │                                             |
|                                                                       |
| │ │ Senior Engineer \[ CLOSED \] │ │                                  |
|                                                                       |
| │ │ Final Score: 4.4 / 5 │ │                                          |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**4.1.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **KPI Strip**    Pending My Action (count of evaluations awaiting
                   manager assessment), Team Avg Score (current cycle
                   average across closed evaluations), Cycle Progress (%
                   of team evaluations completed).

  **View           Toggle between Dashboard (Section 5) and Team list
  Switcher**       (default).

  **Tabs**         \'Team Evaluations\' (default), \'My Own\'. The \'My
                   Own\' tab renders Screen E1 (Employee landing) for the
                   manager\'s own evaluations.

  **Cycle          Header line shows current cycle. Dropdown allows
  Selector**       switching to past cycles.

  **Filter Chips** All, Awaiting Action, Completed. Awaiting Action shows
                   evaluations where the manager needs to fill or where
                   employees are blocked.

  **Team           Avatar, employee name, position, status badge,
  Evaluation       sub-line context (e.g., \'Self-assessment submitted 2
  Card**           days ago\'), action button. Tap card opens M2.

  **Action Button  Visible only when manager action is required. Label
  on Card**        changes per state: \'Set Goals\', \'Evaluate\',
                   \'Review\'.
  -----------------------------------------------------------------------

**4.2 Screen M2 --- Manager Evaluation Form**

Form used by the manager to evaluate a single employee. The screen
surfaces the employee\'s self-assessment as read-only context next to
the manager input fields.

**4.2.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Evaluate --- Sarah Ahmed ⤓ │                                      |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 👤 Sarah Ahmed │ │                                                |
|                                                                       |
| │ │ Software Engineer · Sales │ │                                     |
|                                                                       |
| │ │ Annual Review 2026 │ │                                            |
|                                                                       |
| │ │ \[ AWAITING MANAGER ASSESSMENT \] │ │                             |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ KPIs / GOALS │                                                      |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ 1. Increase regional sales by 15% │ │                             |
|                                                                       |
| │ │ Weight: 30% │ │                                                   |
|                                                                       |
| │ │ Target: AED 1.5M Achieved: AED 1.7M (113%) │ │                    |
|                                                                       |
| │ │ Self-Rating: ★ ★ ★ ★ ★ (5) │ │                                    |
|                                                                       |
| │ │ Self-Note: \"Exceeded by 13%, opened 2 keys\" │ │                 |
|                                                                       |
| │ │ ───────────────────────────────── │ │                             |
|                                                                       |
| │ │ Manager Rating: ★ ★ ★ ★ ★ (5) │ │                                 |
|                                                                       |
| │ │ Manager Note: │ │                                                 |
|                                                                       |
| │ │ \[ \] │ │                                                         |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ COMPETENCIES │                                                      |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Self Manager │                                                      |
|                                                                       |
| │ Communication 4 → ★ ★ ★ ★ ☆ │                                       |
|                                                                       |
| │ Leadership 4 → ★ ★ ★ ★ ☆ │                                          |
|                                                                       |
| │ Technical Skills 5 → ★ ★ ★ ★ ★ │                                    |
|                                                                       |
| │ Teamwork 5 → ★ ★ ★ ★ ★ │                                            |
|                                                                       |
| │ Problem Solving 4 → ★ ★ ★ ★ ☆ │                                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ EMPLOYEE\'S NARRATIVE (read-only) │                                 |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Top Achievements: │                                                 |
|                                                                       |
| │ \"Closed two enterprise deals worth AED 1.2M total\...\" │          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Challenges: │                                                       |
|                                                                       |
| │ \"Pricing pressure on smaller deals impacted margin\...\" │         |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ YOUR FEEDBACK │                                                     |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Overall Comments \* │                                               |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ Areas for Development │                                             |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ │ │                                                               |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ PROVISIONAL FINAL SCORE │                                           |
|                                                                       |
| │ ╔══════════════════╗ │                                              |
|                                                                       |
| │ ║ 4.4 / 5 ║ Auto-computed by backend │                              |
|                                                                       |
| │ ╚══════════════════╝ │                                              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ \[ Save Draft \] \[ Submit Evaluation \] │                          |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**4.2.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**    **Specification**
  ---------------- ------------------------------------------------------
  **Employee       Avatar, name, position + department, current cycle,
  Header**         evaluation state.

  **KPI Card       Each card displays the KPI definition + employee
  (Manager Mode)** self-input (target, achieved, self-rating, self-note)
                   followed by a separator and the manager\'s input area:
                   rating star input + manager note text. Self-input is
                   visually distinguished as muted/read-only context.

  **Competency     Two columns: Self rating (display only) and Manager
  Comparison**     rating (interactive star input). The arrow between
                   them visually emphasizes the transition.

  **Narrative      Read-only display of the employee\'s self-assessment
  Section**        narrative answers. Manager cannot edit the employee\'s
                   input.

  **Manager        Two text areas for the manager: Overall Comments
  Feedback**       (required) and Areas for Development (optional).

  **Provisional    Live-updated as the manager edits ratings. Computed by
  Final Score**    backend on each save. Visual treatment matches
                   closed-mode final score block.

  **Save Draft /   Save Draft persists state without locking. Submit
  Submit**         transitions the evaluation to HR Review or Closed
                   state and locks edits.
  -----------------------------------------------------------------------

**5. Manager Performance Dashboard**

Visual analytical view of team performance. Available to Manager and HR
Manager. Accessed via the Dashboard button on M1.

**5.1 Layout Wireframe**

+-----------------------------------------------------------------------+
| ┌──────────────────────────────────────────────────────────┐          |
|                                                                       |
| │ ← Performance Dashboard Annual Review 2026 ▼ ⤓ │                    |
|                                                                       |
| ├──────────────────────────────────────────────────────────┤          |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │                |
|                                                                       |
| │ │ Team Avg │ │ Completion │ │ Top Score │ │                         |
|                                                                       |
| │ │ 4.1 / 5 │ │ 68% │ │ 4.7 (Sarah)│ │                                |
|                                                                       |
| │ └──────────────┘ └──────────────┘ └──────────────┘ │                |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ SCORE DISTRIBUTION │                                                |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ Outstanding (5) ▆▆ 2 │ │                                          |
|                                                                       |
| │ │ Exceeds (4) ▆▆▆▆▆▆▆▆ 8 │ │                                        |
|                                                                       |
| │ │ Meets (3) ▆▆▆▆ 4 │ │                                              |
|                                                                       |
| │ │ Partial (2) ▆ 1 │ │                                               |
|                                                                       |
| │ │ Below (1) 0 │ │                                                   |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ COMPETENCY AVERAGES (Team) │                                        |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ ┌──────────────────────────────────────────────────┐ │              |
|                                                                       |
| │ │ Communication ●━━━━━●━━━━━●━━━━━● 4.2 │ │                         |
|                                                                       |
| │ │ Leadership ●━━━━━●━━━━━●━━━━━○ 3.8 │ │                            |
|                                                                       |
| │ │ Technical Skills ●━━━━━●━━━━━●━━━━━● 4.5 │ │                      |
|                                                                       |
| │ │ Teamwork ●━━━━━●━━━━━●━━━━━● 4.3 │ │                              |
|                                                                       |
| │ │ Problem Solving ●━━━━━●━━━━━●━━━━━○ 4.0 │ │                       |
|                                                                       |
| │ └──────────────────────────────────────────────────┘ │              |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ TOP PERFORMERS │                                                    |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ 1. Sarah Ahmed 4.7 / 5 Outstanding › │                              |
|                                                                       |
| │ 2. Layla Mohammed 4.4 / 5 Exceeds › │                               |
|                                                                       |
| │ 3. Yousef Ibrahim 4.3 / 5 Exceeds › │                               |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ ATTENTION NEEDED │                                                  |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ 1. Omar Khalid 2.8 / 5 Partial Meets ›│                             |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| │ DEPARTMENT COMPARISON (HR Manager only) │                           |
|                                                                       |
| │ ──────────────────────────────────────────────── │                  |
|                                                                       |
| │ Sales ▆▆▆▆▆▆▆▆ 4.2 │                                                |
|                                                                       |
| │ Marketing ▆▆▆▆▆▆▆ 4.0 │                                             |
|                                                                       |
| │ Operations ▆▆▆▆▆▆▆▆▆ 4.4 │                                          |
|                                                                       |
| │ F&B ▆▆▆▆▆▆ 3.8 │                                                    |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| └──────────────────────────────────────────────────────────┘          |
+-----------------------------------------------------------------------+

**5.2 Component Specification**

  -----------------------------------------------------------------------
  **Component**      **Specification**
  ------------------ ----------------------------------------------------
  **Cycle Selector** Dropdown in header. Switches all dashboard data to
                     the selected cycle. Includes \'All Cycles\' option
                     for trend views.

  **KPI Cards**      Team Average Score (mean across closed evaluations
                     in scope), Completion (% of team evaluations
                     closed), Top Score (highest individual final score
                     with name).

  **Score            Horizontal bar chart showing count of employees per
  Distribution**     descriptive band
                     (Outstanding/Exceeds/Meets/Partial/Below). Tap a
                     band to drill down to those employees.

  **Competency       Per-competency average across the team. Visual:
  Averages**         progress-bar style with score on the right. Shows
                     team strengths and weaknesses.

  **Top Performers** Top 3 by final score. Tap row to open M3 (read-only
                     evaluation detail).

  **Attention        Employees with final score below 3.0 (Meets
  Needed**           Expectations) or with overdue self-assessments. Tap
                     row to open M2 or M3.

  **Department       HR Manager only. Horizontal bar chart by department
  Comparison**       average.

  **Export PDF**     Generates PDF snapshot of dashboard with emp_id
                     watermark.
  -----------------------------------------------------------------------

**6. HR Manager Additional Views**

HR Managers extend the Manager view with company-wide visibility, cycle
management oversight, and aggregate analytics.

**6.1 Additional Capabilities**

  -----------------------------------------------------------------------
  **Capability**     **Specification**
  ------------------ ----------------------------------------------------
  **All Evaluations  On Screen M1, the team list shows all employees
  Access**           company-wide. Department filter is enabled.

  **Cycle Overview   Top of M1 shows a card per active cycle: cycle name,
  Card**             period, % completion, count of overdue evaluations,
                     drill-down to filtered list.

  **Aggregated       Dashboard sees company-wide data with department and
  Dashboard**        location filters.

  **Aggregate PDF    Export \'All Evaluations\' PDF for a cycle --- bulk
  Export**           PDF combining individual evaluation PDFs. Backend
                     generated. emp_id watermark of the HR Manager.

  **Calibration      Read-only matrix showing distribution of scores
  View**             across departments to identify outliers (e.g., one
                     department all 5s vs. another all 3s). Used for HR
                     review before finalizing cycle.
  -----------------------------------------------------------------------

+-----------------------------------------------------------------------+
| **⚑ ASSUMPTION --- CONFIRM**                                          |
|                                                                       |
| Aggregate PDF export of all evaluations in a cycle is a               |
| backend-generated bulk operation. If your Odoo backend doesn\'t       |
| currently support this, treat it as a Phase 2 enhancement and remove  |
| from Phase 1 scope.                                                   |
+-----------------------------------------------------------------------+

**7. Screen Inventory & Navigation**

**7.1 Screen Inventory**

  -------------------------------------------------------------------------
  **Screen    **Screen Name**            **Audience**   **Mode**
  ID**                                                  
  ----------- -------------------------- -------------- -------------------
  **E1**      My Performance Landing     Employee,      Read
                                         Manager, HR    
                                         Manager (in    
                                         \'My Own\'     
                                         tab)           

  **E2**      Evaluation Detail /        Employee,      Read or Write
              Self-Assessment            Manager, HR    (state-driven)
                                         Manager        

  **M1**      Manager Performance        Manager, HR    Read + actions
              Landing                    Manager        

  **M2**      Manager Evaluation Form    Manager, HR    Write
                                         Manager        

  **M3**      Evaluation Detail (Manager Manager, HR    Read
              Read Mode)                 Manager        

  **D1**      Performance Dashboard      Manager, HR    Read
                                         Manager        
  -------------------------------------------------------------------------

**7.2 Navigation Flow**

+-----------------------------------------------------------------------+
| \[ Main App Home \]                                                   |
|                                                                       |
| │                                                                     |
|                                                                       |
| Tap \'Performance\' widget                                            |
|                                                                       |
| │                                                                     |
|                                                                       |
| ┌───────┴────────┐                                                    |
|                                                                       |
| │ Role detection │                                                    |
|                                                                       |
| └───┬────────┬───┘                                                    |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| Employee Manager / HR Manager                                         |
|                                                                       |
| ▼ ▼                                                                   |
|                                                                       |
| ┌──────┐ ┌──────┐                                                     |
|                                                                       |
| │ E1 │ │ M1 │ ─── Tab: My Own ──► E1                                  |
|                                                                       |
| └──┬───┘ └──┬───┘                                                     |
|                                                                       |
| │ │                                                                   |
|                                                                       |
| ▼ ├─► \[D1 Dashboard\]                                                |
|                                                                       |
| ┌──────┐ │                                                            |
|                                                                       |
| │ E2 │ ├─► Tap \'Evaluate\' ──► \[M2\]                                |
|                                                                       |
| └──────┘ │ │ Submit                                                   |
|                                                                       |
| │ ▼                                                                   |
|                                                                       |
| └─► Tap card \[M3 Read\]                                              |
|                                                                       |
| ▼                                                                     |
|                                                                       |
| \[M3 Read\]                                                           |
+-----------------------------------------------------------------------+

**7.3 Backend API Touchpoints**

  -------------------------------------------------------------------------
  **Capability**      **Used By**                          **Status**
  ------------------- ------------------------------------ ----------------
  **Get my            E1                                   To define
  evaluations                                              
  (current +                                               
  history)**                                               

  **Get evaluation    E2                                   To define
  detail (employee                                         
  perspective)**                                           

  **Save / submit     E2                                   To define
  self-assessment**                                        

  **Get team          M1                                   To define
  evaluations                                              
  (scoped)**                                               

  **Get evaluation    M2, M3                               To define
  for manager                                              
  review**                                                 

  **Save / submit     M2                                   To define
  manager                                                  
  assessment**                                             

  **Get provisional / E2, M2                               To define
  final score                                              
  (computed)**                                             

  **Get performance   D1                                   To define
  dashboard data**                                         

  **Get cycle list +  M1, D1                               To define
  details**                                                

  **Download          E2 read mode, M3                     To define
  evaluation PDF with                                      
  watermark**                                              
  -------------------------------------------------------------------------

**8. Status Badge Reference**

  -------------------------------------------------------------------------
  **State**           **Background**   **Text Color**   **Meaning**
  ------------------- ---------------- ---------------- -------------------
  **GOAL SETTING**    #E5E7EB          #374151          KPIs being defined

  **AWAITING          #FFF4D6          #C77700          Employee needs to
  SELF-ASSESSMENT**                                     fill
                                                        self-assessment

  **AWAITING MANAGER  #D6E4F5          #1F3A5F          Manager needs to
  ASSESSMENT**                                          evaluate

  **HR REVIEW**       #D6E4F5          #4A6B8A          HR Manager review /
                                                        calibration

  **CLOSED**          #D6F0E2          #2E7D5B          Final, no more
                                                        edits
  -------------------------------------------------------------------------

**9. Sign-off & Open Items**

**9.1 Assumptions Recap**

  ---------------------------------------------------------------------------
  **\#**   **Assumption**                                        **Status**
  -------- ----------------------------------------------------- ------------
  **1**    Evaluation cycles are configured in Odoo backoffice.  Pending
           Mobile app surfaces active cycle but does not create  
           cycles.                                               

  **2**    Scoring uses a 5-point scale for KPIs and             Pending
           competencies. Final score is weighted average         
           computed by backend.                                  

  **3**    KPIs are set during goal-setting at cycle start (in   Pending
           backoffice in Phase 1) and surface read-only in       
           mobile.                                               

  **4**    Standard competency set: Communication, Leadership,   Pending
           Technical Skills, Teamwork, Problem Solving.          
           Adjustable per Odoo configuration.                    

  **5**    Acknowledgement is read-only display in Phase 1.      Pending
           Action button deferred to Phase 2.                    

  **6**    Aggregate PDF export of all evaluations in a cycle is Pending
           backend-generated. Treat as Phase 2 if not currently  
           supported.                                            
  ---------------------------------------------------------------------------

**9.2 Open Items Owned by Backend**

- Status normalization mapping for evaluation states

- Final score computation formula (KPI weight × rating + competency
  weight × rating)

- Whether competencies are fixed or template-driven per role

- Cycle reference number format and identifiers

- Auto-save behavior and conflict resolution for concurrent edits

- PDF generation approach (server-side template vs client-side)

- Calibration matrix data structure for HR Manager view

*--- End of Module 3 ---*

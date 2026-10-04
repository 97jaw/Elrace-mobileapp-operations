# Mobile app feature access: move role flags into `emp_mobile_conf` configuration

Status: proposal for review. Scope: **what the app shows** (screens, tabs, buttons, view modes).
**Data access** (which records an API returns) is a separate phase: groups, access rights, record rules.

## 1. Why

Only the home cards and the check-in button are configured in Odoo today (`default_widgets`, resolved from
`mobile.widget.role.template` per role). Every other screen decision is computed in the app from overlapping
login flags, which come from Studio booleans on `res.users.role`:

- "Management" is decided six different ways, "HR manager" three ways, "PM" two ways.
- Defaults disagree: HR falls back to *employee* (hidden), Timesheet falls back to *foreman* (shown), so a user
  with no flags gets the foreman dashboard.
- 31 employee ids are hard-coded for stamp rights, and the app writes its own stamp flag to Firestore, so the
  server cannot revoke it.
- Several server keys are sent but ignored (`available_tabs`, `hr_module_manager.hr_request`,
  `hr_module_manager.recruitment`, `roles`, `mobile_access`).

The role export (`docs/access_audit/output/5_flag_vs_groups.csv`) showed every flag only means
"user has one of roles R1…Rn". So the flags can be replaced by a per-role list of app features, maintained in
the same place as the widgets.

## 2. Proposal

**One place per role decides widgets and features**: the existing mobile role template.

### Backend (`emp_mobile_conf` + `elrace_backend_apis`)

1. **Feature catalogue** `mobile.feature` (new model, seeded by XML data; the app must know each code):
   `code` (unique, e.g. `hr.employees_profile`), `name`, `module` (hr, purchase, timesheet, …),
   `kind` (screen, tab, action, view_mode), `parent_id` (a tab belongs to its screen), `sequence`,
   `active`, `description`, `category` (same list as widget categories: Human Resource, Projects,
   Clients & Vendors, Purchase, Productivity, Finance, Library) and `is_default`.
2. **Role template gets features**: `mobile.widget.role.template.feature_ids` (Many2many), next to
   `widget_ids`. The existing assignment wizard gets a Features tab grouped by category. Label the
   template "Mobile Role Access". A new template starts with the `is_default` features ticked; the
   responsible person then adjusts it per role.
3. **Features come from roles only** (decided): the union of the templates of the user's roles; no
   per-employee feature override. A user with no template gets no features (fail closed).
4. **Only enabled, in-date role lines count.** The widget resolver currently reads all `role_line_ids`
   (including expired ones); fix both at the same time.
5. **View modes are features too** (no booleans with special meaning). Examples:
   `hr.requests.manager`, `hr.requests.hr_manager`, `timesheet.foreman`, `timesheet.pm`,
   `timesheet.hr_wide`. The app picks the highest one it has.
6. **API**:
   - New `GET/POST /api/v3/mobile/access_profile` → `{"features": [...codes], "widgets": {...}}`.
     The app calls it after login and on resume, so role changes apply without re-login.
   - Login adds `features` (additive). Existing keys (`is_management`, `hr_module_manager`,
     `purchase_scope`, `x_stamp_user`, …) keep their current values for installed builds.
7. **Migration with no behaviour change**: a one-off script fills each role template's features from
   the role's current flags and role names (same mapping as today's code). Day one, every user gets the
   same screens they have now.
8. **Log-only check**: for a period, login computes features both ways (flags vs template) and logs
   users where they differ, before the app switches to `features`.

### App

1. One resolver, `FeatureAccess.has('<code>')`, replaces the per-module resolvers
   (`ProjectsDashboardAccess`, `hrEffectiveViewFromData`, `purchaseAccessFromData`,
   `tmRoleResolutionFromData`, `performanceManagerModeProvider`, `attendanceLoginSuggestsManagerScope`,
   `UserStampAssets.isStampUser`, `DrawingStudioAccess`).
2. **Fail closed** when the server sends `features`. When it doesn't (older server), keep today's logic.
3. Remove the hard-coded stamp ids and the Firestore self-write once `signature.stamp` is live.
4. Remove the Timesheet "default to foreman" fallback.
5. Delete dead gates (legacy `AttendancePage`, `manager_payslip_hub_screen`, unused dev toggles).

## 3. What stays out of this configuration

| Decision | Where it belongs |
|---|---|
| Which records a list returns (own / department / project / all) | Data access phase: groups, access rights, record rules |
| Per-record buttons (approve, receive invoice) | The API's per-record fields (`can_approve`, `can_receive`) |
| Widget data authorisation (`is_authorized` on LPO / petty cash cards) | The widget data API, derived from data access |
| Global test mode, VPN skip, face ID | `/app/config` (global, not per role) |
| Chat group admin | Firestore group membership |
| Check-in eligibility (BioTime, geofence) | Attendance API |

**Rule:** a feature only controls visibility. Every API must still check data access itself; hiding a tab
is not security.

## 4. Draft feature catalogue (from the app inventory)

The "Replaces" column uses the row ids of the app gating inventory (H home, R HR, P purchase, T timesheet,
J projects/media, S signature, Q QR); that inventory can be attached as an appendix if needed.

### Home
| Code | Replaces | Today |
|---|---|---|
| `home.drawing_studio` | H7 | management + Cognito config, not in `default_widgets` |
| `home.clients_vendors` | H10 fallback | management fallback when widget keys are missing |
| `home.hrms.team_view` | H31 | app overrides server scope for foremen |

Existing home cards stay as widgets (`default_widgets`); no change.

### HR
| Code | Replaces | Today |
|---|---|---|
| `hr.employees_profile` | R2, R3 | management only |
| `hr.company_documents` | R4, R5 | HR manager or management or PM |
| `hr.requests.manager` / `hr.requests.hr_manager` | R8, R9 | `hrEffectiveViewProvider`; `hr_module_manager.hr_request` ignored |
| `hr.recruitment.manager` / `hr.recruitment.hr_manager` | R11–R14 | view mode; `hr_module_manager.recruitment` ignored |
| `hr.performance.manager` | R16 | `hr_module_manager.evaluation` OR management OR `x_evaluation` |
| `hr.payslip.hr_view` | R17 | `hr_module_manager.payslip`, fallback gives management/PM HR view |
| `hr.attendance.team_view` | R18 | three inputs OR'd, can override the API |

### Purchase
| Code | Replaces | Today |
|---|---|---|
| `purchase.hub` | P1–P3 | login flags OR overview `is_authorized` |
| `purchase.mr_tab`, `purchase.rfq_tab` | P9 | `available_tabs` sent but unused |
| `purchase.invoice_receiving_tab` | P6 | doc controller, or rep who is not a manager |
| `purchase.invoice_create` | P7 | doc controller |
| `purchase.recent_invoices` | P5 | ungated (`canSeeDraftInvoices` unused) |

(Purchase scope moves to the data access phase.)

### Timesheet and site
| Code | Replaces | Today |
|---|---|---|
| `timesheet.foreman` | T1, T4, T5, T6 | role resolution, defaults to foreman |
| `timesheet.pm` | T6–T9, T11 | `is_pm` / `x_is_pm` / `x_is_pm_role` |
| `timesheet.hr_wide` | T8, T9 | `is_hr_manager` or `x_is_hr_manager` |
| `timesheet.act_as_foreman` | T2 | shown to every non-foreman |

### Projects and media
| Code | Replaces | Today |
|---|---|---|
| `projects.financials_tab` | J1 | management only |
| `projects.dashboard_all` | J2 | management bypasses client-side filter (data scope later) |
| `media.projects_tab` | J3 | `can_see_project_media` or management/PM/media |

### Signature, QR
| Code | Replaces | Today |
|---|---|---|
| `signature.stamp` | S1–S5 | `x_stamp_user` + 31 hard-coded ids + Firestore self-write |
| `qr.survey` | Q1, Q2 | `qr_status` (type mismatch bool vs int) |

## 5. Decisions

Decided:
1. Features come from roles only (users are managed inside roles).
2. One template per role holds widgets and features; features are grouped by widget category and
   new templates start with the default features ticked.
3. Mobile App Admin access stays with Odoo Settings administrators (`base.group_system`); no new group.
4. My Actions row (HR, RFQ, Petty Cash, Invoice, Signature, My Requests shortcuts on Home) stays
   visible to everyone; `home.my_actions*` is dropped from the catalogue.
5. View modes are features in the role template (`timesheet.foreman`, `timesheet.pm`,
   `timesheet.hr_wide`, `hr.requests.manager`, `hr.requests.hr_manager`, …).
6. Session recording on login is re-enabled, keeping the latest 5 sessions per employee.

## 5a. Mobile Administration module requirements

1. **Access**: Settings administrators (`base.group_system`) only. HR managers currently have
   read/write/create on widgets, role templates and the assignment wizard; that access is removed.
2. **Chatter with tracking on configuration forms**: widgets, features, role templates, devices,
   notification categories and preferences, admin notifications. Needs `mail` in the module
   dependencies. Odoo 14 does not track Many2many changes, so template `widget_ids` / `feature_ids`
   changes are posted to the chatter by code (added / removed lists).
   Log models (sessions, user locations, UAE Pass login log, notification log) stay read-only lists.
3. **Session history**: keep the last 5 `mobile.session` rows per employee (by login time); a daily
   cron deletes older rows.
   - Session recording on email login is currently commented out in `login_x` (temporary live login
     fix of 2026-09-10). Re-enabling it is approved; it must not block or slow the login (write after
     the token is built, inside a savepoint, errors only logged).
   - Do not store the full JWT in `jwt_token`; store a hash or the last characters only.

## 6. Rollout

| Step | Change | User impact |
|---|---|---|
| 1 | `mobile.feature` model, catalogue data, template `feature_ids`, wizard tab | None |
| 2 | Migration script fills templates from current flags; review per role | None |
| 3 | Login adds `features`; `/api/v3/mobile/access_profile`; log-only comparison | None (additive) |
| 4 | App build reads `features` (fail closed), falls back to old logic on old servers | Only where the log showed differences, after approval |
| 5 | Remove hard-coded stamp ids, Timesheet foreman default, dead gates | Stamp rights follow Odoo |
| 6 | After old builds retire: stop sending legacy flag keys; hide then delete Studio flags | None |

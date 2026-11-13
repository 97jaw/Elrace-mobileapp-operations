# TASK HR1 — Employee Profile: who can search whom (backend only)

Repo: ~/projects/elrace/odoo14-clients/.worktrees/elrace-addons (branch elrace-addons), module elrace_backend_apis
(+ emp_mobile_conf only if a feature record is needed). Author: M Jawad <jawad@elrace.com>, NO Co-authored-by.
NO mobile changes. The app must keep working with its current calls.

## Rules (one place: EmployeeProfileService.profile_scope(user) → 'all' | 'team' | 'self')
1. 'all': the user is management (EmployeeProfileService.is_management_user) OR has feature hr.employees_profile
   from configuration (role template / role-user settings). Can search and open EVERY active employee,
   INCLUDING labour (is_labor = True). Today labour is missing. Fix it.
2. 'team': not 'all', but the user's employee is the direct Manager (hr.employee.parent_id) of at least one active
   employee. Can search and open ONLY their direct reports (parent_id = me), plus their own profile. Direct only,
   not reports-of-reports. Labour direct reports are included.
3. 'self': anything else. Only their own profile (today's behaviour, keep it).

## Current code (read first)
- App directory list = GET /api/employee/listx (misc_controller.employee_list_get): returns is_labor = False only.
  The SAME endpoint is used by the app's contacts / call screen, todo team members, task options and RCC Hub,
  so listx's default output must NOT change for those callers.
- Profile endpoints: /api/employee/profile, /profile/contract, /profile/documents, /profile/fleet.
  Gate: _can_view_employee_profiles(user) = management or hr.employees_profile.
- App shows the directory only when its feature list contains hr.employees_profile
  (ProjectsDashboardAccess.canAccessEmployeesProfile). Otherwise it opens the user's own profile only.

## Changes
A) Scope helper: EmployeeProfileService.profile_scope(user) and allowed_employee_ids(user)
   ('all' → None = no limit; 'team' → direct reports + self; 'self' → [self]).
   Use only CONFIGURED feature codes for 'all' (before any auto-add from B).

B) App gating without an app change: in the feature list returned to the app (FeatureAccessService.resolve /
   codes sent at login and refresh), ADD hr.employees_profile for 'team' users, so the app opens the directory.
   This auto-added code must NOT count as 'all' in A or in any server check. Keep the role-config path unchanged.

C) Directory list, backend only. The app cannot send a new parameter, so make /api/employee/listx scope-aware
   ONLY when the caller is a mobile user whose scope is 'team':
   - 'team' caller → return their direct reports (incl. labour) + self, same row shape (HrmsWidgetService.employee_row).
   - 'all' caller → today's non-labour rows PLUS active labour rows (same row shape, fields add is_labor: true).
   - 'self' caller and non-mobile callers (RCC Hub / integrations) → unchanged.
   Before changing listx, CHECK every caller in the mobile repo (call_screen ContactRepo, todo team_members_api_service,
   tasks_dashboard task_options_api_service, urll_utils contactApi) and report the effect on each. If adding labour or
   team scoping to listx would break contacts / todo / task pickers, STOP and report instead of changing listx;
   we will then decide on a separate directory endpoint.
   Performance: labour can be large. Return only the row fields, prefetch images by URL (no base64), one search.

D) Profile endpoints (profile, contract, documents, fleet): replace the yes/no gate with the scope.
   Target employee not in allowed_employee_ids → error "You can only view your own team." (code 403).
   'self' → only own id. Same payloads otherwise.

E) Tests: management sees labour; config feature sees labour; manager sees only direct reports (not indirect,
   not peers) and gets 403 on a non-report; plain user only self; Hub/integration listx output unchanged.

## Report
Scope helper code, every listx caller and the impact, test results, commit hash. Push elrace-addons.
Deploy: -u elrace_backend_apis (no new columns).

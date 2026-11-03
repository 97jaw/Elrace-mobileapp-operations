# Task 1 — Cleanup: remove Delayed Requests (keep ROR) and Recent timesheets

Read first: `doc/timesheet_approval/PLAN.md`, `.cursor/rules/branching-from-main.mdc`.
Branch: `feat/timesheet-approval` (already created from `main`). Do not touch the
uncommitted `.cursor/rules/*`, `doc/MOBILE_HANDOFF_2026-11-03.md` or `tools/`.

Pure deletion task. No new UI, no behaviour change except the removed parts.

## A. Delayed Requests — remove everything, keep the ROR tab

The ROR tab (Waiting / ROR segmented tabs on the Waiting screen) uses
`DelayedApprovalsRepository.fetchRor` → `/api/my_delayed_approvals/ror` and
`DelayedRorResponse`. That call is the only one that stays.

1. Move the ROR call out of `lib/ui/presentation/Email Approval/delayed/`:
   - a small repository with `fetchRor({month, year})` (+ its private request
     helper) and the response model (rename `DelayedRorResponse` → `RorResponse`,
     keep the same parsing logic and helpers). Place it where it fits in
     `Email Approval/`.
2. Delete the rest of `lib/ui/presentation/Email Approval/delayed/`
   (models, repository, screens, widgets, `delayed_approvals.dart`).
3. `Email Approval/Approval.dart`: remove `delayedCount`, `_delayedCounters`,
   `_delayedRepo`, `_fetchDelayedCount()` and every call to it (initState,
   refresh), `_openDelayedRecordFromSheet`, the `delayed*` fields of
   `_ApprovalsCountCache`, and the delayed arguments passed to
   `AllApprovalsOverview`. ROR (`_rorData`, `_fetchRorData`, period change) uses
   the new repository.
4. `widgets/all_approvals_overview.dart`: remove the `delayed*` props,
   `onDelayedRecordTap`, `_openDelayedSheet`, `_DelayedGlassCard`,
   `_DelayedInline` and the card in the scroll column. Keep the debug-only test
   cards.
5. `widgets/approval_overview_records_sheet.dart`: remove `showDelayed`,
   `_DelayedRecordsSheetBody` + state, and helpers only used by them
   (e.g. `daysDelayed` rendering).
6. `lib/utils/generated_routes.dart`: remove the `DelayedRequestsScreen` route and
   import; remove any navigation to that route name.
7. Check: `grep -rn "Delayed\|my_delayed_approvals" lib` → only the ROR endpoint
   string remains.

## B. Recent timesheets (foreman dashboard) — remove

1. `lib/ui/presentation/timesheet/foreman/fm1_foreman_dashboard.dart`: remove
   `_RecentTimesheetsSection`, the `recentAsync` watch, the section in the layout,
   and the two `ref.invalidate(timesheetForemanRecentRowsProvider)` calls. Task 3
   puts the new "Timesheet documents" list in this place.
2. `lib/core/timesheet/providers/timesheet_data_providers.dart`: remove
   `timesheetForemanRecentRowsProvider`. **Keep**
   `TimesheetApiClient.fetchProjectTimesheetRowsForRange` (still used by
   `fm_timesheet_submitted_list_screen.dart`).
3. Remove imports/helpers that become unused.

## Done when

- `flutter analyze`: no new issues in touched files; total issue count not higher
  than before (2224 on main).
- `flutter test`: all pass.
- App: Waiting screen shows the 4 boxes and the ROR tab works (month/year change);
  no Delayed card; tapping boxes still opens their lists. Foreman dashboard opens
  without the Recent section and without errors. Debug log shows no calls to
  `my_delayed_approvals/counters|details|all`.

## Commits (one per item)

1. `docs(timesheet-approval): plan and task 1` — `doc/timesheet_approval/*`
2. `refactor(approvals): remove Delayed Requests, keep ROR`
3. `refactor(timesheet): remove Recent timesheets from the foreman dashboard`

Push the branch (no PR yet). Then report: files deleted, line count removed,
analyze/test results.

# Deprecated — legacy attendance UI (safe to delete later)

The **new** attendance module lives under `lib/ui/presentation/attendance_reports/`
(route: `HrRouteNames.attendanceReports` → `AttendanceReportsModuleScreen`).

These legacy screen files are no longer linked from the home HR widgets.
**Do not delete** `Attendace_list/model/` or `Attendace_list/repository/` — the new module still uses them.

## Delete when ready

| Path | Notes |
|------|--------|
| `lib/ui/presentation/Attendace_list/attendance_page.dart` | Old full-screen attendance list |
| `lib/ui/presentation/Attendace_list/bloc/attendance_bloc.dart` | Old bloc |
| `lib/ui/presentation/Attendace_list/bloc/attendance_event.dart` | |
| `lib/ui/presentation/Attendace_list/bloc/attendance_state.dart` | |
| `lib/ui/presentation/Attendace_list/attendance_widgets/colleasped_card.dart` | |
| `lib/ui/presentation/Attendace_list/attendance_widgets/expand_card.dart` | |
| `lib/ui/presentation/Attendace_list/attendance_widgets/icon_toggle.dart` | |
| `lib/ui/presentation/Attendace_list/attendance_widgets/report_dialog.dart` | |
| `lib/ui/presentation/Attendace_list/attendance_widgets/report_item.dart` | |

## After deletion, also clean up

- Remove `AttendanceBloc` registration from `lib/utils/di.dart` (if unused).
- Remove `/attendance` legacy route from `lib/utils/generated_routes.dart` (already points to new module).
- Remove any remaining imports of `attendance_page.dart`.

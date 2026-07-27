import 'package:el_race/ui/presentation/landing_screen/landing_screen.dart';
import 'package:el_race/ui/presentation/signin/bloc/sign_in_bloc.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/ui/presentation/signin/sign_in_screen.dart';
import 'package:el_race/ui/presentation/splash_screen/splash_screen.dart';
import 'package:el_race/utils/di.dart';
import 'package:el_race/core/timesheet/providers/timesheet_entry_mode_provider.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_entry_mode_scope.dart';
import 'package:el_race/core/clients_vendors/clients_vendors_route_names.dart';
import 'package:el_race/ui/presentation/clients_vendors/clients_screen.dart';
import 'package:el_race/ui/presentation/clients_vendors/vendors_screen.dart';
import 'package:el_race/ui/presentation/clients_vendors/screens/accounts_receivable_screen.dart';
import 'package:el_race/ui/presentation/clients_vendors/screens/outstanding_invoices_screen.dart';
import 'package:el_race/ui/presentation/clients_vendors/screens/vendor_bills_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:el_race/ui/presentation/home_screen/screens/home_screen.dart';
import 'package:el_race/ui/presentation/qr_code/qr_code_screen.dart';

import '../ui/presentation/call_screen/bloc/contact_bloc.dart';
import '../ui/presentation/call_screen/call_screen.dart';
// Import additional screens for notification navigation
import '../ui/presentation/my_projects/presentation/screens/my_project.dart';
import '../ui/presentation/PettyCash/PettyCashScreen.dart';
import '../ui/presentation/media/screens/media_list_screen.dart';
import '../ui/presentation/my_notes/screens/my_notes_screen.dart';
import '../ui/presentation/my_request/MyRequestsPage.dart';
import '../ui/presentation/task_sheet/task_sheet_screen.dart';
import '../ui/presentation/attendance_reports/attendance_reports_module_screen.dart';
import '../ui/presentation/News Banner/news_screen.dart';
import '../ui/presentation/tasks_dashboard/screens/task_details.dart';
import '../ui/presentation/Email Approval/delayed/screens/delayed_requests_screen.dart';
import '../ui/presentation/hr_management/hr_management_entry_screen.dart';
import '../ui/presentation/recruitment/r1_recruitment_landing_screen.dart';
import '../ui/presentation/performance/performance_evaluation_module_screen.dart';
import '../ui/presentation/payslip/payslip_module_screen.dart';
import '../ui/presentation/hr_management/hr_requests_module_screen.dart';
import '../ui/presentation/hr_management/hr_asset_under_planning_screen.dart';
import '../ui/presentation/hr_management/hr_circular_announcements_screen.dart';
import '../ui/presentation/hr_management/employees_profile_screen.dart';
import '../ui/presentation/hr_management/company_documents_screen.dart';
import '../core/hr_management/routing/hr_route_names.dart';
import '../core/timesheet/routing/timesheet_route_names.dart';
import '../core/widgets/hr_management/hr_module_widgets_sandbox.dart';
import '../core/widgets/timesheet/timesheet_widgets_sandbox.dart';
import '../ui/presentation/timesheet/foreman/attendance/at1_capture_mode_sheet.dart';
import '../ui/presentation/timesheet/foreman/attendance/at2_capture_camera.dart';
import '../ui/presentation/timesheet/foreman/attendance/at4_capture_summary.dart';
import '../ui/presentation/timesheet/foreman/fm1_foreman_dashboard.dart';
import '../ui/presentation/timesheet/foreman/fm3_task_detail.dart';
import '../ui/presentation/timesheet/foreman/fm_day_hub_screen.dart';
import '../ui/presentation/timesheet/foreman/fm_project_dates_screen.dart';
import '../ui/presentation/timesheet/foreman/fm_project_picker_screen.dart';
import '../ui/presentation/timesheet/foreman/fm_projects_list.dart';
import '../ui/presentation/timesheet/foreman/fm_sync_queue_screen.dart';
import '../ui/presentation/timesheet/foreman/fm_tasks_hub_screen.dart';
import '../ui/presentation/timesheet/pm/pm1_dashboard.dart';
import '../ui/presentation/timesheet/pm/pm_attendance_review.dart';
import '../ui/presentation/timesheet/pm/pm_timesheet_submissions_screen.dart';
import '../ui/presentation/timesheet/pm/pm_worker_enrol.dart';
import '../ui/presentation/timesheet/foreman/enrollment/fm_face_enroll_file_id_screen.dart';
import '../ui/presentation/timesheet/foreman/enrollment/fm_face_enroll_capture_screen.dart';
import '../ui/presentation/timesheet/gantt_list_view.dart';
import '../ui/presentation/timesheet/live_location_map.dart';
import '../ui/presentation/timesheet/project_chat_entry.dart';
import '../ui/presentation/timesheet/site_photos_gallery.dart';
import '../ui/presentation/timesheet/foreman/fm_timesheet_print_report_screen.dart';
import '../ui/presentation/timesheet/foreman/fm_timesheet_records_screen.dart';
import '../ui/presentation/timesheet/site_report_form.dart';
import '../ui/presentation/timesheet/site_management_module_entry_screen.dart';
import '../ui/presentation/timesheet/timesheet_module_home_screen.dart';
import '../ui/presentation/timesheet/timesheet_project_detail_router.dart';
import '../ui/presentation/timesheet/timesheet_route_args.dart';

class OnGeneratedRoutes {
  Route<dynamic> generatedRoutes(RouteSettings settings) {
    final signInBloc = sl.get<SignInBloc>();
    final contactBloc = sl.get<ContactBloc>();
    switch (settings.name) {
      case '/':
        return CupertinoPageRoute(builder: (_) => const SplashScreen());
      case '/signIN':
        Future.delayed(const Duration(milliseconds: 500), () {
          signInBloc.add(CheckSignedIn());
        });
        return CupertinoPageRoute(builder: (_) => const SignInScreen());
      case '/landing':
        return CupertinoPageRoute(
            builder: (_) => LandingScreen(
                  loginResponseModel: settings.arguments! as LoginResponseModel,
                ));
      case '/home':
        return CupertinoPageRoute(
          builder: (_) => const HomeScreen(), // Pass the argument),
        );
      case '/contact':
        Future.delayed(const Duration(milliseconds: 500), () {
          contactBloc.add(GetEmployeeLisET());
        });
        return CupertinoPageRoute(builder: (_) => const CallScreen());
      case '/qr_code':
        return CupertinoPageRoute(builder: (_) => const QrCodeScreen());

      // Additional routes for notification navigation
      case '/my_projects':
        return CupertinoPageRoute(builder: (_) => const MyProject());
      case '/petty_cash':
        return CupertinoPageRoute(builder: (_) => const PettyCashScreen());
      case '/media':
        return CupertinoPageRoute(builder: (_) => const MediaListScreen());
      case '/my_notes':
        return CupertinoPageRoute(builder: (_) => const MyNotesScreen());
      case '/my_requests':
        return CupertinoPageRoute(builder: (_) => const MyRequestsPage());
      case '/tasks':
        return CupertinoPageRoute(builder: (_) => const TaskSheetPage());
      case '/attendance':
        return CupertinoPageRoute(
            builder: (_) => const AttendanceReportsModuleScreen());
      case '/news':
        return CupertinoPageRoute(builder: (_) => const NewsScreen());
      case '/task-details':
        return CupertinoPageRoute(builder: (_) => const TaskDetailsScreen());
      case '/delayed_requests':
        return CupertinoPageRoute(
            builder: (_) => const DelayedRequestsScreen());
      case HrRouteNames.hub:
      case HrRouteNames.employeeLanding:
        return CupertinoPageRoute(
            builder: (_) => const HrManagementEntryScreen());
      case HrRouteNames.recruitment:
        return CupertinoPageRoute(
            builder: (_) => const R1RecruitmentLandingScreen());
      case HrRouteNames.performance:
        return CupertinoPageRoute(
            builder: (_) => const PerformanceEvaluationModuleScreen());
      case HrRouteNames.payslips:
        return CupertinoPageRoute(builder: (_) => const PayslipModuleScreen());
      case HrRouteNames.attendanceReports:
        return CupertinoPageRoute(
            builder: (_) => const AttendanceReportsModuleScreen());
      case HrRouteNames.circularAnnouncements:
        return CupertinoPageRoute(
            builder: (_) => const HrCircularAnnouncementsScreen());
      case HrRouteNames.employeesProfile:
        return CupertinoPageRoute(
            builder: (_) => const EmployeesProfileScreen());
      case HrRouteNames.companyDocuments:
        return CupertinoPageRoute(
            builder: (_) => const CompanyDocumentsScreen());
      case HrRouteNames.requests:
        return CupertinoPageRoute(
            builder: (_) => const HrRequestsModuleScreen());
      case HrRouteNames.simRequest:
        return CupertinoPageRoute(
          builder: (_) => const HrAssetUnderPlanningScreen(title: 'SIM Card Request'),
        );
      case HrRouteNames.carRentRequest:
        return CupertinoPageRoute(
          builder: (_) => const HrAssetUnderPlanningScreen(title: 'Car Rent Request'),
        );
      case HrRouteNames.carAllowanceRequest:
        return CupertinoPageRoute(
          builder: (_) =>
              const HrAssetUnderPlanningScreen(title: 'Car Allowance Request'),
        );
      case HrRouteNames.widgetSandbox:
        return CupertinoPageRoute(
            builder: (_) => const HrModuleWidgetsSandbox());
      case ClientsVendorsRouteNames.clients:
        return CupertinoPageRoute(builder: (_) => const ClientsScreen());
      case ClientsVendorsRouteNames.vendors:
        return CupertinoPageRoute(builder: (_) => const VendorsScreen());
      case ClientsVendorsRouteNames.accountsReceivable:
        return CupertinoPageRoute(
          builder: (_) => const AccountsReceivableScreen(),
        );
      case ClientsVendorsRouteNames.outstandingInvoices:
        final oiArgs = settings.arguments;
        return CupertinoPageRoute(
          builder: (_) => OutstandingInvoicesScreen(
            args: oiArgs is OutstandingInvoicesArgs ? oiArgs : null,
          ),
        );
      case ClientsVendorsRouteNames.vendorBills:
        final vbArgs = settings.arguments;
        return CupertinoPageRoute(
          builder: (_) => VendorBillsScreen(
            args: vbArgs is VendorBillsArgs
                ? vbArgs
                : const VendorBillsArgs(scope: 'purchases'),
          ),
        );
      case TimesheetRouteNames.home:
        return CupertinoPageRoute(
          builder: (_) => const TimesheetEntryModeScope(
            mode: TimesheetEntryMode.timesheet,
            child: TimesheetModuleHomeScreen(),
          ),
        );
      case TimesheetRouteNames.siteManagementHome:
        return CupertinoPageRoute(
          builder: (_) => const TimesheetEntryModeScope(
            mode: TimesheetEntryMode.siteManagement,
            child: SiteManagementModuleEntryScreen(),
          ),
        );
      case TimesheetRouteNames.foremanDashboard:
        return CupertinoPageRoute(
          builder: (_) => const Fm1ForemanDashboard(),
        );
      case TimesheetRouteNames.projectsList:
        final listArgs = settings.arguments;
        final listPickerArgs = listArgs is TimesheetProjectsListArgs
            ? listArgs
            : const TimesheetProjectsListArgs();
        return CupertinoPageRoute(
          builder: (_) => FmProjectPickerScreen(
            showFiltersInitially: listPickerArgs.showFiltersInitially,
            openChatOnSelect: listPickerArgs.openChatOnSelect,
          ),
        );
      case TimesheetRouteNames.projectPicker:
        final pickerArgs = settings.arguments;
        final pickerListArgs = pickerArgs is TimesheetProjectsListArgs
            ? pickerArgs
            : const TimesheetProjectsListArgs();
        return CupertinoPageRoute(
          builder: (_) => FmProjectPickerScreen(
            showFiltersInitially: pickerListArgs.showFiltersInitially,
            openChatOnSelect: pickerListArgs.openChatOnSelect,
          ),
        );
      case TimesheetRouteNames.projectDates:
        final args = settings.arguments;
        final projectId =
            args is TimesheetProjectArgs ? args.projectId : '0';
        final projectName =
            args is TimesheetProjectArgs ? args.projectName : null;
        final clientImageUrl =
            args is TimesheetProjectArgs ? args.clientImageUrl : null;
        return CupertinoPageRoute(
          builder: (_) => FmProjectDatesScreen(
            projectId: projectId,
            projectName: projectName,
            clientImageUrl: clientImageUrl,
          ),
        );
      case TimesheetRouteNames.projectDayHub:
        final args = settings.arguments;
        if (args is! TimesheetProjectDayArgs) {
          return CupertinoPageRoute(
            builder: (_) => const FmProjectPickerScreen(),
          );
        }
        return CupertinoPageRoute(
          builder: (_) => FmDayHubScreen(args: args),
        );
      case TimesheetRouteNames.projectDetail:
        final args = settings.arguments;
        final projectId =
            args is TimesheetProjectArgs ? args.projectId : 'p_midtown';
        return CupertinoPageRoute(
          builder: (_) => TimesheetProjectDetailRouter(projectId: projectId),
        );
      case TimesheetRouteNames.taskDetail:
        final args = settings.arguments;
        final projectId =
            args is TimesheetTaskArgs ? args.projectId : 'p_midtown';
        final taskId = args is TimesheetTaskArgs ? args.taskId : 't_inspection';
        return CupertinoPageRoute(
          builder: (_) => Fm3TaskDetail(projectId: projectId, taskId: taskId),
        );
      case TimesheetRouteNames.captureMode:
        return CupertinoPageRoute(
          builder: (_) => const At1CaptureModeScreen(),
        );
      case TimesheetRouteNames.captureCamera:
        return CupertinoPageRoute(
          builder: (_) => At2CaptureCameraScreen(
            capture: timesheetCaptureArgsFromRoute(settings.arguments),
          ),
        );
      case TimesheetRouteNames.captureSummary:
        final args = settings.arguments;
        if (args is! TimesheetCaptureSummaryArgs) {
          return CupertinoPageRoute(
            builder: (_) => At4CaptureSummaryScreen(
              args: TimesheetCaptureSummaryArgs(
                capture: timesheetCaptureArgsFromRoute(null),
                mode: 'individual',
                rows: const [],
              ),
            ),
          );
        }
        return CupertinoPageRoute(
          builder: (_) => At4CaptureSummaryScreen(args: args),
        );
      case TimesheetRouteNames.syncQueue:
        return CupertinoPageRoute(
          builder: (_) => const FmSyncQueueScreen(),
        );
      case TimesheetRouteNames.foremanTasksHub:
        return CupertinoPageRoute(
          builder: (_) => const FmTasksHubScreen(),
        );
      case TimesheetRouteNames.foremanTimesheetRecords:
        final args = settings.arguments;
        final projectArgs = args is TimesheetProjectArgs ? args : null;
        return CupertinoPageRoute(
          builder: (_) => FmTimesheetRecordsScreen(
            projectId: projectArgs?.projectId,
            projectName: projectArgs?.projectName,
          ),
        );
      case TimesheetRouteNames.workerEnrol:
        final args = settings.arguments;
        final projectId =
            args is TimesheetProjectArgs ? args.projectId : 'p_midtown';
        return CupertinoPageRoute(
          builder: (_) => PmWorkerEnrol(projectId: projectId),
        );
      case TimesheetRouteNames.faceEnrollEntry:
        final enrollArgs = settings.arguments;
        if (enrollArgs is! TimesheetFaceEnrollArgs) {
          return CupertinoPageRoute(
            builder: (_) => const FmFaceEnrollFileIdScreen(
              args: TimesheetFaceEnrollArgs(projectId: 'p_midtown'),
            ),
          );
        }
        return CupertinoPageRoute(
          builder: (_) => FmFaceEnrollFileIdScreen(args: enrollArgs),
        );
      case TimesheetRouteNames.faceEnrollCapture:
        final captureArgs = settings.arguments;
        if (captureArgs is! TimesheetFaceEnrollCaptureArgs) {
          return CupertinoPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('Missing enrollment employee')),
            ),
          );
        }
        return CupertinoPageRoute(
          builder: (_) => FmFaceEnrollCaptureScreen(args: captureArgs),
        );
      case TimesheetRouteNames.sitePhotos:
        final args = settings.arguments;
        final projectId =
            args is TimesheetProjectArgs ? args.projectId : 'p_midtown';
        return CupertinoPageRoute(
          builder: (_) => SitePhotosGallery(projectId: projectId),
        );
      case TimesheetRouteNames.reportForm:
        final args = settings.arguments;
        final projectArgs = args is TimesheetProjectArgs ? args : null;
        final projectId = projectArgs?.projectId ?? 'p_midtown';
        return CupertinoPageRoute(
          builder: (_) => FmTimesheetPrintReportScreen(
            projectId: projectId,
            projectName: projectArgs?.projectName,
          ),
        );
      case TimesheetRouteNames.gantt:
        final args = settings.arguments;
        final projectId =
            args is TimesheetProjectArgs ? args.projectId : 'p_midtown';
        return CupertinoPageRoute(
          builder: (_) => GanttListView(projectId: projectId),
        );
      case TimesheetRouteNames.liveMap:
        final args = settings.arguments;
        final projectId =
            args is TimesheetProjectArgs ? args.projectId : 'p_midtown';
        return CupertinoPageRoute(
          builder: (_) => LiveLocationMap(projectId: projectId),
        );
      case TimesheetRouteNames.projectChat:
        final args = settings.arguments;
        final projectArgs = args is TimesheetProjectArgs ? args : null;
        final projectId = projectArgs?.projectId ?? 'p_midtown';
        return CupertinoPageRoute(
          builder: (_) => ProjectChatEntry(
            projectId: projectId,
            projectName: projectArgs?.projectName,
          ),
        );
      case TimesheetRouteNames.pmDashboard:
        return CupertinoPageRoute(
          builder: (_) => const Pm1Dashboard(),
        );
      case TimesheetRouteNames.attendanceReview:
        final args = settings.arguments;
        final projectId =
            args is TimesheetProjectArgs ? args.projectId : 'p_midtown';
        return CupertinoPageRoute(
          builder: (_) => PmAttendanceReview(projectId: projectId),
        );
      case TimesheetRouteNames.pmTimesheetReport:
        final args = settings.arguments;
        final projectId =
            args is TimesheetProjectArgs ? args.projectId : 'p_midtown';
        final projectName =
            args is TimesheetProjectArgs ? args.projectName : null;
        return CupertinoPageRoute(
          builder: (_) => PmTimesheetSubmissionsScreen(
            projectId: projectId,
            projectName: projectName,
          ),
        );
      case TimesheetRouteNames.widgetSandbox:
        return CupertinoPageRoute(
          builder: (_) => const TimesheetWidgetsSandbox(),
        );
    }
    return MaterialPageRoute(
        builder: (_) => Scaffold(
            body:
                Center(child: Text('No route defined for ${settings.name}'))));
  }
}

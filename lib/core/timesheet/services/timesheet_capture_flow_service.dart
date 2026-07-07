import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/models/timesheet_submit_request.dart';
import 'package:el_race/core/timesheet/network/timesheet_api_client.dart';
import 'package:el_race/core/timesheet/network/timesheet_functions_client.dart';
import 'package:el_race/core/timesheet/services/capture_queue_service.dart';

/// Orchestrates face match (mock/real callable) then Odoo timesheet submit.
class TimesheetCaptureFlowService {
  TimesheetCaptureFlowService({
    TimesheetFunctionsClient? functionsClient,
    TimesheetApiClient? apiClient,
    TimesheetCaptureQueueService? queueService,
  })  : _functionsClient = functionsClient ?? TimesheetFunctionsClient(),
        _apiClient = apiClient ?? TimesheetApiClient(),
        _queueService = queueService ?? TimesheetCaptureQueueService();

  final TimesheetFunctionsClient _functionsClient;
  final TimesheetApiClient _apiClient;
  final TimesheetCaptureQueueService _queueService;

  Future<TimesheetMatchAttendanceResult> matchCapture(
    AttendanceCaptureDraft draft,
  ) {
    return _functionsClient.matchAttendance(
      projectId: draft.projectId,
      taskId: draft.taskId,
      cropUrl: draft.cropLocalPath,
      lat: draft.lat ?? 0,
      lon: draft.lon ?? 0,
      event: draft.event,
    );
  }

  Future<TimesheetSubmitResult> submitAttendance({
    required AttendanceCaptureDraft draft,
    required TimesheetMatchAttendanceResult match,
    required List<Worker> workers,
    String? workerNameOverride,
    int? employeeIdOverride,
  }) async {
    final worker = _resolveWorker(match.workerId, workers);
    final employeeId = employeeIdOverride ??
        worker?.odooEmployeeId ??
        _parseEmployeeId(match.workerId);
    if (employeeId == null) {
      return const TimesheetSubmitResult(
        success: false,
        message: 'Worker is not linked to an Odoo employee id',
      );
    }

    final name = workerNameOverride ?? worker?.name ?? match.workerId ?? 'Worker';

    return _apiClient.submitTimesheet(
      TimesheetSubmitRequest.fromSiteCapture(
        projectId: draft.projectId,
        taskId: draft.taskId,
        employeeId: employeeId,
        employeeName: name,
        capturedAt: draft.createdAt,
        isCheckOut: draft.event == 'checkOut',
      ),
    );
  }

  Future<void> enqueueDraft(AttendanceCaptureDraft draft) {
    return _queueService.enqueue(draft);
  }

  Future<void> markDraftSynced(String draftId) {
    return _queueService.markSynced(draftId);
  }

  Worker? _resolveWorker(String? workerId, List<Worker> workers) {
    if (workerId == null) return null;
    for (final worker in workers) {
      if (worker.id == workerId) return worker;
    }
    return null;
  }

  int? _parseEmployeeId(String? workerId) {
    if (workerId == null) return null;
    final direct = int.tryParse(workerId);
    if (direct != null) return direct;
    if (workerId.startsWith('emp_')) {
      return int.tryParse(workerId.substring(4));
    }
    switch (workerId) {
      case 'w_ahmed':
        return 101;
      case 'w_bilal':
        return 102;
      case 'w_carlos':
        return 103;
      default:
        return null;
    }
  }
}

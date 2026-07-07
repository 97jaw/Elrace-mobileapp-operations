class TimesheetMatchAttendanceResult {
  const TimesheetMatchAttendanceResult({
    required this.result,
    required this.similarity,
    this.workerId,
    this.attendanceId,
    required this.outsideGeofence,
    required this.taskMembership,
  });

  final String result;
  final double similarity;
  final String? workerId;
  final String? attendanceId;
  final bool outsideGeofence;
  final bool taskMembership;

  Map<String, dynamic> toJson() {
    return {
      'result': result,
      'similarity': similarity,
      'worker_id': workerId,
      'attendance_id': attendanceId,
      'outside_geofence': outsideGeofence,
      'task_membership': taskMembership,
    };
  }
}

class TimesheetFunctionsClient {
  Future<Map<String, dynamic>> enrollWorkerFace({
    required String workerId,
    required String projectId,
    required List<String> photoUrls,
  }) async {
    // TODO(backend): Replace mock with callable enrollWorkerFace.
    // See Module 6 SRD §14.2.
    await Future<void>.delayed(const Duration(milliseconds: 260));
    return {
      'success': true,
      'face_id': 'mock_${projectId}_$workerId',
    };
  }

  Future<TimesheetMatchAttendanceResult> matchAttendance({
    required String projectId,
    required String taskId,
    required String cropUrl,
    required double lat,
    required double lon,
    required String event,
  }) async {
    // TODO(backend): Replace mock with callable matchAttendance.
    // See Module 6 SRD §14.2.
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final hash = '$projectId|$taskId|$cropUrl|$event'.codeUnits.fold<int>(
          0,
          (previous, element) => previous + element,
        );
    final variant = hash % 3;
    if (variant == 0) {
      return const TimesheetMatchAttendanceResult(
        result: 'matched',
        similarity: 97.2,
        workerId: 'w_ahmed',
        attendanceId: 'att_mock_001',
        outsideGeofence: false,
        taskMembership: true,
      );
    }
    if (variant == 1) {
      return const TimesheetMatchAttendanceResult(
        result: 'needs_confirmation',
        similarity: 92.4,
        workerId: 'w_bilal',
        attendanceId: null,
        outsideGeofence: false,
        taskMembership: true,
      );
    }
    return const TimesheetMatchAttendanceResult(
      result: 'no_match',
      similarity: 84.6,
      workerId: null,
      attendanceId: null,
      outsideGeofence: false,
      taskMembership: false,
    );
  }

  Future<Map<String, dynamic>> deleteWorkerFace({
    required String workerId,
    required String projectId,
  }) async {
    // TODO(backend): Replace mock with callable deleteWorkerFace.
    // See Module 6 SRD §14.2.
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return {
      'success': true,
      'worker_id': workerId,
      'project_id': projectId,
    };
  }
}

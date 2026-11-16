class ItHardwareRequest {
  const ItHardwareRequest({
    required this.id,
    required this.requestNumber,
    required this.requestType,
    required this.requestDate,
    required this.requester,
    required this.requesterDepartment,
    required this.hardwareUser,
    required this.employeeId,
    required this.department,
    required this.currentApprover,
    required this.project,
    required this.projectManager,
    required this.status,
    required this.imageUrl,
    required this.isDebug,
  });

  final String id;
  final String requestNumber;
  final String requestType;
  final String requestDate;
  final String requester;
  final String requesterDepartment;
  final String hardwareUser;
  final String employeeId;
  final String department;
  final String currentApprover;
  final String project;
  final String projectManager;
  final String status;
  final String imageUrl;
  final bool isDebug;

  factory ItHardwareRequest.fromMap(Map<String, dynamic> map) {
    return ItHardwareRequest(
      id: _pick(map, const ['id', 'request_id']),
      requestNumber: _pick(
        map,
        const ['request_no', 'name', 'reference', 'ref_no'],
      ),
      requestType: _pick(
        map,
        const ['request_type', 'request_type_name', 'type'],
        fallback: 'IT Hardware Request',
      ),
      requestDate: _pick(
        map,
        const ['request_date', 'date', 'create_date'],
      ),
      requester: _pick(
        map,
        const ['requester_name', 'requester', 'requested_by'],
      ),
      requesterDepartment: _pick(
        map,
        const ['requester_department', 'requester_department_name'],
      ),
      hardwareUser: _pick(
        map,
        const ['hardware_user_name', 'hardware_user', 'employee_name'],
      ),
      employeeId: _pick(
        map,
        const ['employee_code', 'employee_id', 'emp_id'],
      ),
      department: _pick(
        map,
        const ['department', 'department_name'],
      ),
      currentApprover: _pick(
        map,
        const ['current_approver', 'current_approver_name', 'approver_name'],
      ),
      project: _pick(
        map,
        const ['project', 'project_name', 'project_id'],
      ),
      projectManager: _pick(
        map,
        const ['project_manager', 'project_manager_name'],
      ),
      status: _pick(map, const ['status', 'state'], fallback: 'Open'),
      imageUrl: _pick(
        map,
        const ['employee_image', 'image_url', 'emp_image_url', 'photo_url'],
      ),
      isDebug: map['is_debug'] == true ||
          _pick(map, const ['id']).startsWith('LOCAL_FAKE_IT_'),
    );
  }

  static String _pick(
    Map<String, dynamic> map,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = _asText(map[key]);
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  static String _asText(dynamic value) {
    if (value == null || value == false || value == true) return '';
    if (value is List) {
      if (value.length > 1) return _asText(value[1]);
      if (value.isNotEmpty) return _asText(value.first);
      return '';
    }
    if (value is Map) {
      for (final key in const ['name', 'display_name', 'label']) {
        final nested = _asText(value[key]);
        if (nested.isNotEmpty) return nested;
      }
      return '';
    }
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }
}

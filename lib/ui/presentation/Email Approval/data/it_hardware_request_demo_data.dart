import 'package:flutter/foundation.dart';

abstract final class ItHardwareRequestDemoData {
  static List<Map<String, dynamic>> get waitingItems {
    if (!kDebugMode) return const [];

    return const [
      {
        'id': 'LOCAL_FAKE_IT_14665',
        'request_no': 'REQ/2026/14665',
        'request_type': 'IT Hardware Request',
        'request_date': '16/11/2026',
        'requester_name': 'Qossay Naji Ali Bahlool',
        'requester_department': 'IT',
        'hardware_user_name': 'Qossay Naji Ali Bahlool',
        'employee_id': '3377',
        'department': 'IT',
        'current_approver': 'IT Manager',
        'project': 'Head Office',
        'project_manager': 'Mohammed Jawad',
        'status': 'Open',
        'category': 'IT Hardware Request',
        'is_debug': true,
      },
      {
        'id': 'LOCAL_FAKE_IT_14632',
        'request_no': 'REQ/2026/14632',
        'request_type': 'IT Hardware Request',
        'request_date': '15/11/2026',
        'requester_name': 'Ahmed Khalid',
        'requester_department': 'Operations',
        'hardware_user_name': 'Ahmed Khalid',
        'employee_id': '2841',
        'department': 'Operations',
        'current_approver': 'IT Manager',
        'status': 'Open',
        'category': 'IT Hardware Request',
        'is_debug': true,
      },
      {
        'id': 'LOCAL_FAKE_IT_14598',
        'request_no': 'REQ/2026/14598',
        'request_type': 'IT Hardware Request',
        'request_date': '14/11/2026',
        'requester_name': 'Mariam Hassan',
        'requester_department': 'Finance',
        'hardware_user_name': 'Mariam Hassan',
        'employee_id': '3104',
        'department': 'Finance',
        'project': 'Corporate Services',
        'project_manager': 'Sara Ahmed',
        'status': 'Open',
        'category': 'IT Hardware Request',
        'is_debug': true,
      },
    ];
  }
}

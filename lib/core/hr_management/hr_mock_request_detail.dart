import 'package:el_race/core/hr_management/hr_mock_requests.dart';
import 'package:el_race/core/hr_management/hr_mock_team_requests.dart';
import 'package:el_race/core/hr_management/models/hr_request_detail.dart';
import 'package:el_race/core/hr_management/models/hr_request_summary.dart';

Map<String, dynamic>? _summaryMapById(String id) {
  for (final m in hrMockMyRequestsJson()) {
    if (m['id']?.toString() == id) {
      return Map<String, dynamic>.from(m);
    }
  }
  for (final m in hrMockTeamRequestsJson()) {
    if (m['id']?.toString() == id) {
      return Map<String, dynamic>.from(m);
    }
  }
  for (final m in hrMockTeamArchiveJson()) {
    if (m['id']?.toString() == id) {
      return Map<String, dynamic>.from(m);
    }
  }
  return null;
}

bool _isLeaveName(String type) {
  final t = type.toLowerCase();
  return t.contains('leave') ||
      t.contains('permission') ||
      t.contains('mission') ||
      t.contains('encashment') ||
      t.contains('compensation');
}

/// Mock JSON for [HrRequestDetail.fromJson]. [managerContext] adjusts timeline labels.
Map<String, dynamic> hrMockRequestDetailJson(
  String id, {
  required bool managerContext,
}) {
  final sm = _summaryMapById(id) ??
      Map<String, dynamic>.from(hrMockMyRequestsJson().first);
  final summary = HrRequestSummary.fromJson(sm);
  final leave = _isLeaveName(summary.type);

  final pending = summary.uiStatus.toUpperCase() == 'PENDING';
  final approveTitle =
      managerContext && pending ? 'To Approve (You)' : 'To Approve (Manager)';

  final timeline = <Map<String, dynamic>>[
    {
      'title': 'Submitted',
      'subtitle': summary.submittedAtLabel ?? '—',
      'state': 'COMPLETED',
    },
    if (pending)
      {
        'title': approveTitle,
        'subtitle': null,
        'state': 'CURRENT',
      }
    else ...[
      {
        'title': approveTitle,
        'subtitle': 'Approved',
        'state': 'COMPLETED',
      },
      {
        'title': 'HR validation',
        'subtitle': summary.uiStatus.toUpperCase() == 'APPROVED'
            ? 'Recorded'
            : '—',
        'state': summary.uiStatus.toUpperCase() == 'APPROVED'
            ? 'COMPLETED'
            : 'PENDING',
      },
    ],
  ];

  final detailRows = <Map<String, dynamic>>[
    {'label': 'Request type', 'value': summary.type},
    if (leave) ...[
      {'label': 'From date', 'value': '12 May 2026'},
      {'label': 'To date', 'value': '16 May 2026'},
      {'label': 'Number of days', 'value': '5'},
    ] else ...[
      {'label': 'Effective / window', 'value': summary.secondaryLine ?? '—'},
    ],
    {'label': 'Reason', 'value': 'Mock justification for ${summary.referenceNumber}'},
  ];

  final attachments = <Map<String, dynamic>>[
    if (summary.type.toLowerCase().contains('sim') ||
        summary.type.toLowerCase().contains('car'))
      {'name': 'supporting_doc.pdf', 'url': null},
  ];

  final comments = <Map<String, dynamic>>[
    if (summary.uiStatus.toUpperCase() == 'REJECTED')
      {
        'author': 'Line Manager',
        'text': 'Please adjust dates and resubmit.',
        'timestamp': '01 May 2026',
      },
  ];

  Map<String, dynamic>? subject;
  if (managerContext &&
      sm['employee_name'] != null &&
      sm['employee_name'].toString().isNotEmpty) {
    subject = {
      'name': sm['employee_name']?.toString() ?? '',
      'position_department': sm['employee_role_line']?.toString() ?? '',
      'employee_id': sm['employee_number']?.toString() ?? '',
      'email':
          '${(sm['employee_name']?.toString() ?? 'user').split(' ').first.toLowerCase()}@elrace.com',
      'phone': '+971 50 000 0000',
    };
  }

  return {
    'summary': sm,
    'submitted_at_display':
        '${summary.submittedAtLabel ?? '—'}${summary.relativeSubmittedLabel != null ? ' · ${summary.relativeSubmittedLabel}' : ''}',
    'detail_rows': detailRows,
    'timeline': timeline,
    'attachments': attachments,
    'comments': comments,
    'is_leave_type': leave,
    if (leave && managerContext) 'available_leave_balance': '18 days',
    if (subject != null) 'subject_employee': subject,
  };
}

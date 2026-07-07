import 'package:el_race/core/hr_management/models/hr_request_summary.dart';

/// JSON maps for mock API — single source for [HrApiClient] and summaries.
List<Map<String, dynamic>> hrMockMyRequestsJson() {
  return [
    _m(
      id: '1',
      ref: 'HR/LV/2026/0142',
      type: 'Annual Leave',
      status: 'PENDING',
      submitted: '12 May 2026',
      secondary: '12 May → 16 May (5 days)',
      relative: 'Submitted 2d ago',
      seq: 100,
    ),
    _m(
      id: '2',
      ref: 'HR/CR/2026/0089',
      type: 'Car Rent Request',
      status: 'APPROVED',
      submitted: '4 May 2026',
      secondary: '04 May → 04 May (1 day)',
      relative: 'Submitted 6d ago',
      seq: 94,
    ),
    _m(
      id: '3',
      ref: 'HR/TP/2026/0233',
      type: 'Temporary Permission',
      status: 'APPROVED',
      submitted: '2 May 2026',
      secondary: '02 May, 14:00 → 16:00',
      relative: 'Submitted 8d ago',
      seq: 92,
    ),
    _m(
      id: '4',
      ref: 'HR/LV/2026/0101',
      type: 'Sick Leave',
      status: 'APPROVED',
      submitted: '28 Apr 2026',
      secondary: '28 Apr (1 day)',
      relative: 'Submitted 12d ago',
      seq: 88,
    ),
    _m(
      id: '5',
      ref: 'HR/SIM/2026/0044',
      type: 'SIM Card Request',
      status: 'PENDING',
      submitted: '8 May 2026',
      secondary: 'Required by 15 May 2026',
      relative: 'Submitted 4d ago',
      seq: 96,
    ),
    _m(
      id: '6',
      ref: 'HR/CA/2026/0012',
      type: 'Car Allowance',
      status: 'DRAFT',
      submitted: null,
      secondary: 'Effective from 1 Jun 2026',
      relative: 'Draft',
      seq: 90,
    ),
    _m(
      id: '7',
      ref: 'HR/LV/2026/0098',
      type: 'Short Leave',
      status: 'REJECTED',
      submitted: '30 Apr 2026',
      secondary: '30 Apr, 09:00 → 13:00',
      relative: 'Submitted 10d ago',
      seq: 86,
    ),
    _m(
      id: '8',
      ref: 'HR/JM/2026/0031',
      type: 'Job Mission',
      status: 'PENDING',
      submitted: '9 May 2026',
      secondary: '15 May → 18 May',
      relative: 'Submitted 3d ago',
      seq: 97,
    ),
    _m(
      id: '9',
      ref: 'HR/LV/2026/0077',
      type: 'Annual Leave',
      status: 'DRAFT',
      submitted: null,
      secondary: '1 Jun → 5 Jun (5 days)',
      relative: 'Draft',
      seq: 84,
    ),
    _m(
      id: '10',
      ref: 'HR/LV/2026/0155',
      type: 'Annual Leave',
      status: 'APPROVED',
      submitted: '11 May 2026',
      secondary: '20 May → 24 May (5 days)',
      relative: 'Submitted 1d ago',
      seq: 99,
    ),
  ];
}

Map<String, dynamic> _m({
  required String id,
  required String ref,
  required String type,
  required String status,
  String? submitted,
  String? secondary,
  String? relative,
  required int seq,
}) {
  return {
    'id': id,
    'reference': ref,
    'type': type,
    'ui_status': status,
    if (submitted != null) 'submitted_at': submitted,
    if (secondary != null) 'secondary_line': secondary,
    if (relative != null) 'relative_submitted': relative,
    'sequence': seq,
  };
}

List<HrRequestSummary> hrMockRequestSummaries() {
  return hrMockMyRequestsJson().map(HrRequestSummary.fromJson).toList();
}

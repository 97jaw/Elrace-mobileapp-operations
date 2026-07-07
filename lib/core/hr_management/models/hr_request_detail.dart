import 'package:el_race/core/hr_management/models/hr_request_summary.dart';

/// Step in the vertical status timeline (SRD §3.3).
enum HrTimelineStepState { completed, current, pending }

class HrTimelineStep {
  const HrTimelineStep({
    required this.title,
    this.subtitle,
    required this.state,
  });

  final String title;
  final String? subtitle;
  final HrTimelineStepState state;
}

class HrAttachmentItem {
  const HrAttachmentItem({required this.name, this.url});

  final String name;
  final String? url;
}

class HrCommentItem {
  const HrCommentItem({
    required this.author,
    required this.text,
    this.timestamp,
  });

  final String author;
  final String text;
  final String? timestamp;
}

/// Snapshot for [HrEmployeeInfoCard] on manager detail (SRD §4.3).
class HrEmployeeSubject {
  const HrEmployeeSubject({
    required this.name,
    required this.positionDepartmentLine,
    required this.employeeId,
    this.email,
    this.phone,
  });

  final String name;
  final String positionDepartmentLine;
  final String employeeId;
  final String? email;
  final String? phone;
}

/// Full request payload for E3 / M3 — mock + future API.
class HrRequestDetail {
  const HrRequestDetail({
    required this.summary,
    required this.submittedAtDisplay,
    required this.detailRows,
    required this.timeline,
    this.attachments = const [],
    this.comments = const [],
    this.availableLeaveBalance,
    this.subjectEmployee,
    this.isLeaveType = false,
  });

  final HrRequestSummary summary;
  final String submittedAtDisplay;
  final List<(String label, String value)> detailRows;
  final List<HrTimelineStep> timeline;
  final List<HrAttachmentItem> attachments;
  final List<HrCommentItem> comments;
  final String? availableLeaveBalance;
  final HrEmployeeSubject? subjectEmployee;
  final bool isLeaveType;

  factory HrRequestDetail.fromJson(Map<String, dynamic> json) {
    final summaryMap =
        Map<String, dynamic>.from(json['summary'] as Map? ?? {});
    final rowsRaw = json['detail_rows'] as List<dynamic>? ?? [];
    final timelineRaw = json['timeline'] as List<dynamic>? ?? [];
    final attachRaw = json['attachments'] as List<dynamic>? ?? [];
    final commentsRaw = json['comments'] as List<dynamic>? ?? [];
    final subRaw = json['subject_employee'] as Map<String, dynamic>?;

    HrTimelineStepState parseState(String? s) {
      switch (s?.toUpperCase()) {
        case 'CURRENT':
          return HrTimelineStepState.current;
        case 'PENDING':
          return HrTimelineStepState.pending;
        default:
          return HrTimelineStepState.completed;
      }
    }

    return HrRequestDetail(
      summary: HrRequestSummary.fromJson(summaryMap),
      submittedAtDisplay: json['submitted_at_display']?.toString() ?? '—',
      detailRows: rowsRaw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return (m['label']?.toString() ?? '', m['value']?.toString() ?? '');
      }).toList(),
      timeline: timelineRaw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return HrTimelineStep(
          title: m['title']?.toString() ?? '',
          subtitle: m['subtitle']?.toString(),
          state: parseState(m['state']?.toString()),
        );
      }).toList(),
      attachments: attachRaw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return HrAttachmentItem(
          name: m['name']?.toString() ?? 'file',
          url: m['url']?.toString(),
        );
      }).toList(),
      comments: commentsRaw.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return HrCommentItem(
          author: m['author']?.toString() ?? '',
          text: m['text']?.toString() ?? '',
          timestamp: m['timestamp']?.toString(),
        );
      }).toList(),
      availableLeaveBalance: json['available_leave_balance']?.toString(),
      subjectEmployee: subRaw == null
          ? null
          : HrEmployeeSubject(
              name: subRaw['name']?.toString() ?? '',
              positionDepartmentLine:
                  subRaw['position_department']?.toString() ?? '',
              employeeId: subRaw['employee_id']?.toString() ?? '',
              email: subRaw['email']?.toString(),
              phone: subRaw['phone']?.toString(),
            ),
      isLeaveType: json['is_leave_type'] == true,
    );
  }
}

/// Riverpod family key for detail fetch.
class HrDetailQuery {
  const HrDetailQuery({required this.id, required this.managerContext});

  final String id;
  final bool managerContext;

  @override
  bool operator ==(Object other) =>
      other is HrDetailQuery &&
      other.id == id &&
      other.managerContext == managerContext;

  @override
  int get hashCode => Object.hash(id, managerContext);
}

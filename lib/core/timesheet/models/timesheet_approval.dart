import 'package:cloud_firestore/cloud_firestore.dart';

/// Role of an approver on a timesheet approval document.
enum TimesheetApproverRole {
  siteEngineer,
  projectsManager;

  static TimesheetApproverRole fromString(String? value) {
    switch (value) {
      case 'projects_manager':
        return TimesheetApproverRole.projectsManager;
      case 'site_engineer':
      default:
        return TimesheetApproverRole.siteEngineer;
    }
  }

  String toJson() {
    switch (this) {
      case TimesheetApproverRole.projectsManager:
        return 'projects_manager';
      case TimesheetApproverRole.siteEngineer:
        return 'site_engineer';
    }
  }

  String get shortLabel {
    switch (this) {
      case TimesheetApproverRole.siteEngineer:
        return 'SE';
      case TimesheetApproverRole.projectsManager:
        return 'PM';
    }
  }

  String get displayLabel {
    switch (this) {
      case TimesheetApproverRole.siteEngineer:
        return 'Site Engineer';
      case TimesheetApproverRole.projectsManager:
        return 'Projects Manager';
    }
  }
}

enum TimesheetApproverStatus {
  pending,
  approved,
  rejected;

  static TimesheetApproverStatus fromString(String? value) {
    switch (value) {
      case 'approved':
        return TimesheetApproverStatus.approved;
      case 'rejected':
        return TimesheetApproverStatus.rejected;
      case 'pending':
      default:
        return TimesheetApproverStatus.pending;
    }
  }

  String toJson() => name;
}

enum TimesheetApprovalStatus {
  pending,
  approved,
  rejected;

  static TimesheetApprovalStatus fromString(String? value) {
    switch (value) {
      case 'approved':
        return TimesheetApprovalStatus.approved;
      case 'rejected':
        return TimesheetApprovalStatus.rejected;
      case 'pending':
      default:
        return TimesheetApprovalStatus.pending;
    }
  }

  String toJson() => name;
}

/// One Site Engineer / Projects Manager stamp cell on a labour page.
class TimesheetApprovalCell {
  const TimesheetApprovalCell({
    required this.page,
    required this.role,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int page;
  final TimesheetApproverRole role;
  final double x;
  final double y;
  final double width;
  final double height;

  factory TimesheetApprovalCell.fromMap(Map<String, dynamic> data) {
    return TimesheetApprovalCell(
      page: (data['page'] as num?)?.toInt() ?? 0,
      role: TimesheetApproverRole.fromString(data['role']?.toString()),
      x: (data['x'] as num?)?.toDouble() ?? 0,
      y: (data['y'] as num?)?.toDouble() ?? 0,
      width: (data['width'] as num?)?.toDouble() ?? 0,
      height: (data['height'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'page': page,
        'role': role.toJson(),
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
}

class TimesheetApproverEntry {
  const TimesheetApproverEntry({
    required this.role,
    required this.name,
    required this.status,
    this.actedAt,
  });

  final TimesheetApproverRole role;
  final String name;
  final TimesheetApproverStatus status;
  final DateTime? actedAt;

  factory TimesheetApproverEntry.fromMap(Map<String, dynamic> data) {
    return TimesheetApproverEntry(
      role: TimesheetApproverRole.fromString(data['role']?.toString()),
      name: data['name']?.toString() ?? '',
      status: TimesheetApproverStatus.fromString(data['status']?.toString()),
      actedAt: (data['acted_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap({bool includeActedAt = false}) {
    final map = <String, dynamic>{
      'role': role.toJson(),
      'name': name,
      'status': status.toJson(),
    };
    if (includeActedAt && actedAt != null) {
      map['acted_at'] = Timestamp.fromDate(actedAt!);
    }
    return map;
  }

  TimesheetApproverEntry copyWith({
    TimesheetApproverStatus? status,
    DateTime? actedAt,
  }) {
    return TimesheetApproverEntry(
      role: role,
      name: name,
      status: status ?? this.status,
      actedAt: actedAt ?? this.actedAt,
    );
  }
}

/// Firestore `timesheet_approvals/{id}`.
class TimesheetApproval {
  const TimesheetApproval({
    required this.id,
    required this.ownerUid,
    required this.ownerName,
    required this.fileName,
    required this.projectId,
    required this.projectName,
    required this.pageCount,
    required this.pdfPath,
    required this.approvers,
    required this.approverUids,
    required this.pendingUids,
    required this.status,
    required this.cells,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerUid;
  final String ownerName;
  final String fileName;
  final String projectId;
  final String projectName;
  final int pageCount;
  final String pdfPath;
  final Map<String, TimesheetApproverEntry> approvers;
  final List<String> approverUids;
  final List<String> pendingUids;
  final TimesheetApprovalStatus status;
  final List<TimesheetApprovalCell> cells;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool isPendingFor(String uid) => pendingUids.contains(uid);

  TimesheetApproverRole? myRole(String uid) => approvers[uid]?.role;

  /// Foreman list label.
  String get statusLabel {
    switch (status) {
      case TimesheetApprovalStatus.approved:
        return 'Approved';
      case TimesheetApprovalStatus.rejected:
        return 'Rejected';
      case TimesheetApprovalStatus.pending:
        break;
    }
    final pendingRoles = pendingUids
        .map((uid) => approvers[uid]?.role)
        .whereType<TimesheetApproverRole>()
        .toSet();
    final hasSe = pendingRoles.contains(TimesheetApproverRole.siteEngineer);
    final hasPm = pendingRoles.contains(TimesheetApproverRole.projectsManager);
    if (hasSe && hasPm) return 'Pending with SE & PM';
    if (hasSe) return 'Pending with SE';
    if (hasPm) return 'Pending with PM';
    return 'Pending';
  }

  factory TimesheetApproval.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TimesheetApproval.fromMap(doc.id, data);
  }

  factory TimesheetApproval.fromMap(String id, Map<String, dynamic> data) {
    final rawApprovers = data['approvers'];
    final approvers = <String, TimesheetApproverEntry>{};
    if (rawApprovers is Map) {
      for (final entry in rawApprovers.entries) {
        final value = entry.value;
        if (value is Map) {
          approvers[entry.key.toString()] =
              TimesheetApproverEntry.fromMap(Map<String, dynamic>.from(value));
        }
      }
    }

    final cells = <TimesheetApprovalCell>[];
    final rawCells = data['cells'];
    if (rawCells is List) {
      for (final item in rawCells) {
        if (item is Map) {
          cells.add(
            TimesheetApprovalCell.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return TimesheetApproval(
      id: id,
      ownerUid: data['owner_uid']?.toString() ?? '',
      ownerName: data['owner_name']?.toString() ?? '',
      fileName: data['file_name']?.toString() ?? 'Timesheet.pdf',
      projectId: data['project_id']?.toString() ?? '',
      projectName: data['project_name']?.toString() ?? '',
      pageCount: (data['page_count'] as num?)?.toInt() ?? 0,
      pdfPath: data['pdf_path']?.toString() ?? '',
      approvers: approvers,
      approverUids: data['approver_uids'] is List
          ? List<String>.from(data['approver_uids'] as List)
          : const [],
      pendingUids: data['pending_uids'] is List
          ? List<String>.from(data['pending_uids'] as List)
          : const [],
      status: TimesheetApprovalStatus.fromString(data['status']?.toString()),
      cells: cells,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore({bool isUpdate = false}) {
    final map = <String, dynamic>{
      'owner_uid': ownerUid,
      'owner_name': ownerName,
      'file_name': fileName,
      'project_id': projectId,
      'project_name': projectName,
      'page_count': pageCount,
      'pdf_path': pdfPath,
      'approvers': {
        for (final entry in approvers.entries)
          entry.key: entry.value.toMap(includeActedAt: entry.value.actedAt != null),
      },
      'approver_uids': approverUids,
      'pending_uids': pendingUids,
      'status': status.toJson(),
      'cells': cells.map((c) => c.toMap()).toList(),
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (!isUpdate) {
      map['created_at'] = FieldValue.serverTimestamp();
    }
    return map;
  }
}

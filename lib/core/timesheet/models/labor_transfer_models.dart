import 'package:el_race/core/timesheet/models/timesheet_model_parsers.dart';

/// Person card shared by labor-transfer API payloads.
class LaborTransferPerson {
  const LaborTransferPerson({
    required this.id,
    required this.name,
    this.empId,
    this.photo,
    this.cityId,
    this.cityName,
    this.sameCity,
  });

  final int id;
  final String name;
  final String? empId;
  final String? photo;
  final int? cityId;
  final String? cityName;
  final bool? sameCity;

  factory LaborTransferPerson.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const LaborTransferPerson(id: 0, name: '');
    }
    return LaborTransferPerson(
      id: tmIntFromJson(json['id']),
      name: tmStringFromJson(json['name']),
      empId: tmStringFromJson(json['emp_id']).isEmpty
          ? null
          : tmStringFromJson(json['emp_id']),
      photo: tmStringFromJson(json['photo']).isEmpty
          ? null
          : tmStringFromJson(json['photo']),
      cityId: tmIntOrNullFromJson(json['city_id']),
      cityName: tmStringFromJson(json['city_name']).isEmpty
          ? null
          : tmStringFromJson(json['city_name']),
      sameCity: json.containsKey('same_city')
          ? tmBoolFromJson(json['same_city'])
          : null,
    );
  }
}

/// Selectable labor for a new transfer request.
class LaborTransferLaborOption {
  const LaborTransferLaborOption({
    required this.id,
    required this.empId,
    required this.name,
    this.photo,
    this.currentForeman,
    required this.inPendingTransfer,
    required this.inMyTeam,
  });

  final int id;
  final String empId;
  final String name;
  final String? photo;
  final LaborTransferPerson? currentForeman;
  final bool inPendingTransfer;
  final bool inMyTeam;

  bool get isSelectable => !inPendingTransfer && !inMyTeam;

  factory LaborTransferLaborOption.fromJson(Map<String, dynamic> json) {
    final foremanRaw = json['current_foreman'];
    return LaborTransferLaborOption(
      id: tmIntFromJson(json['id']),
      empId: tmStringFromJson(json['emp_id']),
      name: tmStringFromJson(json['name']),
      photo: tmStringFromJson(json['photo']).isEmpty
          ? null
          : tmStringFromJson(json['photo']),
      currentForeman: foremanRaw is Map
          ? LaborTransferPerson.fromJson(Map<String, dynamic>.from(foremanRaw))
          : null,
      inPendingTransfer: tmBoolFromJson(json['in_pending_transfer']),
      inMyTeam: tmBoolFromJson(json['in_my_team']),
    );
  }
}

/// Detail line: labor + previous foreman snapshot.
class LaborTransferLine {
  const LaborTransferLine({
    required this.labor,
    this.previousForeman,
  });

  final LaborTransferPerson labor;
  final LaborTransferPerson? previousForeman;

  factory LaborTransferLine.fromJson(Map<String, dynamic> json) {
    final laborRaw = json['labor'];
    final prevRaw = json['previous_foreman'];
    return LaborTransferLine(
      labor: LaborTransferPerson.fromJson(
        laborRaw is Map ? Map<String, dynamic>.from(laborRaw) : null,
      ),
      previousForeman: prevRaw is Map
          ? LaborTransferPerson.fromJson(Map<String, dynamic>.from(prevRaw))
          : null,
    );
  }
}

enum LaborTransferState {
  draft,
  pending,
  partiallyApproved,
  approved,
  rejected,
  cancelled,
  unknown;

  static LaborTransferState fromApi(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'draft':
        return LaborTransferState.draft;
      case 'pending':
        return LaborTransferState.pending;
      case 'partially_approved':
        return LaborTransferState.partiallyApproved;
      case 'approved':
        return LaborTransferState.approved;
      case 'rejected':
        return LaborTransferState.rejected;
      case 'cancelled':
        return LaborTransferState.cancelled;
      default:
        return LaborTransferState.unknown;
    }
  }

  String get apiValue {
    switch (this) {
      case LaborTransferState.draft:
        return 'draft';
      case LaborTransferState.pending:
        return 'pending';
      case LaborTransferState.partiallyApproved:
        return 'partially_approved';
      case LaborTransferState.approved:
        return 'approved';
      case LaborTransferState.rejected:
        return 'rejected';
      case LaborTransferState.cancelled:
        return 'cancelled';
      case LaborTransferState.unknown:
        return '';
    }
  }

  String get label {
    switch (this) {
      case LaborTransferState.draft:
        return 'Draft';
      case LaborTransferState.pending:
        return 'Pending';
      case LaborTransferState.partiallyApproved:
        return '1 of 2 approved';
      case LaborTransferState.approved:
        return 'Approved';
      case LaborTransferState.rejected:
        return 'Rejected';
      case LaborTransferState.cancelled:
        return 'Cancelled';
      case LaborTransferState.unknown:
        return 'Unknown';
    }
  }

  bool get isOpen =>
      this == LaborTransferState.pending ||
      this == LaborTransferState.partiallyApproved;
}

enum LaborTransferBox {
  mine,
  toApprove,
  incoming,
  involved;

  String get apiValue {
    switch (this) {
      case LaborTransferBox.mine:
        return 'mine';
      case LaborTransferBox.toApprove:
        return 'to_approve';
      case LaborTransferBox.incoming:
        return 'incoming';
      case LaborTransferBox.involved:
        return 'involved';
    }
  }
}

/// Badge counts from `/api/labor_transfer/counts`.
class LaborTransferCounts {
  const LaborTransferCounts({
    required this.toApprove,
    required this.myRequestsPending,
    this.isApprover = false,
  });

  final int toApprove;
  final int myRequestsPending;

  /// True when the caller is from/to approver on any transfer (foreman tab gate).
  final bool isApprover;

  static const empty = LaborTransferCounts(
    toApprove: 0,
    myRequestsPending: 0,
    isApprover: false,
  );

  factory LaborTransferCounts.fromJson(Map<String, dynamic> json) {
    return LaborTransferCounts(
      toApprove: tmIntFromJson(json['to_approve']),
      myRequestsPending: tmIntFromJson(json['my_requests_pending']),
      isApprover: tmBoolFromJson(json['is_approver']) ||
          tmIntFromJson(json['to_approve']) > 0,
    );
  }
}

/// List or detail transfer record from `/api/labor_transfer/*`.
class LaborTransferRecord {
  const LaborTransferRecord({
    required this.id,
    required this.name,
    required this.state,
    required this.note,
    required this.rejectReason,
    required this.laborCount,
    this.requestDate,
    this.decisionDate,
    this.requester,
    this.targetForeman,
    this.fromApprover,
    this.toApprover,
    this.approver,
    this.sameApprover = false,
    this.fromApproved = false,
    this.toApproved = false,
    this.myPendingSide,
    this.city,
    this.lines = const [],
  });

  final int id;
  final String name;
  final LaborTransferState state;
  final String note;
  final String rejectReason;
  final int laborCount;
  final DateTime? requestDate;
  final DateTime? decisionDate;
  final LaborTransferPerson? requester;
  final LaborTransferPerson? targetForeman;
  final LaborTransferPerson? fromApprover;
  final LaborTransferPerson? toApprover;
  final LaborTransferPerson? approver;
  final bool sameApprover;
  final bool fromApproved;
  final bool toApproved;

  /// API: `from` | `to` | `both`, or null when the caller has no pending side.
  final String? myPendingSide;
  final LaborTransferPerson? city;
  final List<LaborTransferLine> lines;

  bool get canActOnApproval =>
      myPendingSide != null && myPendingSide!.trim().isNotEmpty;

  bool get isPending => state.isOpen;

  bool canCancel(int? loginEmployeeId) {
    if (!state.isOpen || loginEmployeeId == null || loginEmployeeId <= 0) {
      return false;
    }
    return requester?.id == loginEmployeeId;
  }

  /// Side status for detail approver rows.
  LtApproverSideStatus sideStatus({required bool approved}) {
    if (approved) return LtApproverSideStatus.approved;
    if (state == LaborTransferState.rejected) {
      return LtApproverSideStatus.rejected;
    }
    if (state.isOpen) return LtApproverSideStatus.pending;
    return LtApproverSideStatus.pending;
  }

  factory LaborTransferRecord.fromJson(Map<String, dynamic> json) {
    final linesRaw = json['lines'];
    final lines = <LaborTransferLine>[];
    if (linesRaw is List) {
      for (final row in linesRaw) {
        if (row is Map) {
          lines.add(
            LaborTransferLine.fromJson(Map<String, dynamic>.from(row)),
          );
        }
      }
    } else {
      final laborsRaw = json['labors'];
      if (laborsRaw is List) {
        for (final row in laborsRaw) {
          if (row is Map) {
            lines.add(
              LaborTransferLine(
                labor: LaborTransferPerson.fromJson(
                  Map<String, dynamic>.from(row),
                ),
              ),
            );
          }
        }
      }
    }

    final cityRaw = json['city'];
    final sideRaw = json['my_pending_side'];
    String? mySide;
    if (sideRaw is String && sideRaw.trim().isNotEmpty && sideRaw != 'false') {
      mySide = sideRaw.trim().toLowerCase();
    }

    return LaborTransferRecord(
      id: tmIntFromJson(json['id']),
      name: tmStringFromJson(json['name']),
      state: LaborTransferState.fromApi(tmStringFromJson(json['state'])),
      note: tmStringFromJson(json['note']),
      rejectReason: tmStringFromJson(json['reject_reason']),
      laborCount: tmIntFromJson(json['labor_count']),
      requestDate: tmDateTimeFromJson(json['request_date']),
      decisionDate: tmDateTimeFromJson(json['decision_date']),
      requester: json['requester'] is Map
          ? LaborTransferPerson.fromJson(
              Map<String, dynamic>.from(json['requester'] as Map),
            )
          : null,
      targetForeman: json['target_foreman'] is Map
          ? LaborTransferPerson.fromJson(
              Map<String, dynamic>.from(json['target_foreman'] as Map),
            )
          : null,
      fromApprover: json['from_approver'] is Map
          ? LaborTransferPerson.fromJson(
              Map<String, dynamic>.from(json['from_approver'] as Map),
            )
          : null,
      toApprover: json['to_approver'] is Map
          ? LaborTransferPerson.fromJson(
              Map<String, dynamic>.from(json['to_approver'] as Map),
            )
          : null,
      approver: json['approver'] is Map
          ? LaborTransferPerson.fromJson(
              Map<String, dynamic>.from(json['approver'] as Map),
            )
          : null,
      sameApprover: tmBoolFromJson(json['same_approver']),
      fromApproved: tmBoolFromJson(json['from_approved']),
      toApproved: tmBoolFromJson(json['to_approved']),
      myPendingSide: mySide,
      city: cityRaw is Map
          ? LaborTransferPerson(
              id: tmIntFromJson(cityRaw['id']),
              name: tmStringFromJson(cityRaw['name']),
            )
          : null,
      lines: lines,
    );
  }
}

enum LtApproverSideStatus { approved, pending, rejected }

extension LtApproverSideStatusX on LtApproverSideStatus {
  String get label => switch (this) {
        LtApproverSideStatus.approved => 'approved',
        LtApproverSideStatus.pending => 'pending',
        LtApproverSideStatus.rejected => 'rejected',
      };
}

/// Audience for the transfers list (foreman vs PM/manager).
enum LtListAudience { foreman, manager }

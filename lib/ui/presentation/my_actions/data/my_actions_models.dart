class MyActionsType {
  final String apiValue;
  final String responseKey;

  const MyActionsType._(this.apiValue, this.responseKey);

  static const invoice = MyActionsType._('invoice', 'invoice');
  static const rfq = MyActionsType._('rfq', 'rfq');
  static const hr = MyActionsType._('hr', 'hr');
  // API type is "ptsh" but response key is "petty_cash".
  static const ptsh = MyActionsType._('ptsh', 'petty_cash');
  static const signatures = MyActionsType._('signatures', 'signatures');
  static const timesheet = MyActionsType._('timesheet', 'timesheet');
  static const reports = MyActionsType._('reports', 'reports');
}

class MyActionItem {
  final int id;
  final String name;
  final String? reference;
  final String? date;
  final String? project;
  final String? vendor;
  final double? amountTotal;
  final String? requestType;
  final String status;
  final String employeeName;
  final String employeeImage;
  final String? reportLink;
  final String? clientImage;
  final String? operatingUnit;
  final String? fileId;

  const MyActionItem({
    required this.id,
    required this.name,
    required this.status,
    required this.employeeName,
    required this.employeeImage,
    this.reference,
    this.date,
    this.project,
    this.vendor,
    this.amountTotal,
    this.requestType,
    this.reportLink,
    this.clientImage,
    this.operatingUnit,
    this.fileId,
  });

  factory MyActionItem.fromJson(Map<String, dynamic> json) {
    // Parse status: handles String, Map, and other types
    String parseStatus(dynamic rawStatus) {
      if (rawStatus is String) return rawStatus;
      if (rawStatus is Map && rawStatus.isNotEmpty) {
        final first = rawStatus.values.first;
        return first?.toString() ?? '';
      }
      return rawStatus?.toString() ?? '';
    }

    // amount: try amount_total (custom), total_amount (Odoo expense sheet), amount, total
    final dynamic amountRaw = json['amount_total'] ??
        json['total_amount'] ??
        json['amount'] ??
        json['total'];

    // name: prioritize file/report names when available, then generic labels.
    final dynamic nameRaw = json['name'] ??
        json['display_name'] ??
        json['report_name'] ??
        json['file_name'] ??
        json['filename'] ??
        json['document_name'] ??
        json['attachment_name'] ??
        json['project'] ??
        json['request_type'];

    // status: try status (custom), state (Odoo standard)
    final dynamic statusRaw = json['status'] ?? json['state'];

    // employee: try employee_name, employee (Odoo), requester_name
    final dynamic empRaw =
        json['employee_name'] ?? json['employee'] ?? json['requester_name'];

    String parseFileLink(Map<String, dynamic> data) {
      final candidates = <dynamic>[
        data['report_link'],
        data['file_url'],
        data['document_url'],
        data['attachment_url'],
        data['signed_file_url'],
        data['url'],
        data['public_url'],
        data['access_url'],
        data['download_url'],
        data['pdf_url'],
        data['file_link'],
        data['report_url'],
        data['link'],
        data['media_url'],
        data['path'],
      ];

      for (final c in candidates) {
        final s = _safeString(c).trim();
        if (s.isNotEmpty) {
          return s;
        }
      }

      final attachment = data['attachment'];
      if (attachment is Map) {
        final map = Map<String, dynamic>.from(attachment);
        final nested = _safeString(
          map['url'] ?? map['link'] ?? map['public_url'] ?? map['download_url'],
        ).trim();
        if (nested.isNotEmpty) {
          return nested;
        }
      }

      return '';
    }

    return MyActionItem(
      id: (json['id'] as num?)?.toInt() ??
          (json['parent_id'] as num?)?.toInt() ??
          0,
      name: _safeString(nameRaw),
      reference:
          _safeString(json['reference'] ?? json['ref'] ?? json['number']),
        date: _safeString(json['last_updated_on'] ??
          json['updated_at'] ??
          json['write_date'] ??
          json['create_date'] ??
          json['accounting_date'] ??
          json['date']),
      project: _safeString(json['project']),
      vendor: _safeString(json['vendor']),
      amountTotal: amountRaw is num
          ? amountRaw.toDouble()
          : double.tryParse(amountRaw?.toString() ?? ''),
      requestType: _safeString(json['request_type']),
      status: parseStatus(statusRaw),
      employeeName: _safeString(empRaw),
      employeeImage: json['employee_image']?.toString() ?? '',
      reportLink: parseFileLink(json),
      clientImage: _safeString(json['client_image']),
      operatingUnit: _safeString(json['operating_unit']),
      fileId: _safeString(
        json['file_id'] ??
            json['employee_file_id'] ??
            json['emp_profile_id'] ??
            json['employee_id'],
      ),
    );
  }

  /// Safely convert Odoo values — treats false/true/null as empty string.
  static String _safeString(dynamic v) {
    if (v == null || v == false || v == true) return '';
    final s = v.toString();
    final lower = s.toLowerCase();
    if (lower == 'false' || lower == 'null') return '';
    return s;
  }
}

/// One row from detail API `approvals[]` (review_ids / request_approvals_ids).
class MyActionApprovalStep {
  const MyActionApprovalStep({
    required this.name,
    required this.status,
    this.id,
    this.sequence,
    this.image,
    this.description,
    this.approveTime,
    this.comments,
  });

  final int? id;
  final String name;
  final String status;
  final int? sequence;
  final String? image;
  final String? description;
  final String? approveTime;
  final String? comments;

  factory MyActionApprovalStep.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['validation_status'] ?? json['status'];
    String status;
    if (rawStatus is bool) {
      status = rawStatus ? 'approved' : 'pending';
    } else {
      status = MyActionItem._safeString(rawStatus).toLowerCase();
      if (status.isEmpty) status = 'pending';
      if (status == 'true') status = 'approved';
      if (status == 'false') status = 'pending';
    }
    if (json['skipped'] == true && status == 'pending') {
      status = 'skipped';
    }

    final seq = json['sequence'];
    final approveRaw = json['approve_time'] ?? json['reviewed_date'];
    return MyActionApprovalStep(
      id: (json['id'] as num?)?.toInt() ??
          (json['validator_user_id'] as num?)?.toInt(),
      name: MyActionItem._safeString(
        json['name'] ??
            json['validator'] ??
            json['approver'] ??
            json['validating_users'],
      ),
      status: status,
      sequence: seq is num ? seq.toInt() : int.tryParse('$seq'),
      image: MyActionItem._safeString(json['image']).isEmpty
          ? null
          : MyActionItem._safeString(json['image']),
      description: MyActionItem._safeString(json['description']).isEmpty
          ? null
          : MyActionItem._safeString(json['description']),
      approveTime: MyActionItem._safeString(approveRaw).isEmpty
          ? null
          : MyActionItem._safeString(approveRaw),
      comments: MyActionItem._safeString(json['comments']).isEmpty
          ? null
          : MyActionItem._safeString(json['comments']),
    );
  }
}

/// Detail payload used by the My Actions record preview sheet.
class MyActionRecordPreview {
  const MyActionRecordPreview({
    required this.approvals,
    this.headerExtras = const {},
  });

  final List<MyActionApprovalStep> approvals;

  /// Extra key/value pairs for the header (from form_view / request_info).
  final Map<String, String> headerExtras;

  factory MyActionRecordPreview.fromDetailData(
    Map<String, dynamic> data, {
    required MyActionsType type,
  }) {
    final approvalsRaw = data['approvals'];
    final approvals = approvalsRaw is List
        ? approvalsRaw
            .whereType<Map>()
            .map((e) => MyActionApprovalStep.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : const <MyActionApprovalStep>[];

    final extras = <String, String>{};
    void put(String label, dynamic value) {
      final s = MyActionItem._safeString(value).trim();
      if (s.isEmpty || s == 'N/A') return;
      extras[label] = s;
    }

    if (type == MyActionsType.hr) {
      final requestInfo =
          (data['request_info'] as Map?)?.cast<String, dynamic>() ?? const {};
      final employeeInfo =
          (data['employee_info'] as Map?)?.cast<String, dynamic>() ?? const {};
      // No Request / Department in header (title already covers request no).
      put(
        'Type',
        requestInfo['request_name'] ?? requestInfo['leave_request_subtype'],
      );
      put(
        'Employee',
        employeeInfo['employee_name'] ?? requestInfo['requested_by'],
      );
      put(
        'From',
        requestInfo['request_date_from'] ?? requestInfo['start_date'],
      );
      put('To', requestInfo['request_date_to'] ?? requestInfo['end_date']);
    } else if (type == MyActionsType.rfq) {
      final form =
          (data['form_view'] as Map?)?.cast<String, dynamic>() ?? const {};
      // No RFQ / Department — sheet title already shows RFQ number.
      put('Vendor', form['vendor']);
      put('Project', form['project']);
      put('Amount', form['amount_total']);
      put('Client', form['client']);
    } else if (type == MyActionsType.invoice) {
      final form =
          (data['form_view'] as Map?)?.cast<String, dynamic>() ?? const {};
      put('Vendor', form['vendor']);
      put('Project', form['project']);
      put('Department', form['department']);
      put('Client', form['client']);
      final amount = form['amount_total'];
      if (amount is num) {
        put('Amount', '${amount.toStringAsFixed(2)} AED');
      } else {
        put('Amount', amount);
      }
      put('LPO', form['lpo'] ?? form['lpo_name']);
      put('Invoice No', form['inv_no']);
      put('Date', form['date']);
    } else if (type == MyActionsType.ptsh) {
      final form =
          (data['form_view'] as Map?)?.cast<String, dynamic>() ?? const {};
      put('Employee', form['employee'] ?? form['requester_name']);
      put('Holder', form['holder'] ?? form['holder_name']);
      put('Project', form['project']);
      put('Amount', form['amount'] ?? form['total_amount']);
      put('Date', form['date']);
    }

    return MyActionRecordPreview(
      approvals: approvals,
      headerExtras: extras,
    );
  }
}
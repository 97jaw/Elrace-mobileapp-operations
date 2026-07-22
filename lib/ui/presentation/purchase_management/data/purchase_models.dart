// Data models for the Purchase Management module.
// All models are parsed from Odoo JSON-RPC responses (see doc/category_03_purchase.md).
// No write/edit/create logic here.

// ---------------------------------------------------------------------------
// Overview / KPIs
// ---------------------------------------------------------------------------

class PurchaseOverview {
  const PurchaseOverview({
    required this.isAuthorized,
    required this.availableTabs,
    required this.scope,
    required this.monthLabel,
    required this.totalDisplay,
    required this.pendingCount,
    required this.approvedCount,
    required this.trendLabel,
    required this.deltaPercentage,
    required this.previousTotalDisplay,
    required this.mrCounts,
    required this.poStateCounts,
    required this.invoiceCounts,
    required this.cards,
  });

  final bool isAuthorized;
  final List<String> availableTabs;
  final String scope;
  final String monthLabel;
  final String totalDisplay;
  final int pendingCount;
  final int approvedCount;
  final String trendLabel;
  final double? deltaPercentage;
  final String previousTotalDisplay;
  final Map<String, int> mrCounts;
  final Map<String, int> poStateCounts;
  final Map<String, int> invoiceCounts;
  final PurchaseHubCards cards;

  factory PurchaseOverview.fromJson(Map<String, dynamic> json) {
    return PurchaseOverview(
      isAuthorized: json['is_authorized'] != false,
      availableTabs: _parseStringList(json['available_tabs']),
      scope: json['scope']?.toString() ?? 'none',
      monthLabel: json['month_label']?.toString() ?? '',
      totalDisplay: json['total_display']?.toString() ?? 'AED 0',
      pendingCount: _parseInt(json['pending_count']),
      approvedCount: _parseInt(json['approved_count']),
      trendLabel: json['trend_label']?.toString() ?? '',
      deltaPercentage: _parseDouble(json['delta_percentage']),
      previousTotalDisplay: json['previous_total_display']?.toString() ?? '',
      mrCounts: _parseIntMap(json['mr_counts']),
      poStateCounts: _parseIntMap(json['po_state_counts']),
      invoiceCounts: _parseIntMap(json['invoice_counts']),
      cards: PurchaseHubCards.fromJson(
        json['cards'] is Map ? Map<String, dynamic>.from(json['cards'] as Map) : null,
      ),
    );
  }

  static PurchaseOverview unauthorized() => const PurchaseOverview(
        isAuthorized: false,
        availableTabs: [],
        scope: 'none',
        monthLabel: '',
        totalDisplay: 'AED 0',
        pendingCount: 0,
        approvedCount: 0,
        trendLabel: '',
        deltaPercentage: null,
        previousTotalDisplay: '',
        mrCounts: {},
        poStateCounts: {},
        invoiceCounts: {},
        cards: PurchaseHubCards.empty,
      );
}

class PurchaseHubCards {
  const PurchaseHubCards({
    required this.waitingRfqs,
    required this.totalRfqs,
    required this.pendingMrs,
    required this.lpos,
    required this.lposOpen,
    required this.lposClosed,
    required this.rfqPendingResponse,
    required this.rfqQuotationsReceived,
  });

  final int waitingRfqs;
  final int totalRfqs;
  final int pendingMrs;
  final int lpos;
  final int lposOpen;
  final int lposClosed;
  final int rfqPendingResponse;
  final int rfqQuotationsReceived;

  static const empty = PurchaseHubCards(
    waitingRfqs: 0,
    totalRfqs: 0,
    pendingMrs: 0,
    lpos: 0,
    lposOpen: 0,
    lposClosed: 0,
    rfqPendingResponse: 0,
    rfqQuotationsReceived: 0,
  );

  factory PurchaseHubCards.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PurchaseHubCards.empty;
    return PurchaseHubCards(
      waitingRfqs: _parseInt(json['waiting_rfqs']),
      totalRfqs: _parseInt(json['total_rfqs']),
      pendingMrs: _parseInt(json['pending_mrs']),
      lpos: _parseInt(json['lpos']),
      lposOpen: _parseInt(json['lpos_open']),
      lposClosed: _parseInt(json['lpos_closed']),
      rfqPendingResponse: _parseInt(json['rfq_pending_response']),
      rfqQuotationsReceived: _parseInt(json['rfq_quotations_received']),
    );
  }
}

class DraftInvoiceItem {
  const DraftInvoiceItem({
    required this.id,
    required this.vendor,
    required this.vendorPhoto,
    required this.invoiceId,
    required this.amount,
    required this.formattedAmount,
    required this.createDate,
    required this.timeAgo,
    required this.state,
    this.invoiceDate = '',
    this.dueDate = '',
    this.currency = 'AED',
    this.amountResidual = 0,
    this.formattedResidual = '',
    this.amountPaid = 0,
    this.formattedPaid = '',
    this.paymentState = '',
    this.statusLabel = '',
    this.origin = '',
  });

  final int id;
  final String vendor;
  final String vendorPhoto;
  final String invoiceId;
  final double amount;
  final String formattedAmount;
  final String createDate;
  final String timeAgo;
  /// Odoo `state` (draft/posted/cancel) — kept for compatibility.
  final String state;
  final String invoiceDate;
  final String dueDate;
  final String currency;
  final double amountResidual;
  final String formattedResidual;
  final double amountPaid;
  final String formattedPaid;
  final String paymentState;
  /// Display badge: DRAFT / NOT PAID / PARTIAL / PAID / …
  final String statusLabel;
  final String origin;

  String get displayStatus {
    if (statusLabel.isNotEmpty) return statusLabel;
    if (state.toUpperCase() == 'PENDING' || state.toUpperCase() == 'DRAFT') {
      return 'DRAFT';
    }
    return state.isNotEmpty ? state.toUpperCase() : 'POSTED';
  }

  factory DraftInvoiceItem.fromJson(Map<String, dynamic> json) =>
      DraftInvoiceItem(
        id: _parseInt(json['id']),
        vendor: json['vendor']?.toString() ??
            json['company_name']?.toString() ??
            '',
        vendorPhoto: json['vendor_photo']?.toString() ?? '',
        invoiceId: json['invoice_id']?.toString() ?? '',
        amount: _parseDouble(json['amount']) ?? 0,
        formattedAmount: json['formatted_amount']?.toString() ?? '',
        createDate: json['create_date']?.toString() ?? '',
        timeAgo: json['time_ago']?.toString() ?? '',
        state: json['state']?.toString() ?? 'PENDING',
        invoiceDate: json['invoice_date']?.toString() ?? '',
        dueDate: json['due_date']?.toString() ?? '',
        currency: json['currency']?.toString() ?? 'AED',
        amountResidual: _parseDouble(json['amount_residual']) ?? 0,
        formattedResidual: json['formatted_residual']?.toString() ?? '',
        amountPaid: _parseDouble(json['amount_paid']) ?? 0,
        formattedPaid: json['formatted_paid']?.toString() ?? '',
        paymentState: json['payment_state']?.toString() ?? '',
        statusLabel: json['status_label']?.toString() ?? '',
        origin: json['origin']?.toString() ?? '',
      );
}

class InvoicePaymentItem {
  const InvoicePaymentItem({
    required this.id,
    required this.name,
    required this.date,
    required this.amount,
    required this.formattedAmount,
    required this.currency,
    required this.journal,
    required this.state,
  });

  final int id;
  final String name;
  final String date;
  final double amount;
  final String formattedAmount;
  final String currency;
  final String journal;
  final String state;

  factory InvoicePaymentItem.fromJson(Map<String, dynamic> json) =>
      InvoicePaymentItem(
        id: _parseInt(json['id']),
        name: json['name']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        amount: _parseDouble(json['amount']) ?? 0,
        formattedAmount: json['formatted_amount']?.toString() ?? '',
        currency: json['currency']?.toString() ?? 'AED',
        journal: json['journal']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
      );
}

class PurchaseInvoiceDetail {
  const PurchaseInvoiceDetail({
    required this.id,
    required this.vendor,
    required this.vendorPhoto,
    required this.invoiceId,
    required this.invoiceDate,
    required this.dueDate,
    required this.amount,
    required this.formattedAmount,
    required this.currency,
    required this.amountResidual,
    required this.formattedResidual,
    required this.amountPaid,
    required this.formattedPaid,
    required this.amountUntaxed,
    required this.formattedUntaxed,
    required this.amountTax,
    required this.formattedTax,
    required this.paymentState,
    required this.state,
    required this.statusLabel,
    required this.origin,
    required this.narration,
    required this.ref,
    required this.payments,
  });

  final int id;
  final String vendor;
  final String vendorPhoto;
  final String invoiceId;
  final String invoiceDate;
  final String dueDate;
  final double amount;
  final String formattedAmount;
  final String currency;
  final double amountResidual;
  final String formattedResidual;
  final double amountPaid;
  final String formattedPaid;
  final double amountUntaxed;
  final String formattedUntaxed;
  final double amountTax;
  final String formattedTax;
  final String paymentState;
  final String state;
  final String statusLabel;
  final String origin;
  final String narration;
  final String ref;
  final List<InvoicePaymentItem> payments;

  String get displayStatus {
    if (statusLabel.isNotEmpty) return statusLabel;
    return state.isNotEmpty ? state.toUpperCase() : 'POSTED';
  }

  factory PurchaseInvoiceDetail.fromJson(Map<String, dynamic> json) =>
      PurchaseInvoiceDetail(
        id: _parseInt(json['id']),
        vendor: json['vendor']?.toString() ?? '',
        vendorPhoto: json['vendor_photo']?.toString() ?? '',
        invoiceId: json['invoice_id']?.toString() ?? '',
        invoiceDate: json['invoice_date']?.toString() ?? '',
        dueDate: json['due_date']?.toString() ?? '',
        amount: _parseDouble(json['amount']) ?? 0,
        formattedAmount: json['formatted_amount']?.toString() ?? '',
        currency: json['currency']?.toString() ?? 'AED',
        amountResidual: _parseDouble(json['amount_residual']) ?? 0,
        formattedResidual: json['formatted_residual']?.toString() ?? '',
        amountPaid: _parseDouble(json['amount_paid']) ?? 0,
        formattedPaid: json['formatted_paid']?.toString() ?? '',
        amountUntaxed: _parseDouble(json['amount_untaxed']) ?? 0,
        formattedUntaxed: json['formatted_untaxed']?.toString() ?? '',
        amountTax: _parseDouble(json['amount_tax']) ?? 0,
        formattedTax: json['formatted_tax']?.toString() ?? '',
        paymentState: json['payment_state']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        statusLabel: json['status_label']?.toString() ?? '',
        origin: json['origin']?.toString() ?? '',
        narration: json['narration']?.toString() ?? '',
        ref: json['ref']?.toString() ?? '',
        payments: _parseList(json['payments'], InvoicePaymentItem.fromJson),
      );
}

class DraftInvoicesPreview {
  const DraftInvoicesPreview({
    required this.totalCount,
    required this.items,
  });

  final int totalCount;
  final List<DraftInvoiceItem> items;

  static const empty = DraftInvoicesPreview(totalCount: 0, items: []);

  factory DraftInvoicesPreview.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DraftInvoicesPreview.empty;
    return DraftInvoicesPreview(
      totalCount: _parseInt(json['total_count']),
      items: _parseList(json['items'], DraftInvoiceItem.fromJson),
    );
  }
}

// ---------------------------------------------------------------------------
// Material Requisition (MR)
// ---------------------------------------------------------------------------

class MrItem {
  const MrItem({
    required this.id,
    required this.name,
    required this.requester,
    required this.requesterPhoto,
    required this.department,
    required this.project,
    required this.woPo,
    required this.requestDate,
    required this.deadline,
    required this.state,
    required this.odooState,
    required this.priority,
    required this.myRole,
    required this.proposedVendor,
    required this.projectManager,
    this.projectManagerPhoto = '',
    this.isUrgent = false,
  });

  final int id;
  final String name;
  final String requester;
  final String requesterPhoto;
  final String department;
  final String project;
  final String woPo;
  final String requestDate;
  final String deadline;
  final String state;
  final String odooState;
  final String priority;
  final String myRole;
  final String proposedVendor;
  final String projectManager;
  final String projectManagerPhoto;
  final bool isUrgent;

  factory MrItem.fromJson(Map<String, dynamic> json) => MrItem(
        id: _parseInt(json['id']),
        name: json['name']?.toString() ?? '',
        requester: json['requester']?.toString() ?? '',
        requesterPhoto: json['requester_photo']?.toString() ?? '',
        department: json['department']?.toString() ?? '',
        project: json['project']?.toString() ?? '',
        woPo: json['wo_po']?.toString() ?? '',
        requestDate: json['request_date']?.toString() ?? '',
        deadline: json['deadline']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        odooState: json['odoo_state']?.toString() ?? '',
        priority: json['priority']?.toString() ?? 'normal',
        myRole: json['my_role']?.toString() ?? '',
        proposedVendor: json['proposed_vendor']?.toString() ?? '',
        projectManager: json['project_manager']?.toString() ?? '',
        projectManagerPhoto: json['project_manager_photo']?.toString() ?? '',
        isUrgent: json['is_urgent'] == true,
      );
}

class MrLineItem {
  const MrLineItem({
    required this.id,
    required this.product,
    required this.description,
    required this.qty,
    required this.uom,
    required this.scheduledDate,
  });
  final int id;
  final String product;
  final String description;
  final double qty;
  final String uom;
  final String scheduledDate;

  factory MrLineItem.fromJson(Map<String, dynamic> json) => MrLineItem(
        id: _parseInt(json['id']),
        product: json['product']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        qty: _parseDouble(json['qty']) ?? 0,
        uom: json['uom']?.toString() ?? '',
        scheduledDate: json['scheduled_date']?.toString() ?? '',
      );
}

class MrAttachment {
  const MrAttachment({
    required this.id,
    required this.name,
    required this.url,
    required this.mimetype,
  });
  final int id;
  final String name;
  final String url;
  final String mimetype;

  factory MrAttachment.fromJson(Map<String, dynamic> json) => MrAttachment(
        id: _parseInt(json['id']),
        name: json['name']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        mimetype: json['mimetype']?.toString() ?? '',
      );
}

class MrApprovalStep {
  const MrApprovalStep({
    required this.reviewer,
    required this.status,
    required this.date,
    required this.comment,
  });
  final String reviewer;
  final String status;
  final String date;
  final String comment;

  factory MrApprovalStep.fromJson(Map<String, dynamic> json) => MrApprovalStep(
        reviewer: json['reviewer']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        comment: json['comment']?.toString() ?? '',
      );
}

class MrLinkedRfq {
  const MrLinkedRfq({
    required this.id,
    required this.name,
    required this.state,
  });
  final int id;
  final String name;
  final String state;

  factory MrLinkedRfq.fromJson(Map<String, dynamic> json) => MrLinkedRfq(
        id: _parseInt(json['id']),
        name: json['name']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
      );
}

class MrDetail {
  const MrDetail({
    required this.id,
    required this.name,
    required this.state,
    required this.odooState,
    required this.requesterName,
    required this.requesterPhoto,
    required this.department,
    required this.woPo,
    required this.reqOu,
    required this.operatingUnit,
    required this.reqResp,
    required this.mrType,
    required this.requestDate,
    required this.receivedDate,
    required this.deadline,
    required this.analyticAccount,
    required this.projectManager,
    this.projectManagerPhoto = '',
    required this.priority,
    required this.proposedVendor,
    required this.quotationRef,
    required this.taskJobOrderUser,
    required this.deliveryAddress,
    required this.lineCommonVendor,
    required this.requesterManager,
    required this.lines,
    required this.attachments,
    required this.linkedRfqs,
    required this.approvalTrail,
  });

  final int id;
  final String name;
  final String state;
  final String odooState;
  final String requesterName;
  final String requesterPhoto;
  final String department;
  final String woPo;
  final String reqOu;
  final String operatingUnit;
  final String reqResp;
  final String mrType;
  final String requestDate;
  final String receivedDate;
  final String deadline;
  final String analyticAccount;
  final String projectManager;
  final String projectManagerPhoto;
  final String priority;
  final String proposedVendor;
  final String quotationRef;
  final String taskJobOrderUser;
  final String deliveryAddress;
  final String lineCommonVendor;
  final String requesterManager;
  final List<MrLineItem> lines;
  final List<MrAttachment> attachments;
  final List<MrLinkedRfq> linkedRfqs;
  final List<MrApprovalStep> approvalTrail;

  factory MrDetail.fromJson(Map<String, dynamic> json) => MrDetail(
        id: _parseInt(json['id']),
        name: json['name']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        odooState: json['odoo_state']?.toString() ?? '',
        requesterName: json['requester_name']?.toString() ?? '',
        requesterPhoto: json['requester_photo']?.toString() ?? '',
        department: json['department']?.toString() ?? '',
        woPo: json['wo_po']?.toString() ?? json['project']?.toString() ?? '',
        reqOu: json['req_ou']?.toString() ?? '',
        operatingUnit: json['operating_unit']?.toString() ?? '',
        reqResp: json['req_resp']?.toString() ?? '',
        mrType: json['mr_type']?.toString() ?? '',
        requestDate: json['request_date']?.toString() ?? '',
        receivedDate: json['received_date']?.toString() ?? '',
        deadline: json['deadline']?.toString() ?? '',
        analyticAccount: json['analytic_account']?.toString() ?? '',
        projectManager: json['project_manager']?.toString() ?? '',
        projectManagerPhoto: json['project_manager_photo']?.toString() ?? '',
        priority: json['priority']?.toString() ?? 'normal',
        proposedVendor: json['proposed_vendor']?.toString() ?? '',
        quotationRef: json['quotation_ref']?.toString() ?? '',
        taskJobOrderUser: json['task_job_order_user']?.toString() ?? '',
        deliveryAddress: json['delivery_address']?.toString() ?? '',
        lineCommonVendor: json['line_common_vendor']?.toString() ?? '',
        requesterManager: json['requester_manager']?.toString() ?? '',
        lines: _parseList(json['lines'], MrLineItem.fromJson),
        attachments: _parseList(json['attachments'], MrAttachment.fromJson),
        linkedRfqs: _parseList(json['linked_rfqs'], MrLinkedRfq.fromJson),
        approvalTrail: _parseList(json['approval_trail'], MrApprovalStep.fromJson),
      );
}

// ---------------------------------------------------------------------------
// Purchase list filters & filter options
// ---------------------------------------------------------------------------

class PurchaseFilterOption {
  const PurchaseFilterOption({
    required this.id,
    required this.label,
    this.subtitle,
    this.color,
  });

  final int id;
  final String label;
  final String? subtitle;
  final int? color;

  factory PurchaseFilterOption.fromJson(Map<String, dynamic> json) {
    return PurchaseFilterOption(
      id: _parseInt(json['id']),
      label: json['label']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      color: json.containsKey('color') ? _parseInt(json['color']) : null,
    );
  }
}

class PurchaseFilterOptions {
  const PurchaseFilterOptions({
    this.vendors = const [],
    this.materialTypes = const [],
    this.cities = const [],
    this.projectManagers = const [],
    this.years = const [],
  });

  static const empty = PurchaseFilterOptions();

  final List<PurchaseFilterOption> vendors;
  final List<PurchaseFilterOption> materialTypes;
  final List<PurchaseFilterOption> cities;
  final List<PurchaseFilterOption> projectManagers;
  final List<PurchaseFilterOption> years;

  factory PurchaseFilterOptions.fromJson(Map<String, dynamic> json) {
    List<PurchaseFilterOption> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => PurchaseFilterOption.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList();
    }

    return PurchaseFilterOptions(
      vendors: parseList(json['vendors']),
      materialTypes: parseList(json['material_types']),
      cities: parseList(json['cities']),
      projectManagers: parseList(json['project_managers']),
      years: parseList(json['years']),
    );
  }
}

class PurchaseListFilters {
  const PurchaseListFilters({
    this.dateFrom = '',
    this.dateTo = '',
    this.origin = '',
    this.reference = '',
    this.vendorIds = const [],
    this.materialTypeIds = const [],
    this.cityIds = const [],
    this.projectManagerIds = const [],
    this.years = const [],
  });

  final String dateFrom;
  final String dateTo;
  final String origin;
  final String reference;
  final List<int> vendorIds;
  final List<int> materialTypeIds;
  final List<int> cityIds;
  final List<int> projectManagerIds;
  final List<int> years;

  bool get isEmpty =>
      dateFrom.isEmpty &&
      dateTo.isEmpty &&
      origin.isEmpty &&
      reference.isEmpty &&
      vendorIds.isEmpty &&
      materialTypeIds.isEmpty &&
      cityIds.isEmpty &&
      projectManagerIds.isEmpty &&
      years.isEmpty;

  int get activeCount =>
      [
        if (dateFrom.isNotEmpty) dateFrom,
        if (dateTo.isNotEmpty) dateTo,
        if (origin.isNotEmpty) origin,
        if (reference.isNotEmpty) reference,
      ].length +
      (vendorIds.isNotEmpty ? 1 : 0) +
      (materialTypeIds.isNotEmpty ? 1 : 0) +
      (cityIds.isNotEmpty ? 1 : 0) +
      (projectManagerIds.isNotEmpty ? 1 : 0) +
      (years.isNotEmpty ? 1 : 0);

  PurchaseListFilters copyWith({
    String? dateFrom,
    String? dateTo,
    String? origin,
    String? reference,
    List<int>? vendorIds,
    List<int>? materialTypeIds,
    List<int>? cityIds,
    List<int>? projectManagerIds,
    List<int>? years,
  }) {
    return PurchaseListFilters(
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      origin: origin ?? this.origin,
      reference: reference ?? this.reference,
      vendorIds: vendorIds ?? this.vendorIds,
      materialTypeIds: materialTypeIds ?? this.materialTypeIds,
      cityIds: cityIds ?? this.cityIds,
      projectManagerIds: projectManagerIds ?? this.projectManagerIds,
      years: years ?? this.years,
    );
  }

  Map<String, String> toApiParams() {
    final map = <String, String>{};
    void put(String key, String value) {
      final v = value.trim();
      if (v.isNotEmpty) map[key] = v;
    }

    void putIds(String key, List<int> ids) {
      if (ids.isNotEmpty) map[key] = ids.join(',');
    }

    put('date_from', dateFrom);
    put('date_to', dateTo);
    put('origin', origin);
    put('reference', reference);
    putIds('vendor_ids', vendorIds);
    putIds('material_type_ids', materialTypeIds);
    putIds('city_ids', cityIds);
    putIds('project_manager_ids', projectManagerIds);
    putIds('years', years);
    return map;
  }
}

typedef LpoListFilters = PurchaseListFilters;

// ---------------------------------------------------------------------------
// RFQ / PO
// ---------------------------------------------------------------------------

class RfqItem {
  const RfqItem({
    required this.id,
    required this.name,
    required this.vendorName,
    required this.clientPhoto,
    required this.project,
    required this.requestedBy,
    required this.requestedByPhoto,
    required this.requesterManager,
    required this.dateOrder,
    required this.amountTotal,
    required this.amountDisplay,
    required this.state,
    required this.odooState,
    required this.currency,
    required this.department,
    required this.attachments,
  });

  final int id;
  final String name;
  final String vendorName;
  final String clientPhoto;
  final String project;
  final String requestedBy;
  final String requestedByPhoto;
  final String requesterManager;
  final String dateOrder;
  final double amountTotal;
  final String amountDisplay;
  final String state;
  final String odooState;
  final String currency;
  final String department;
  final List<Map<String, dynamic>> attachments;

  factory RfqItem.fromJson(Map<String, dynamic> json) => RfqItem(
        id: _parseInt(json['id']),
        name: json['name']?.toString() ?? '',
        vendorName: json['partner_id']?.toString() ?? '',
        clientPhoto: json['client_photo']?.toString() ?? '',
        project: json['project']?.toString() ?? '',
        requestedBy: json['requested_by']?.toString() ?? '',
        requestedByPhoto: json['requested_by_user_photo']?.toString() ?? '',
        requesterManager: json['requester_manager']?.toString() ?? '',
        dateOrder: json['date_order']?.toString() ?? '',
        amountTotal: _parseDouble(json['amount_total']) ?? 0,
        amountDisplay: json['amount_display']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        odooState: json['odoo_state']?.toString() ?? '',
        currency: json['currency']?.toString() ?? 'AED',
        department: json['department']?.toString() ?? '',
        attachments: _parseRawList(json['attachments']),
      );
}

// ---------------------------------------------------------------------------
// Invoice Receiving
// ---------------------------------------------------------------------------

class InvoiceReceivingItem {
  const InvoiceReceivingItem({
    required this.id,
    required this.name,
    required this.invoiceNo,
    required this.lpoNo,
    required this.invoiceDate,
    required this.invoicingDate,
    required this.amount,
    required this.amountDisplay,
    required this.state,
    required this.currency,
    required this.partner,
  });

  final int id;
  /// Odoo sequence name (e.g. RCC/SCP/2026/1240).
  final String name;
  final String invoiceNo;
  final String lpoNo;
  final String invoiceDate;
  final String invoicingDate;
  final double amount;
  final String amountDisplay;
  final String state;
  final String currency;
  final String partner;

  bool get isDraft => state.toUpperCase() == 'DRAFT';

  factory InvoiceReceivingItem.fromJson(Map<String, dynamic> json) =>
      InvoiceReceivingItem(
        id: _parseInt(json['id']),
        name: json['name']?.toString() ?? '',
        invoiceNo: json['invoice_no']?.toString() ?? '',
        lpoNo: json['lpo_no']?.toString() ?? '',
        invoiceDate: json['invoice_date']?.toString() ?? '',
        invoicingDate: json['invoicing_date']?.toString() ?? '',
        amount: _parseDouble(json['amount']) ?? 0,
        amountDisplay: json['amount_display']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        currency: json['currency']?.toString() ?? 'AED',
        partner: json['partner']?.toString() ?? '',
      );
}

class InvoiceLineItem {
  const InvoiceLineItem({
    required this.id,
    required this.product,
    required this.description,
    required this.qty,
    required this.priceUnit,
    required this.subtotal,
    required this.tax,
  });
  final int id;
  final String product;
  final String description;
  final double qty;
  final double priceUnit;
  final double subtotal;
  final double tax;

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) =>
      InvoiceLineItem(
        id: _parseInt(json['id']),
        product: json['product']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        qty: _parseDouble(json['qty']) ?? 0,
        priceUnit: _parseDouble(json['price_unit']) ?? 0,
        subtotal: _parseDouble(json['subtotal']) ?? 0,
        tax: _parseDouble(json['tax']) ?? 0,
      );
}

class InvoiceAttachment {
  const InvoiceAttachment({
    required this.id,
    required this.name,
    required this.url,
    required this.mimetype,
    this.fileContentBase64,
  });
  final int id;
  final String name;
  final String url;
  final String mimetype;
  final String? fileContentBase64;

  factory InvoiceAttachment.fromJson(Map<String, dynamic> json) =>
      InvoiceAttachment(
        id: _parseInt(json['id']),
        name: json['name']?.toString() ?? '',
        url: json['url']?.toString() ?? '',
        mimetype: json['mimetype']?.toString() ?? '',
        fileContentBase64: json['file_content_base64']?.toString(),
      );
}

class LpoOption {
  const LpoOption({
    required this.id,
    required this.name,
    required this.partner,
    required this.amount,
    required this.amountDisplay,
    required this.dateOrder,
  });

  final int id;
  final String name;
  final String partner;
  final double amount;
  final String amountDisplay;
  final String dateOrder;

  factory LpoOption.fromJson(Map<String, dynamic> json) => LpoOption(
        id: _parseInt(json['id']),
        name: json['name']?.toString() ?? '',
        partner: json['partner']?.toString() ?? '',
        amount: _parseDouble(json['amount']) ?? 0,
        amountDisplay: json['amount_display']?.toString() ?? '',
        dateOrder: json['date_order']?.toString() ?? '',
      );
}

class InvoiceReceivingDetail {
  const InvoiceReceivingDetail({
    required this.id,
    required this.invoiceNo,
    required this.lpoNo,
    this.lpoId,
    required this.invoiceDate,
    required this.dueDate,
    required this.partner,
    required this.partnerPhoto,
    required this.amountUntaxed,
    required this.amountTax,
    required this.amountTotal,
    required this.amountDisplay,
    required this.currency,
    required this.state,
    required this.paymentState,
    required this.narration,
    required this.lines,
    required this.attachments,
    this.canReceive = false,
  });

  final int id;
  final String invoiceNo;
  final String lpoNo;
  final int? lpoId;
  final String invoiceDate;
  final String dueDate;
  final String partner;
  final String partnerPhoto;
  final double amountUntaxed;
  final double amountTax;
  final double amountTotal;
  final String amountDisplay;
  final String currency;
  final String state;
  final String paymentState;
  final String narration;
  final List<InvoiceLineItem> lines;
  final List<InvoiceAttachment> attachments;
  final bool canReceive;

  factory InvoiceReceivingDetail.fromJson(Map<String, dynamic> json) =>
      InvoiceReceivingDetail(
        id: _parseInt(json['id']),
        invoiceNo: json['invoice_no']?.toString() ?? '',
        lpoNo: json['lpo_no']?.toString() ?? '',
        lpoId: json['lpo_id'] is int ? json['lpo_id'] : null,
        invoiceDate: json['invoice_date']?.toString() ?? '',
        dueDate: json['due_date']?.toString() ?? '',
        partner: json['partner']?.toString() ?? '',
        partnerPhoto: json['partner_photo']?.toString() ?? '',
        amountUntaxed: _parseDouble(json['amount_untaxed']) ?? 0,
        amountTax: _parseDouble(json['amount_tax']) ?? 0,
        amountTotal: _parseDouble(json['amount_total']) ?? 0,
        amountDisplay: json['amount_display']?.toString() ?? '',
        currency: json['currency']?.toString() ?? 'AED',
        state: json['state']?.toString() ?? '',
        paymentState: json['payment_state']?.toString() ?? '',
        narration: json['narration']?.toString() ?? '',
        lines: _parseList(json['lines'], InvoiceLineItem.fromJson),
        attachments: _parseList(json['attachments'], InvoiceAttachment.fromJson),
        canReceive: json['can_receive'] == true,
      );
}

// ---------------------------------------------------------------------------
// Parsing helpers
// ---------------------------------------------------------------------------

int _parseInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

double? _parseDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString());
}

List<String> _parseStringList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  return [];
}

Map<String, int> _parseIntMap(dynamic v) {
  if (v is! Map) return {};
  return v.map((k, val) => MapEntry(k.toString(), _parseInt(val)));
}

List<T> _parseList<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((e) => fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

List<Map<String, dynamic>> _parseRawList(dynamic v) {
  if (v is! List) return [];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

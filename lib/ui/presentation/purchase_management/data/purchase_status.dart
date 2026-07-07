import 'package:flutter/material.dart';

/// Central state-to-display mapping for all four purchase domains.
/// Single source of truth — never scattered across individual screens.
enum MrStatus {
  newDraft,
  waitingDeptApproval,
  waitingIrApproval,
  approved,
  rfqCreated,
  received,
  rejected,
  resetToDraft,
  unknown,
}

enum RfqStatus {
  rfq,
  rfqSent,
  waitingApproval,
  purchaseOrder,
  received,
  cancelled,
  unknown,
}

enum InvoiceReceivingStatus {
  draft,
  confirmed,
  cancelled,
  unknown,
}

// ---------------------------------------------------------------------------
// MR
// ---------------------------------------------------------------------------

extension MrStatusX on MrStatus {
  String get label => switch (this) {
        MrStatus.newDraft => 'NEW',
        MrStatus.waitingDeptApproval => 'WAITING DEPT APPROVAL',
        MrStatus.waitingIrApproval => 'WAITING IR APPROVAL',
        MrStatus.approved => 'APPROVED',
        MrStatus.rfqCreated => 'RFQ CREATED',
        MrStatus.received => 'RECEIVED',
        MrStatus.rejected => 'REJECTED',
        MrStatus.resetToDraft => 'RESET TO DRAFT',
        MrStatus.unknown => 'UNKNOWN',
      };

  /// Zero-based stepper index (excludes terminal/off-path states).
  int get stepIndex => switch (this) {
        MrStatus.newDraft => 0,
        MrStatus.waitingDeptApproval => 1,
        MrStatus.waitingIrApproval => 2,
        MrStatus.approved => 3,
        MrStatus.rfqCreated => 4,
        MrStatus.received => 5,
        _ => -1,
      };

  Color get color => switch (this) {
        MrStatus.newDraft => const Color(0xFF8A9BB5),
        MrStatus.waitingDeptApproval => const Color(0xFFF59E0D),
        MrStatus.waitingIrApproval => const Color(0xFFF59E0D),
        MrStatus.approved => const Color(0xFF4ADE80),
        MrStatus.rfqCreated => const Color(0xFF3E7BFA),
        MrStatus.received => const Color(0xFF4ADE80),
        MrStatus.rejected => const Color(0xFFEF4444),
        MrStatus.resetToDraft => const Color(0xFF8A9BB5),
        MrStatus.unknown => const Color(0xFF8A9BB5),
      };

  bool get isTerminal =>
      this == MrStatus.received ||
      this == MrStatus.rejected ||
      this == MrStatus.unknown;
}

MrStatus mrStatusFromApi(String raw) {
  switch (raw.toUpperCase().trim()) {
    case 'NEW':
    case 'DRAFT':
      return MrStatus.newDraft;
    case 'WAITING DEPARTMENT APPROVAL':
    case 'WAITING DEPT APPROVAL':
    case 'IN_PROGRESS':
    case 'IN PROGRESS':
      return MrStatus.waitingDeptApproval;
    case 'WAITING IR APPROVAL':
    case 'WAITING_IR':
      return MrStatus.waitingIrApproval;
    case 'APPROVED':
      return MrStatus.approved;
    case 'RFQ CREATED':
    case 'RFQ_CREATED':
      return MrStatus.rfqCreated;
    case 'RECEIVED':
    case 'DONE':
      return MrStatus.received;
    case 'REJECT':
    case 'REJECTED':
    case 'REFUSED':
    case 'CANCEL':
    case 'CANCELLED':
      return MrStatus.rejected;
    case 'RESET TO DRAFT':
      return MrStatus.resetToDraft;
    default:
      return MrStatus.unknown;
  }
}

/// The six ordered stepper steps for MR workflow.
const List<String> mrStepLabels = [
  'New',
  'Dept Approval',
  'IR Approval',
  'Approved',
  'RFQ Created',
  'Received',
];

// ---------------------------------------------------------------------------
// RFQ / PO
// ---------------------------------------------------------------------------

extension RfqStatusX on RfqStatus {
  String get label => switch (this) {
        RfqStatus.rfq => 'RFQ',
        RfqStatus.rfqSent => 'RFQ SENT',
        RfqStatus.waitingApproval => 'WAITING APPROVAL',
        RfqStatus.purchaseOrder => 'PURCHASE ORDER',
        RfqStatus.received => 'RECEIVED',
        RfqStatus.cancelled => 'CANCELLED',
        RfqStatus.unknown => 'UNKNOWN',
      };

  Color get color => switch (this) {
        RfqStatus.rfq => const Color(0xFF8A9BB5),
        RfqStatus.rfqSent => const Color(0xFFF59E0D),
        RfqStatus.waitingApproval => const Color(0xFFF59E0D),
        RfqStatus.purchaseOrder => const Color(0xFF4ADE80),
        RfqStatus.received => const Color(0xFF4ADE80),
        RfqStatus.cancelled => const Color(0xFFEF4444),
        RfqStatus.unknown => const Color(0xFF8A9BB5),
      };

  bool get isActive => this != RfqStatus.cancelled && this != RfqStatus.unknown;
}

RfqStatus rfqStatusFromApi(String raw) {
  switch (raw.toUpperCase().trim()) {
    case 'RFQ':
    case 'DRAFT':
      return RfqStatus.rfq;
    case 'RFQ SENT':
    case 'SENT':
      return RfqStatus.rfqSent;
    case 'WAITING APPROVAL':
    case 'TO APPROVE':
      return RfqStatus.waitingApproval;
    case 'PURCHASE ORDER':
    case 'PURCHASE':
      return RfqStatus.purchaseOrder;
    case 'RECEIVED':
    case 'DONE':
      return RfqStatus.received;
    case 'CANCELLED':
    case 'CANCEL':
      return RfqStatus.cancelled;
    default:
      return RfqStatus.unknown;
  }
}

// ---------------------------------------------------------------------------
// Invoice Receiving
// ---------------------------------------------------------------------------

extension InvoiceReceivingStatusX on InvoiceReceivingStatus {
  String get label => switch (this) {
        InvoiceReceivingStatus.draft => 'DRAFT',
        InvoiceReceivingStatus.confirmed => 'CONFIRMED',
        InvoiceReceivingStatus.cancelled => 'CANCELLED',
        InvoiceReceivingStatus.unknown => 'UNKNOWN',
      };

  Color get color => switch (this) {
        InvoiceReceivingStatus.draft => const Color(0xFFF59E0D),
        InvoiceReceivingStatus.confirmed => const Color(0xFF4ADE80),
        InvoiceReceivingStatus.cancelled => const Color(0xFFEF4444),
        InvoiceReceivingStatus.unknown => const Color(0xFF8A9BB5),
      };
}

InvoiceReceivingStatus invoiceStatusFromApi(String raw) {
  switch (raw.toUpperCase().trim()) {
    case 'DRAFT':
      return InvoiceReceivingStatus.draft;
    case 'CONFIRMED':
    case 'POSTED':
      return InvoiceReceivingStatus.confirmed;
    case 'CANCELLED':
    case 'CANCEL':
      return InvoiceReceivingStatus.cancelled;
    default:
      return InvoiceReceivingStatus.unknown;
  }
}

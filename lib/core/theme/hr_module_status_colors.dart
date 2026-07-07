import 'package:flutter/material.dart';

import 'hr_badge_kind.dart';
import 'hr_module_colors.dart';

/// Maps API `ui_status` to badge colors — SRD §6.4.
/// Mobile must use normalized `ui_status` only, not raw Odoo states.
abstract final class HrModuleStatusColors {
  static const Set<String> knownStatuses = {
    'DRAFT',
    'PENDING',
    'APPROVED',
    'REJECTED',
  };

  static String _norm(String uiStatus) =>
      uiStatus.toUpperCase().replaceAll(' ', '_');

  static Color backgroundFor(String uiStatus) {
    switch (uiStatus.toUpperCase()) {
      case 'DRAFT':
        return const Color(0xFFE5E7EB);
      case 'PENDING':
        return const Color(0xFFFFF4D6);
      case 'APPROVED':
        return const Color(0xFFD6F0E2);
      case 'REJECTED':
        return const Color(0xFFF5D6DA);
      default:
        return HrModuleColors.border;
    }
  }

  static Color textColorFor(String uiStatus) {
    switch (uiStatus.toUpperCase()) {
      case 'DRAFT':
        return const Color(0xFF374151);
      case 'PENDING':
        return HrModuleColors.warning;
      case 'APPROVED':
        return HrModuleColors.success;
      case 'REJECTED':
        return HrModuleColors.danger;
      default:
        return HrModuleColors.mutedText;
    }
  }

  /// Solid pill on white list cards.
  static Color solidBackgroundFor(String uiStatus) {
    switch (uiStatus.toUpperCase()) {
      case 'DRAFT':
        return const Color(0xFF6B7280);
      case 'PENDING':
        return const Color(0xFFE89B4C);
      case 'APPROVED':
        return const Color(0xFF3D9B6E);
      case 'REJECTED':
        return const Color(0xFFC45C6A);
      default:
        return HrModuleColors.primary;
    }
  }

  static Color solidBackgroundForKind(String uiStatus, HrBadgeKind kind) {
    if (kind == HrBadgeKind.request) {
      return solidBackgroundFor(uiStatus);
    }
    return backgroundForKind(uiStatus, kind);
  }

  /// Module 2+ — normalized keys use underscores (e.g. `IN_RECRUITMENT`).
  static Color backgroundForKind(String uiStatus, HrBadgeKind kind) {
    switch (kind) {
      case HrBadgeKind.request:
        return backgroundFor(uiStatus);
      case HrBadgeKind.requisition:
        return _requisitionBackground(_norm(uiStatus));
      case HrBadgeKind.candidate:
        return _candidateBackground(_norm(uiStatus));
      case HrBadgeKind.offer:
        return _offerBackground(_norm(uiStatus));
      case HrBadgeKind.performanceEvaluation:
        return _performanceEvaluationBackground(_norm(uiStatus));
    }
  }

  static Color textColorForKind(String uiStatus, HrBadgeKind kind) {
    switch (kind) {
      case HrBadgeKind.request:
        return textColorFor(uiStatus);
      case HrBadgeKind.requisition:
        return _requisitionText(_norm(uiStatus));
      case HrBadgeKind.candidate:
        return _candidateText(_norm(uiStatus));
      case HrBadgeKind.offer:
        return _offerText(_norm(uiStatus));
      case HrBadgeKind.performanceEvaluation:
        return _performanceEvaluationText(_norm(uiStatus));
    }
  }

  static Color _performanceEvaluationBackground(String n) {
    switch (n) {
      case 'DRAFT':
        return const Color(0xFFE5E7EB);
      case 'IN_PROGRESS':
        return const Color(0xFFD6E4F5);
      case 'HR_EVALUATION':
        return const Color(0xFFFFF4D6);
      case 'COMPLETED':
        return const Color(0xFFD6F0E2);
      case 'REJECTED':
        return const Color(0xFFF5D6DA);
      default:
        return HrModuleColors.border;
    }
  }

  static Color _performanceEvaluationText(String n) {
    switch (n) {
      case 'DRAFT':
        return const Color(0xFF374151);
      case 'IN_PROGRESS':
        return const Color(0xFF1F3A5F);
      case 'HR_EVALUATION':
        return HrModuleColors.warning;
      case 'COMPLETED':
        return HrModuleColors.success;
      case 'REJECTED':
        return HrModuleColors.danger;
      default:
        return HrModuleColors.mutedText;
    }
  }

  static Color _requisitionBackground(String n) {
    switch (n) {
      case 'DRAFT':
        return const Color(0xFFE5E7EB);
      case 'REQUESTER_APPROVAL':
      case 'HR_OFFICER_APPROVAL':
      case 'HR_MANAGER_APPROVAL':
        return const Color(0xFFFFF4D6);
      case 'OPEN':
      case 'IN_RECRUITMENT':
        return const Color(0xFFD6E4F5);
      case 'HOLD':
        return const Color(0xFFFFF4D6);
      case 'CLOSED':
      case 'FILLED':
        return const Color(0xFFD6F0E2);
      case 'CANCELLED':
        return const Color(0xFFF5D6DA);
      default:
        return HrModuleColors.border;
    }
  }

  static Color _requisitionText(String n) {
    switch (n) {
      case 'DRAFT':
        return const Color(0xFF374151);
      case 'REQUESTER_APPROVAL':
      case 'HR_OFFICER_APPROVAL':
      case 'HR_MANAGER_APPROVAL':
        return HrModuleColors.warning;
      case 'OPEN':
      case 'IN_RECRUITMENT':
        return const Color(0xFF1F3A5F);
      case 'HOLD':
        return HrModuleColors.warning;
      case 'CLOSED':
      case 'FILLED':
        return HrModuleColors.success;
      case 'CANCELLED':
        return HrModuleColors.danger;
      default:
        return HrModuleColors.mutedText;
    }
  }

  static Color _candidateBackground(String n) {
    switch (n) {
      case 'APPLIED':
        return const Color(0xFFE5E7EB);
      case 'SCREENING':
      case 'INTERVIEW':
        return const Color(0xFFD6E4F5);
      case 'OFFER':
        return const Color(0xFFFFF4D6);
      case 'HIRED':
        return const Color(0xFFD6F0E2);
      case 'REJECTED':
        return const Color(0xFFF5D6DA);
      case 'WITHDRAWN':
        return const Color(0xFFE5E7EB);
      default:
        return HrModuleColors.border;
    }
  }

  static Color _candidateText(String n) {
    switch (n) {
      case 'APPLIED':
        return const Color(0xFF374151);
      case 'SCREENING':
        return const Color(0xFF1F3A5F);
      case 'INTERVIEW':
        return const Color(0xFF4A6B8A);
      case 'OFFER':
        return HrModuleColors.warning;
      case 'HIRED':
        return HrModuleColors.success;
      case 'REJECTED':
        return HrModuleColors.danger;
      case 'WITHDRAWN':
        return const Color(0xFF6B7280);
      default:
        return HrModuleColors.mutedText;
    }
  }

  static Color _offerBackground(String n) {
    switch (n) {
      case 'DRAFT':
        return const Color(0xFFE5E7EB);
      case 'SENT':
        return const Color(0xFFFFF4D6);
      case 'ACCEPTED':
        return const Color(0xFFD6F0E2);
      case 'DECLINED':
        return const Color(0xFFF5D6DA);
      case 'EXPIRED':
        return const Color(0xFFE5E7EB);
      default:
        return HrModuleColors.border;
    }
  }

  static Color _offerText(String n) {
    switch (n) {
      case 'DRAFT':
        return const Color(0xFF374151);
      case 'SENT':
        return HrModuleColors.warning;
      case 'ACCEPTED':
        return HrModuleColors.success;
      case 'DECLINED':
        return HrModuleColors.danger;
      case 'EXPIRED':
        return const Color(0xFF6B7280);
      default:
        return HrModuleColors.mutedText;
    }
  }
}

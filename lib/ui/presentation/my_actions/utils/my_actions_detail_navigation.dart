import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/theme/my_actions_module_theme.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_record_preview_sheet.dart';
import 'package:flutter/material.dart';

abstract final class MyActionsDetailNavigation {
  /// Opens the draggable record preview (header + approvals/review table).
  static void showPreview(
    BuildContext context,
    MyActionsModule module,
    MyActionItem item,
  ) {
    final type = MyActionsModuleTheme.apiTypeFor(module);
    if (type == null) return;
    if (module == MyActionsModule.signature ||
        module == MyActionsModule.myRequests) {
      return;
    }

    MyActionsRecordPreviewSheet.show(
      context,
      module: module,
      item: item,
      actionsType: type,
    );
  }

  static String? rfqSubtitle(MyActionItem item) {
    final parts = <String>[];
    if (item.project?.trim().isNotEmpty == true) parts.add(item.project!.trim());
    if (item.vendor?.trim().isNotEmpty == true) parts.add(item.vendor!.trim());
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String? invoiceSubtitle(MyActionItem item) {
    if (item.project?.trim().isNotEmpty == true) return item.project!.trim();
    return item.employeeName.trim().isNotEmpty ? item.employeeName.trim() : null;
  }

  static String? pettyCashSubtitle(MyActionItem item) {
    if (item.amountTotal != null) {
      return '${item.amountTotal!.toStringAsFixed(0)} AED';
    }
    return item.project?.trim().isNotEmpty == true ? item.project!.trim() : null;
  }
}

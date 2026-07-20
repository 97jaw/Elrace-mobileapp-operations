import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Layout helpers for the floating DMS bottom bar (`extendBody: true`).
abstract final class ProjectDocumentsLayout {
  static const barHeight = 58.0;

  /// Total vertical space occupied by the floating bottom bar (incl. safe area).
  static double bottomBarReserve(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final floatGap = bottomInset > 0 ? 8.th : 12.th;
    return barHeight.th + floatGap + bottomInset;
  }

  /// List bottom padding so the last row clears the floating bar.
  static EdgeInsets listPadding(BuildContext context, {double extra = 12}) {
    return EdgeInsets.fromLTRB(
      16.tw,
      0,
      16.tw,
      bottomBarReserve(context) + extra.th,
    );
  }
}

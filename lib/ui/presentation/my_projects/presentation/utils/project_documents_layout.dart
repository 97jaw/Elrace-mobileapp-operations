import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Layout helpers for Project Documents lists (header glass nav; no bottom bar).
abstract final class ProjectDocumentsLayout {
  /// Safe-area-aware bottom inset for list content.
  static double bottomContentInset(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom;
  }

  /// List padding so the last row clears the home indicator.
  static EdgeInsets listPadding(BuildContext context, {double extra = 12}) {
    return EdgeInsets.fromLTRB(
      16.tw,
      0,
      16.tw,
      bottomContentInset(context) + extra.th,
    );
  }
}

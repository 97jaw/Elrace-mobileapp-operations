import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const kAttendancePrimary = Color(0xFF1E4DB7);

/// Company logo (left) + glass bar (right) for attendance sub-screens.
class AttendanceGlassChromeHeader extends StatelessWidget {
  const AttendanceGlassChromeHeader({
    super.key,
    this.title,
    this.showBack = true,
    this.trailing = const [],
  });

  final String? title;
  final bool showBack;
  final List<Widget> trailing;

  static Widget refreshButton({required VoidCallback onPressed}) {
    return IconButton(
      tooltip: 'Refresh',
      onPressed: onPressed,
      icon: Icon(Icons.refresh_rounded, size: 22.sp, color: kAttendancePrimary),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.w),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContextualGlassChromeHeader(
      title: title,
      showBack: showBack,
      onLightSurface: true,
      transparentGlassBar: true,
      scrimTopOpacity: 0,
      logoOpacity: 1.0,
      trailing: trailing,
    );
  }
}

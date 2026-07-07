import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Section wrapper for toolbar and agreements header (no borders).
class ProjectsSectionFrame extends StatelessWidget {
  const ProjectsSectionFrame({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.symmetric(vertical: 10.h),
      child: child,
    );
  }
}

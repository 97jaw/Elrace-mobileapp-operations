import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Scales phone-designed category cards down to fit narrow tablet columns.
///
/// ScreenUtil inflates `.w`/`.h` on tablets. This wrapper gives the child the
/// inflated layout space a phone-width card expects, then [FittedBox] scales
/// that down to the actual column width.
class TabletCardWrapper extends StatelessWidget {
  const TabletCardWrapper({
    super.key,
    required this.child,
    this.height = 118,
    this.designWidth = 175,
    this.designHeight = 140,
  });

  final Widget child;
  final double height;

  /// Design-unit width (pre-ScreenUtil), e.g. half-phone card ≈ 175.
  final double designWidth;

  /// Design-unit height (pre-ScreenUtil).
  final double designHeight;

  @override
  Widget build(BuildContext context) {
    final scaleW = ScreenUtil().scaleWidth;
    final scaleH = ScreenUtil().scaleHeight;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        return SizedBox(
          height: height,
          width: maxW,
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: designWidth * scaleW,
                height: designHeight * scaleH,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

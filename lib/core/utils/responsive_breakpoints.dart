import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Canonical breakpoints for responsive layout decisions.
///
/// Keep phone behavior unchanged by only branching to tablet/desktop layouts
/// when width reaches tablet thresholds.
abstract final class ResponsiveBreakpoints {
  static const double phoneMaxWidth = 599;
  static const double tabletMinWidth = 600;
  static const double tabletLargeMinWidth = 900;
  static const double desktopMinWidth = 1200;
  static const double contentMaxWidthTablet = 1000;
  static const double contentMaxWidthDesktop = 1240;

  static bool isPhoneWidth(double width) => width <= phoneMaxWidth;
  static bool isTabletWidth(double width) =>
      width >= tabletMinWidth && width < desktopMinWidth;
  static bool isLargeTabletWidth(double width) => width >= tabletLargeMinWidth;
  static bool isDesktopWidth(double width) => width >= desktopMinWidth;

  static bool isTablet(BuildContext context) =>
      isTabletWidth(MediaQuery.sizeOf(context).width);

  static bool isLargeTablet(BuildContext context) =>
      isLargeTabletWidth(MediaQuery.sizeOf(context).width);

  static bool isDesktop(BuildContext context) =>
      isDesktopWidth(MediaQuery.sizeOf(context).width);

  /// Phone keeps the compact layout; tablet and wider use expanded layouts.
  static bool useTabletLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMinWidth;

  /// On tablet, return [value] as raw logical pixels so ScreenUtil does not
  /// inflate sizes into narrow multi-pane columns. On phone, use `.w`.
  static double tabletAwareWidth(BuildContext context, double value) =>
      useTabletLayout(context) ? value : value.w;

  /// On tablet, return [value] as raw logical pixels. On phone, use `.h`.
  static double tabletAwareHeight(BuildContext context, double value) =>
      useTabletLayout(context) ? value : value.h;

  /// On tablet, return [value] as raw logical pixels. On phone, use `.sp`.
  static double tabletAwareSp(BuildContext context, double value) =>
      useTabletLayout(context) ? value : value.sp;

  /// On tablet, return [value] as raw logical pixels. On phone, use `.r`.
  static double tabletAwareRadius(BuildContext context, double value) =>
      useTabletLayout(context) ? value : value.r;

  /// Inflate card shell height on landscape (scaleW >> scaleH) so ScreenUtil
  /// `.w`/`.sp` content fits, then parent can scale the card back down.
  static double landscapeAwareCardHeight([double design = 140]) {
    final sw = ScreenUtil().scaleWidth;
    final sh = ScreenUtil().scaleHeight;
    if (sw > sh * 1.15) {
      return design.h * (sw / sh).clamp(1.0, 2.6);
    }
    return design.h;
  }

  /// Prefer filling a tight parent (tablet scale box); otherwise landscape-aware.
  static double shellHeight(
    BoxConstraints constraints, {
    double? explicit,
    double design = 140,
  }) {
    if (explicit != null) return explicit;
    if (constraints.hasBoundedHeight && constraints.maxHeight < 10000) {
      return constraints.maxHeight;
    }
    return landscapeAwareCardHeight(design);
  }

  /// True when the whole screen is tablet-sized (matches [useTabletLayout]).
  static bool get isTabletScreen =>
      ScreenUtil().screenWidth >= tabletMinWidth;

  static EdgeInsets screenPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (isDesktopWidth(width)) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    }
    if (isLargeTabletWidth(width)) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
    }
    if (isTabletWidth(width)) {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
  }

  static double cappedContentWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final max = isDesktopWidth(width)
        ? contentMaxWidthDesktop
        : isTabletWidth(width)
            ? contentMaxWidthTablet
            : width;
    return width < max ? width : max;
  }
}

/// Smart units for **full sub-screens** (headers, lists, forms, bottom bars).
///
/// On tablet, returns the design value as raw logical pixels so ScreenUtil
/// does not inflate widths/fonts (~2.5× on landscape iPad). On phone, falls
/// back to standard `.w` / `.h` / `.sp` / `.r` — phone UI is unchanged.
///
/// Do **not** use these inside home tablet card scale boxes (those need
/// [UniformTabletScale] `.uh` / `.usp` / `.ur` instead).
extension SmartTabletScale on num {
  bool get _tab => ResponsiveBreakpoints.isTabletScreen;

  double get tw => _tab ? toDouble() : w;
  double get th => _tab ? toDouble() : h;
  double get tsp => _tab ? toDouble() : sp;
  double get tr => _tab ? toDouble() : r;
}

/// Centers body content with smart horizontal padding + max width on tablet.
///
/// Phone: passes [child] through unchanged.
/// Tablet: caps width, adds horizontal padding, and fills available height
/// when the parent provides a bounded max height (typical [Expanded] body).
class TabletContentFrame extends StatelessWidget {
  const TabletContentFrame({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
    this.applyVerticalPadding = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;

  /// When false (default), only horizontal padding is applied so lists can
  /// scroll edge-to-edge vertically under the glass header.
  final bool applyVerticalPadding;

  @override
  Widget build(BuildContext context) {
    if (!ResponsiveBreakpoints.useTabletLayout(context)) {
      return child;
    }

    final base = ResponsiveBreakpoints.screenPadding(context);
    final framePad = padding ??
        (applyVerticalPadding
            ? base
            : EdgeInsets.symmetric(horizontal: base.horizontal / 2));
    final cap = maxWidth ?? ResponsiveBreakpoints.cappedContentWidth(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? (constraints.maxWidth < cap ? constraints.maxWidth : cap)
            : cap;
        Widget framed = Padding(
          padding: framePad,
          child: child,
        );
        if (constraints.hasBoundedHeight && constraints.maxHeight < 100000) {
          framed = SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: framed,
          );
        } else {
          framed = SizedBox(width: width, child: framed);
        }
        return Align(alignment: Alignment.topCenter, child: framed);
      },
    );
  }
}

/// Uniform ScreenUtil units for home cards rendered inside tablet scale boxes.
///
/// On landscape tablets ScreenUtil's `scaleWidth` (≈2.5) diverges hugely from
/// `scaleHeight`/min-scale (≈0.85), so `.h`/`.sp`/`.r` values come out ~3×
/// smaller than `.w` values and cards lose their phone proportions (sharp
/// corners, tiny fonts, crushed vertical padding). These getters scale EVERY
/// axis by `scaleWidth` on tablet — matching the tablet card source box, which
/// is also built with `scaleWidth` on both axes — so cards keep the exact
/// phone shape. On phones they fall back to the standard units (no change).
extension UniformTabletScale on num {
  bool get _tab => ResponsiveBreakpoints.isTabletScreen;

  /// Uniform height unit: `.h` on phone, width-scaled on tablet.
  double get uh => _tab ? this * ScreenUtil().scaleWidth : h;

  /// Uniform font unit: `.sp` on phone, width-scaled on tablet.
  double get usp => _tab ? this * ScreenUtil().scaleWidth : sp;

  /// Uniform radius unit: `.r` on phone, width-scaled on tablet.
  double get ur => _tab ? this * ScreenUtil().scaleWidth : r;
}

import 'package:el_race/ui/navigation/home_navigation.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Logo (left) + glass pill at 50% screen width (fixed height).
class SubAppGlassAppBar extends StatelessWidget {
  const SubAppGlassAppBar({
    super.key,
    this.transparentPill = false,
    this.lightSurfaceTransparentPill = false,
    this.logoOpacity = 0.55,
  });

  final bool transparentPill;

  /// Slightly see-through glass on light hubs (keeps dark icons).
  final bool lightSurfaceTransparentPill;
  final double logoOpacity;

  static const double _barHeight = 50;
  static const double _pillBadgeInset = 10;

  /// Total height of logo + glass row (incl. status bar inset + pill badge room).
  static double extent(BuildContext context) {
    return MediaQuery.paddingOf(context).top +
        2.h +
        _barHeight.h +
        _pillBadgeInset.h;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final screenW = MediaQuery.sizeOf(context).width;
    final pillWidth = screenW * 0.5;
    final rowHeight = _barHeight.h + _pillBadgeInset.h;

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, top + 2.h, 12.w, 0),
      child: SizedBox(
        height: rowHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: screenW - pillWidth - 24.w,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => HomeNavigation.goToHome(context),
                    borderRadius: BorderRadius.circular(8.r),
                    child: Opacity(
                      opacity: logoOpacity,
                      child: Image.asset(
                        'assets/gif/el-race-logo.gif',
                        height: _barHeight.h,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: pillWidth,
              child: Align(
                alignment: Alignment.center,
                child: HomeGlassAppBar(
                  hideLeadingActionIcons: true,
                  omitOuterPadding: true,
                  compactTrailing: true,
                  transparentPill: transparentPill,
                  lightSurfaceTransparentPill: lightSurfaceTransparentPill,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/ui/chat/theme/chat_glass_theme.dart';
import 'package:el_race/ui/navigation/home_navigation.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Chat-only top chrome: company logo + water-glass actions pill.
class ChatTopGlassAppBar extends StatelessWidget {
  const ChatTopGlassAppBar({super.key});

  static const double _barHeight = 50;
  static const double _pillBadgeInset = 6;

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
    final radius = BorderRadius.circular(999);

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
                      opacity: 0.95,
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
                child: AdaptiveGlassLayer(
                  borderRadius: radius,
                  sigma: 14,
                  fallbackColor: ChatGlassTheme.waterFillStrong,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.28),
                          ChatGlassTheme.waterFill,
                          Colors.white.withValues(alpha: 0.1),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0A2848).withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const HomeGlassAppBar(
                      hideLeadingActionIcons: true,
                      omitOuterPadding: true,
                      compactTrailing: true,
                      transparentPill: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:ui';

import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_my_actions_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeQuickActionsGlass extends StatelessWidget {
  const HomeQuickActionsGlass({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 4.h),
      child: HomeGlassTheme.glassSurface(
        borderRadius: BorderRadius.circular(18.r),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ActionTile(
              iconAsset: 'assets/newapp/newicon/hr.png',
              label: 'HR',
              badge: '2',
              tint: const Color(0xFFE8F4FC),
              onTap: () =>
                  HomeMyActionsNavigation.open(context, HomeMyAction.hr),
            ),
            _ActionTile(
              iconAsset: 'assets/newapp/newicon/rfq.png',
              label: 'RFQ',
              tint: const Color(0xFFF0F4FF),
              onTap: () =>
                  HomeMyActionsNavigation.open(context, HomeMyAction.rfq),
            ),
            _ActionTile(
              iconAsset: 'assets/png/my-reports-frame.png',
              label: 'Timesheets',
              tint: const Color(0xFFF5F0FF),
              onTap: () => HomeMyActionsNavigation.open(
                context,
                HomeMyAction.timesheets,
              ),
            ),
            _ActionTile(
              iconAsset: 'assets/newapp/newicon/Invoice.png',
              label: 'Invoice',
              tint: const Color(0xFFFFF5F0),
              onTap: () => HomeMyActionsNavigation.open(
                context,
                HomeMyAction.invoice,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.iconAsset,
    required this.label,
    required this.tint,
    required this.onTap,
    this.badge,
  });

  final String iconAsset;
  final String label;
  final Color tint;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      width: 48.w,
                      height: 48.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(13.r),
                        ),
                        child: Center(
                          child: Image.asset(
                            iconAsset,
                            width: 26.w,
                            height: 26.w,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE31937),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge!,
                        style: GoogleFonts.poppins(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 5.h),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: HomeGlassTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:ui';

import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

enum PurchaseHubViewMode { hub, analytics, ai }

/// Bottom scroll inset when the floating view bar is visible.
abstract final class PurchaseHubViewBarLayout {
  static double scrollBottomPadding(BuildContext context) {
    return 82.h + MediaQuery.paddingOf(context).bottom + 10.h;
  }
}

/// Faded sky-blue floating bottom bar — Hub / Stats / AI.
class PurchaseHubFloatingViewBar extends StatelessWidget {
  const PurchaseHubFloatingViewBar({
    super.key,
    required this.mode,
    required this.onHubTap,
    required this.onAnalyticsTap,
    required this.onAiTap,
  });

  final PurchaseHubViewMode mode;
  final VoidCallback onHubTap;
  final VoidCallback onAnalyticsTap;
  final VoidCallback onAiTap;

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, bottomSafe + 10.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFE8F6FF).withValues(alpha: 0.92),
                  const Color(0xFFD4EBFA).withValues(alpha: 0.88),
                ],
              ),
              borderRadius: BorderRadius.circular(26.r),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: PurchaseTheme.accentBlue.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ModeIcon(
                  icon: Icons.grid_view_rounded,
                  label: 'Hub',
                  isActive: mode == PurchaseHubViewMode.hub,
                  onTap: onHubTap,
                ),
                _ModeIcon(
                  icon: Icons.analytics_rounded,
                  label: 'Stats',
                  isActive: mode == PurchaseHubViewMode.analytics,
                  onTap: onAnalyticsTap,
                ),
                _AiModeIcon(
                  isActive: mode == PurchaseHubViewMode.ai,
                  onTap: onAiTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeIcon extends StatelessWidget {
  const _ModeIcon({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              gradient: isActive
                  ? const LinearGradient(
                      colors: [
                        PurchaseTheme.accentBlue,
                        PurchaseTheme.accentDeep,
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.72),
                        const Color(0xFFE8F4FC).withValues(alpha: 0.5),
                      ],
                    ),
              border: Border.all(
                color: isActive
                    ? PurchaseTheme.accentDeep.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.9),
                width: isActive ? 1.6 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: PurchaseTheme.accentBlue.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : PurchaseTheme.accentDeep,
              size: 22.sp,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? PurchaseTheme.accentDeep
                  : PurchaseTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiModeIcon extends StatelessWidget {
  const _AiModeIcon({required this.isActive, required this.onTap});

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              gradient: LinearGradient(
                colors: isActive
                    ? const [
                        Color(0xFF7C3AED),
                        Color(0xFF4F46E5),
                      ]
                    : [
                        const Color(0xFFEDE9FE).withValues(alpha: 0.9),
                        const Color(0xFFE0E7FF).withValues(alpha: 0.7),
                      ],
              ),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF6D28D9).withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.9),
                width: isActive ? 1.8 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 6.h,
                  right: 8.w,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 8.sp,
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.85)
                        : const Color(0xFF7C3AED),
                  ),
                ),
                Text(
                  'Ai',
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: isActive ? Colors.white : const Color(0xFF5B21B6),
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            'AI',
            style: GoogleFonts.poppins(
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? const Color(0xFF6D28D9)
                  : PurchaseTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

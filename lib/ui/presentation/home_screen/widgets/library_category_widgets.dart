import 'package:el_race/ui/presentation/home_screen/providers/home_library_widgets_provider.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/category_widget_gradient_border.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/parayer_widgets/parayer_widget.dart';
import 'package:el_race/ui/presentation/media/screens/media_list_screen.dart';
import 'package:el_race/ui/presentation/my_documents/screens/my_documents_screen.dart';
import 'package:el_race/utils/Util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// v7 Library category — Documents, Media, Prayer Times (stacked full-width).
class LibraryCategoryMyDocumentsCard extends ConsumerWidget {
  const LibraryCategoryMyDocumentsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeMyDocumentsWidgetProvider);
    final trendColor = _documentsTrendColor(data.trendColor);

    return _LibraryFullCardShell(
      height: 140.h,
      onTap: () => Util.pushPage(const MyDocumentsScreen(), context),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF0F3F8),
          Color(0xFFE5E9F0),
          Color(0xFFD8DEE8),
          Color(0xFFCFD5DE),
        ],
      ),
      iconBadge: const _DocumentsIconBadge(),
      pattern: CustomPaint(
        painter: _StackedPapersPainter(),
        size: Size(168.w, 168.h),
      ),
      contentPadding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PERSONAL',
            style: GoogleFonts.poppins(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFB8860B),
              letterSpacing: 0.55,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            'My Documents',
            style: GoogleFonts.poppins(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A2A4F),
            ),
          ),
          const Spacer(),
          Text(
            '${data.totalCount}',
            style: GoogleFonts.poppins(
              fontSize: 34.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A2A4F),
              height: 1,
            ),
          ),
          if (data.trendMessage.isNotEmpty)
            Text(
              data.trendMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: trendColor,
              ),
            ),
        ],
      ),
    );
  }
}

class LibraryCategoryMediaCard extends ConsumerWidget {
  const LibraryCategoryMediaCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeMediaWidgetProvider);
    const accentGreen = Color(0xFF86EFAC);

    return _LibraryFullCardShell(
      height: 150.h,
      onTap: () => Util.pushPage(const MediaListScreen(), context),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1A1F2E),
          Color(0xFF1A1F2E),
          Color(0xFF141820),
          Color(0xFF0F0F15),
        ],
      ),
      background: const _MediaCardBackground(),
      contentPadding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      child: SizedBox(
        height: 122.h,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GALLERY',
              style: GoogleFonts.poppins(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: accentGreen,
                letterSpacing: 0.55,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              'Media',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Text(
              '${data.totalCount}',
              style: GoogleFonts.poppins(
                fontSize: 36.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
            if (data.trendMessage.isNotEmpty)
              Text(
                data.trendMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: accentGreen,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaCardBackground extends StatelessWidget {
  const _MediaCardBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        const ColoredBox(color: Color(0xFF1A1F2E)),
        Positioned.fill(
          child: Opacity(
            opacity: 0.28,
            child: Image.asset(
              'assets/newapp/media_widget_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
            ),
          ),
        ),
        Positioned(
          right: -28.w,
          bottom: -30.h,
          child: Container(
            width: 140.w,
            height: 140.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 2.5,
              ),
            ),
          ),
        ),
        Positioned(
          right: -10.w,
          bottom: -12.h,
          child: Container(
            width: 100.w,
            height: 100.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LibraryCategoryPrayerTimesCard extends StatelessWidget {
  const LibraryCategoryPrayerTimesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: ParayerWidget(),
    );
  }
}

Color _documentsTrendColor(String color) {
  switch (color) {
    case 'red':
      return const Color(0xFFDC2626);
    case 'amber':
      return const Color(0xFFD97706);
    default:
      return const Color(0xFF16A34A);
  }
}

class _LibraryFullCardShell extends StatelessWidget {
  const _LibraryFullCardShell({
    required this.height,
    required this.child,
    required this.gradient,
    this.iconBadge,
    this.pattern,
    this.background,
    this.onTap,
    this.contentPadding,
  });

  final double height;
  final Widget child;
  final LinearGradient gradient;
  final Widget? iconBadge;
  final Widget? pattern;
  final Widget? background;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final innerRadius =
        (22.r - CategoryWidgetGradientBorder.width).clamp(0.0, double.infinity);
    final rightPad = iconBadge != null ? 46.w : 16.w;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.r),
        child: Container(
          height: height,
          decoration: CategoryWidgetGradientBorder.outer(borderRadius: 22.r),
          padding: CategoryWidgetGradientBorder.padding,
          child: Container(
            decoration: CategoryWidgetGradientBorder.inner(
              borderRadius: 22.r,
              fillGradient: gradient,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(innerRadius),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                fit: StackFit.expand,
                children: [
                  if (background != null) IgnorePointer(child: background!),
                  if (pattern != null)
                    Align(
                      alignment: Alignment.topRight,
                      child: IgnorePointer(child: pattern!),
                    ),
                  Padding(
                    padding: contentPadding ??
                        EdgeInsets.fromLTRB(14.w, 12.h, rightPad, 12.h),
                    child: child,
                  ),
                  if (iconBadge != null)
                    Positioned(top: 8.h, right: 8.w, child: iconBadge!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentsIconBadge extends StatelessWidget {
  const _DocumentsIconBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.w,
      height: 40.w,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
        ),
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8860B).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(Icons.description_outlined, color: Colors.white, size: 20.sp),
    );
  }
}

class _StackedPapersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A2A4F).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 3; i++) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(8 + i * 6.0, 10 + i * 5.0, size.width * 0.55, size.height * 0.5),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Post check-in / check-out success. Done → pop to root (Home).
class CheckinSuccessScreen extends StatelessWidget {
  const CheckinSuccessScreen({
    super.key,
    required this.isCheckIn,
    required this.serverTimeRaw,
    required this.profilePhotoUrl,
    required this.locationTitle,
    this.locationSubtitle,
  });

  final bool isCheckIn;
  final String? serverTimeRaw;
  final String? profilePhotoUrl;
  final String locationTitle;
  final String? locationSubtitle;

  @override
  Widget build(BuildContext context) {
    final title = isCheckIn ? 'Checked In' : 'Checked Out';
    final pill = isCheckIn ? 'Check In Successful' : 'Check Out Successful';
    final timeLabel = _formatTime(serverTimeRaw);
    final dateLabel = _formatToday();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done(context);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: [
                  SizedBox(height: 36.h),
                  Container(
                    width: 88.w,
                    height: 88.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: HomeGlassTheme.bottleGreen,
                      size: 64.sp,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w700,
                      color: HomeGlassTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    dateLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: HomeGlassTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    timeLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 40.sp,
                      fontWeight: FontWeight.w700,
                      color: HomeGlassTheme.bottleGreen,
                    ),
                  ),
                  SizedBox(height: 28.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: SizedBox(
                            width: 64.w,
                            height: 64.w,
                            child: _photo(profilePhotoUrl),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 16.sp,
                                    color: HomeGlassTheme.bottleGreen,
                                  ),
                                  SizedBox(width: 4.w),
                                  Expanded(
                                    child: Text(
                                      locationTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: HomeGlassTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if ((locationSubtitle ?? '').isNotEmpty) ...[
                                SizedBox(height: 4.h),
                                Text(
                                  locationSubtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.sp,
                                    color: HomeGlassTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check,
                          color: HomeGlassTheme.bottleGreen,
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          pill,
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: HomeGlassTheme.bottleGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: () => _done(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HomeGlassTheme.bottleGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: Text(
                        'Done',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _done(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Test helper: same pop behaviour as Done.
  @visibleForTesting
  static void popToRoot(BuildContext context) => _done(context);

  static Widget _photo(String? url) {
    final trimmed = (url ?? '').trim();
    if (trimmed.isEmpty) {
      return ColoredBox(
        color: const Color(0xFFE5E7EB),
        child: Icon(Icons.person, color: Colors.grey.shade500, size: 32),
      );
    }
    return CachedNetworkImage(
      imageUrl: trimmed,
      fit: BoxFit.cover,
      placeholder: (_, __) => const ColoredBox(color: Color(0xFFE5E7EB)),
      errorWidget: (_, __, ___) => ColoredBox(
        color: const Color(0xFFE5E7EB),
        child: Icon(Icons.person, color: Colors.grey.shade500, size: 32),
      ),
    );
  }

  static String _formatToday() {
    final now = DateTime.now();
    return 'Today, ${DateFormat('d MMM yyyy').format(now)}';
  }

  static String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty || raw == '00:00:00' || raw == '--:--') {
      return DateFormat('HH:mm').format(DateTime.now());
    }
    final parts = raw.trim().split(RegExp(r'[\sT]'));
    final timePart = parts.length > 1 ? parts.last : parts.first;
    final hm = timePart.split(':');
    if (hm.length >= 2) {
      return '${hm[0].padLeft(2, '0')}:${hm[1].padLeft(2, '0')}';
    }
    return timePart;
  }
}

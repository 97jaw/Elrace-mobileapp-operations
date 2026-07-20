import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:location/location.dart';

/// Dismissible "enable location services" banner for the check-in panel.
///
/// Replaces the old non-dismissible `AlertDialog` that HomeScreen popped on
/// every mount/resume whenever device location was off — a standalone
/// "stuck screen" source. Location is now enforced where it matters: this
/// banner appears when the attendance panel opens with location services
/// disabled, and check-in's own validation still blocks an actual punch
/// without a valid position.
class LocationServiceBanner extends StatefulWidget {
  const LocationServiceBanner({super.key});

  @override
  State<LocationServiceBanner> createState() => _LocationServiceBannerState();
}

class _LocationServiceBannerState extends State<LocationServiceBanner>
    with WidgetsBindingObserver {
  final Location _location = Location();
  bool _serviceOff = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check when the user comes back from Settings after enabling location.
  // Scoped to this banner's lifetime (attendance panel open), not app-wide.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _serviceOff) {
      _checkService();
    }
  }

  Future<void> _checkService() async {
    try {
      final enabled = await _location.serviceEnabled();
      if (mounted) setState(() => _serviceOff = !enabled);
    } catch (_) {}
  }

  Future<void> _requestService() async {
    try {
      final enabled = await _location.requestService();
      if (mounted) setState(() => _serviceOff = !enabled);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_serviceOff || _dismissed) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 10.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF0B75A)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.location_off_rounded,
              color: Color(0xFFB86E00),
              size: 20,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                translate('location.please_enable'),
                style: GoogleFonts.poppins(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF7A4A00),
                  height: 1.25,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            TextButton(
              onPressed: _requestService,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                minimumSize: Size(0, 30.h),
                backgroundColor: const Color(0xFFB86E00),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                translate('location.enable_service'),
                style: GoogleFonts.poppins(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _dismissed = true),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Color(0xFFB86E00),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

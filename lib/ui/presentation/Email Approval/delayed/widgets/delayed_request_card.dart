import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/constants/app_images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// A card widget for displaying a delayed request item
/// Matches the design from the screenshot with employee image, request info, and days delayed badge
class DelayedRequestCard extends StatelessWidget {
  final String reqNo;
  final String requestType;
  final String employeeName;
  final String empCode;
  final String requestDate;
  final String employeeImageUrl;
  final int daysDelayed;
  final VoidCallback? onTap;

  const DelayedRequestCard({
    super.key,
    required this.reqNo,
    required this.requestType,
    required this.employeeName,
    required this.empCode,
    required this.requestDate,
    required this.employeeImageUrl,
    required this.daysDelayed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double stripWidth = 34;

    return Container(
      height: 165.tw,
      margin: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 4.tw),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18.tr),
          child: Stack(
            children: [
              Positioned.fill(
                child: Ink(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8DCE1),
                    borderRadius: BorderRadius.circular(18.tr),
                    border:
                        Border.all(color: const Color(0xFF80858C), width: 1),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 8.tw,
                    right: 8.tw + stripWidth,
                    top: 9.tw,
                    bottom: 8.tw,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 36.tw,
                              child: Stack(
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      width: 36.tw,
                                      height: 36.tw,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFE7EBEF),
                                          width: 1.3,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: _buildEmployeeImage(36.tw),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 40.tw),
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          reqNo,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16.tsp,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF0B2D5E),
                                            letterSpacing: 0.2,
                                          ),
                                          maxLines: null,
                                          overflow: TextOverflow.visible,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.tw),
                      Padding(
                        padding: EdgeInsets.only(left: 2.tw),
                        child: Text(
                          requestType,
                          style: GoogleFonts.poppins(
                            fontSize: 13.tsp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF121212),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      SizedBox(height: 2.tw),
                      Padding(
                        padding: EdgeInsets.only(left: 2.tw),
                        child: Text(
                          employeeName,
                          style: GoogleFonts.poppins(
                            fontSize: 11.tsp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6C7075),
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      SizedBox(height: 1.5.tw),
                      Padding(
                        padding: EdgeInsets.only(left: 2.tw),
                        child: Text(
                          empCode,
                          style: GoogleFonts.poppins(
                            fontSize: 11.tsp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF565B61),
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.only(left: 2.tw),
                        child: Text(
                          requestDate,
                          style: GoogleFonts.poppins(
                            fontSize: 9.tsp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF70757C),
                          ),
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 20.tw,
                bottom: 0,
                child: SizedBox(
                  width: stripWidth,
                  height: double.infinity,
                  child: ColoredBox(
                    color: const Color(0xFFC62828),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$daysDelayed',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20.tsp,
                                height: 1.0,
                              ),
                            ),
                            SizedBox(height: 6.tw),
                            RotatedBox(
                              quarterTurns: 3,
                              child: Text(
                                'Days Delayed',
                                textAlign: TextAlign.center,
                                maxLines: null,
                                overflow: TextOverflow.visible,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 8.tsp,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeImage(double size) {
    final url = employeeImageUrl.trim();
    if (url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        height: size,
        width: size,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            AppImages.personImage,
            fit: BoxFit.cover,
            height: size,
            width: size,
          );
        },
      );
    }

    return Image.asset(
      AppImages.personImage,
      fit: BoxFit.cover,
      height: size,
      width: size,
    );
  }
}

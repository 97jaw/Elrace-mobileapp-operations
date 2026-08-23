import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Glassy company logo bar (no back). Back lives on [DrawingStudioHeadingCard].
class DrawingStudioChromeHeader extends StatelessWidget {
  const DrawingStudioChromeHeader({
    super.key,
    this.trailing = const [],
  });

  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return ContextualGlassChromeHeader(
      onLightSurface: true,
      transparentGlassBar: true,
      showBack: false,
      trailing: trailing,
    );
  }
}

/// Studio page heading: back + drawing icon + title, tricolor border.
class DrawingStudioHeadingCard extends StatelessWidget {
  const DrawingStudioHeadingCard({
    super.key,
    required this.title,
    this.onBack,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  static const _green = Color(0xFF0D9488);
  static const _blue = Color(0xFF2563EB);
  static const _red = Color(0xFFE63946);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.uh, 16.w, 10.uh),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.ur),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [_green, _blue, _red],
          ),
        ),
        padding: const EdgeInsets.all(1.6),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.5.ur),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.uh),
            child: Row(
              children: [
                InkWell(
                  onTap: onBack ?? () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(10.ur),
                  child: Padding(
                    padding: EdgeInsets.all(8.w),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16.usp,
                      color: const Color(0xFF1A2A4F),
                    ),
                  ),
                ),
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.ur),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _green.withValues(alpha: 0.16),
                        _blue.withValues(alpha: 0.14),
                        _red.withValues(alpha: 0.12),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.architecture_rounded,
                    color: _blue,
                    size: 22.usp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 15.usp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A2A4F),
                          height: 1.2,
                        ),
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        SizedBox(height: 2.uh),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11.usp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF7A849C),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

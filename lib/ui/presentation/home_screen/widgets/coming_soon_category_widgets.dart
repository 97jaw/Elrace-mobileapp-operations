import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/elrace_ai/elrace_ai_tour_screen.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/category_widget_gradient_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Elrace AI hero card — opens the auto feature tour.
class ComingSoonCategoryElraceAiCard extends StatelessWidget {
  const ComingSoonCategoryElraceAiCard({super.key, this.tabletCompact = false});

  final bool tabletCompact;

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1040),
      Color(0xFF4C1D95),
      Color(0xFF06B6D4),
      Color(0xFF7C3AED),
    ],
    stops: [0.0, 0.35, 0.72, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    final innerRadius =
        (22.ur - CategoryWidgetGradientBorder.width).clamp(0.0, double.infinity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ElraceAiTourScreen()),
        ),
        borderRadius: BorderRadius.circular(22.ur),
        child: Container(
          height: 170.uh,
          decoration: CategoryWidgetGradientBorder.outer(borderRadius: 22.ur),
          padding: CategoryWidgetGradientBorder.padding,
          child: Container(
            decoration: CategoryWidgetGradientBorder.inner(
              borderRadius: 22.ur,
              fillGradient: _gradient,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(innerRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.35,
                      child: Image.asset(
                        'assets/gif/ai.gif',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            const Color(0xFF1A1040).withValues(alpha: 0.82),
                            const Color(0xFF4C1D95).withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14.uh,
                    left: 18.w,
                    right: 18.w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 3.uh,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8.ur),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            'COMING SOON',
                            style: GoogleFonts.poppins(
                              fontSize: 8.usp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE9D5FF),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(height: 10.uh),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Elrace ',
                                style: GoogleFonts.poppins(
                                  fontSize: 28.usp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              TextSpan(
                                text: 'AI',
                                style: GoogleFonts.poppins(
                                  fontSize: 28.usp,
                                  fontWeight: FontWeight.w800,
                                  foreground: Paint()
                                    ..shader = const LinearGradient(
                                      colors: [
                                        Color(0xFF67E8F9),
                                        Color(0xFFC4B5FD),
                                      ],
                                    ).createShader(
                                      const Rect.fromLTWH(0, 0, 80, 40),
                                    ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 4.uh),
                        Text(
                          'Your intelligent ERP copilot — tap to preview the tour',
                          style: GoogleFonts.poppins(
                            fontSize: 12.usp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.88),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 12.uh,
                    right: 14.w,
                    child: Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 22.usp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

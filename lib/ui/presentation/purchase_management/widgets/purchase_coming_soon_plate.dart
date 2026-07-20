import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Glass "coming soon" plate with themed vector illustration.
class PurchaseComingSoonPlate extends StatelessWidget {
  const PurchaseComingSoonPlate({
    super.key,
    required this.title,
    required this.message,
    required this.illustration,
    this.bottomPadding = 24,
  });

  final String title;
  final String message;
  final Widget illustration;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.tw, 24.th, 16.tw, bottomPadding),
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 20.tw, vertical: 28.th),
          decoration: PurchaseTheme.glassCard(radius: 24.tr),
          child: Column(
            children: [
              illustration,
              SizedBox(height: 24.th),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 20.tsp,
                  fontWeight: FontWeight.w700,
                  color: PurchaseTheme.textPrimary,
                ),
              ),
              SizedBox(height: 8.th),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12.tsp,
                  height: 1.5,
                  color: PurchaseTheme.textSecondary,
                ),
              ),
              SizedBox(height: 16.th),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 6.th),
                decoration: BoxDecoration(
                  color: PurchaseTheme.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20.tr),
                  border: Border.all(
                    color: PurchaseTheme.accentBlue.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  'Coming soon',
                  style: GoogleFonts.poppins(
                    fontSize: 11.tsp,
                    fontWeight: FontWeight.w700,
                    color: PurchaseTheme.accentDeep,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Vector-style analytics chart illustration (CustomPaint).
class PurchaseAnalyticsVectorIllustration extends StatelessWidget {
  const PurchaseAnalyticsVectorIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200.tw,
      height: 140.th,
      child: CustomPaint(
        painter: _AnalyticsVectorPainter(),
      ),
    );
  }
}

class _AnalyticsVectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Soft background circle
    final bgPaint = Paint()
      ..color = PurchaseTheme.accentBlue.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.5, h * 0.45), w * 0.38, bgPaint);

    // Grid lines
    final gridPaint = Paint()
      ..color = PurchaseTheme.accentBlue.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = h * 0.2 + (h * 0.55 / 3) * i;
      canvas.drawLine(Offset(w * 0.12, y), Offset(w * 0.88, y), gridPaint);
    }

    // Bar chart
    final bars = [0.45, 0.72, 0.55, 0.88, 0.62];
    final barW = w * 0.1;
    final gap = w * 0.04;
    final baseY = h * 0.78;
    final maxBarH = h * 0.48;

    for (var i = 0; i < bars.length; i++) {
      final x = w * 0.16 + i * (barW + gap);
      final barH = maxBarH * bars[i];
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, baseY - barH, barW, barH),
        const Radius.circular(4),
      );
      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            PurchaseTheme.accentDeep.withValues(alpha: 0.85),
            PurchaseTheme.accentBlue.withValues(alpha: 0.55),
          ],
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, barPaint);
    }

    // Trend line
    final linePaint = Paint()
      ..color = const Color(0xFF7C3AED).withValues(alpha: 0.75)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final points = [
      Offset(w * 0.16, h * 0.52),
      Offset(w * 0.32, h * 0.38),
      Offset(w * 0.48, h * 0.44),
      Offset(w * 0.64, h * 0.28),
      Offset(w * 0.80, h * 0.34),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    for (final p in points) {
      canvas.drawCircle(
        p,
        4,
        Paint()..color = const Color(0xFF7C3AED),
      );
      canvas.drawCircle(
        p,
        7,
        Paint()
          ..color = const Color(0xFF7C3AED).withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Pie slice accent (top-right)
    final piePaint = Paint()
      ..color = PurchaseTheme.pendingBadge.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.82, h * 0.18), radius: w * 0.1),
      -0.5,
      1.8,
      true,
      piePaint,
    );
    final piePaint2 = Paint()
      ..color = const Color(0xFF16A34A).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.82, h * 0.18), radius: w * 0.1),
      1.3,
      2.5,
      true,
      piePaint2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

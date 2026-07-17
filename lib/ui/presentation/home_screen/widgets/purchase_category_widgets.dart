import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_lpo_widget_provider.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/category_widget_gradient_border.dart';
import 'package:el_race/ui/presentation/purchase_management/providers/purchase_providers.dart';
import 'package:el_race/ui/presentation/purchase_management/screens/purchase_management_hub_screen.dart';
import 'package:el_race/utils/Util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// v7 Purchase category — LPO full-width card.
class PurchaseCategoryLpoCard extends ConsumerWidget {
  const PurchaseCategoryLpoCard({super.key, this.tabletCompact = false});

  final bool tabletCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeLpoWidgetProvider);
    final purchaseAccess = ref.watch(purchaseAccessProvider);

    if (!data.isAuthorized && !purchaseAccess.hasAnyAccess) {
      return const _LpoUnauthorizedCard();
    }

    final title = data.titleLine.isNotEmpty
        ? data.titleLine
        : (data.monthLabel.isNotEmpty ? 'LPO · ${data.monthLabel}' : 'LPO');

    return _LpoFullCardShell(
      height: null,
      onTap: () => Util.pushPage(const PurchaseManagementHubScreen(), context),
      iconBadge: const _LpoIconBadge(),
      pattern: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -28.w,
            bottom: -32.uh,
            child: Container(
              width: 178.w,
              height: 178.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7DB3E8).withValues(alpha: 0.44),
                    const Color(0xFF7DB3E8).withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _LpoDiagonalBeamsPainter()),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PURCHASE MANAGEMENT',
            style: GoogleFonts.poppins(
              fontSize: 8.usp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7DB3E8),
              letterSpacing: 0.55,
              height: 1.1,
            ),
          ),
          SizedBox(height: 3.uh),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 14.usp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          SizedBox(height: 8.uh),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LpoStatColumn(
                  label: 'Total',
                  value: '${data.pendingCount + data.approvedCount}',
                  valueColor: Colors.white,
                  valueFontSize: 26.usp,
                ),
                const _LpoStatDivider(),
                _LpoStatColumn(
                  label: 'Open',
                  value: data.pendingLabel,
                  valueColor: const Color(0xFFF59E0D),
                  valueFontSize: 26.usp,
                ),
                const _LpoStatDivider(),
                _LpoStatColumn(
                  label: 'Closed',
                  value: data.approvedLabel,
                  valueColor: const Color(0xFF4ADE80),
                  valueFontSize: 26.usp,
                ),
              ],
            ),
          ),
          SizedBox(height: 6.uh),
          if (data.trendLabel.isNotEmpty)
            Text(
              data.trendLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 10.usp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF7FC0FF),
                height: 1.15,
              ),
            ),
        ],
      ),
    );
  }
}

class _LpoUnauthorizedCard extends StatelessWidget {
  const _LpoUnauthorizedCard();

  @override
  Widget build(BuildContext context) {
    return _LpoFullCardShell(
      iconBadge: const _LpoIconBadge(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PURCHASE MANAGEMENT',
            style: GoogleFonts.poppins(
              fontSize: 8.usp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7DB3E8),
              letterSpacing: 0.55,
            ),
          ),
          SizedBox(height: 3.uh),
          Text(
            'Purchase Mgmt',
            style: GoogleFonts.poppins(
              fontSize: 14.usp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Not authorized',
            style: GoogleFonts.poppins(
              fontSize: 12.usp,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _LpoFullCardShell extends StatelessWidget {
  const _LpoFullCardShell({
    required this.child,
    required this.iconBadge,
    this.pattern,
    this.onTap,
    this.height,
  });

  final Widget child;
  final Widget iconBadge;
  final Widget? pattern;
  final VoidCallback? onTap;
  final double? height;

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E2A4A),
      Color(0xFF2A3654),
      Color(0xFF2E3A5E),
      Color(0xFF243454),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final innerRadius =
        (22.ur - CategoryWidgetGradientBorder.width).clamp(0.0, double.infinity);

    return LayoutBuilder(
      builder: (context, constraints) {
        final shellH = ResponsiveBreakpoints.shellHeight(
          constraints,
          explicit: height,
        );
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22.ur),
            child: Container(
              height: shellH,
              width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
              decoration:
                  CategoryWidgetGradientBorder.outer(borderRadius: 22.ur),
              padding: CategoryWidgetGradientBorder.padding,
              child: Container(
                decoration: CategoryWidgetGradientBorder.inner(
                  borderRadius: 22.ur,
                  fillGradient: _gradient,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(innerRadius),
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      if (pattern != null)
                        Positioned.fill(
                          child: IgnorePointer(child: pattern!),
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(14.w, 12.uh, 46.w, 12.uh),
                        child: LayoutBuilder(
                          builder: (context, inner) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topLeft,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: inner.maxWidth,
                                  ),
                                  child: child,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(top: 8.uh, right: 8.w, child: iconBadge),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LpoIconBadge extends StatelessWidget {
  const _LpoIconBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34.w,
      height: 34.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11.ur),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B9FE8), Color(0xFF3E7BFA)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3E7BFA).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(Icons.receipt_long_rounded, size: 18.usp, color: Colors.white),
    );
  }
}

class _LpoStatColumn extends StatelessWidget {
  const _LpoStatColumn({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.valueFontSize,
  });

  final String label;
  final String value;
  final Color valueColor;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 7.5.usp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8A9BB5),
              letterSpacing: 0.35,
              height: 1.1,
            ),
          ),
          SizedBox(height: 5.uh),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.poppins(
                fontSize: valueFontSize,
                fontWeight: FontWeight.w800,
                color: valueColor,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LpoStatDivider extends StatelessWidget {
  const _LpoStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: EdgeInsets.symmetric(horizontal: 8.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.18),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _LpoDiagonalBeamsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final solid = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF7DB3E8).withValues(alpha: 0.08),
          const Color(0xFF7DB3E8).withValues(alpha: 0.62),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final medium = Paint()
      ..color = const Color(0xFF7DB3E8).withValues(alpha: 0.34)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final faint = Paint()
      ..color = const Color(0xFF9CC8F0).withValues(alpha: 0.22)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(size.width * 0.52, size.height * 0.02);
    canvas.rotate(-0.436); // ~-25°

    canvas.drawLine(
      const Offset(-24, 0),
      Offset(size.width * 0.72, 0),
      solid,
    );
    canvas.drawLine(
      Offset(-12, size.height * 0.2),
      Offset(size.width * 0.62, size.height * 0.2),
      medium,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.4),
      Offset(size.width * 0.52, size.height * 0.4),
      faint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

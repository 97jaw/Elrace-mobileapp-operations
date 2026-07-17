import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/PettyCash/PettyCashScreen.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_petty_cash_widget_provider.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/category_widget_gradient_border.dart';
import 'package:el_race/utils/Util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// v7 Finance category — Petty Cash full-width card.
class FinanceCategoryPettyCashCard extends ConsumerWidget {
  const FinanceCategoryPettyCashCard({super.key, this.tabletCompact = false});

  final bool tabletCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homePettyCashWidgetProvider);

    if (!data.isAuthorized) {
      return const _PettyCashUnauthorizedCard();
    }

    final availableColor =
        data.isOverspent ? const Color(0xFFFF6B7A) : Colors.white;
    final trendColor = _trendColor(data);

    return _PettyCashFullCardShell(
      height: null,
      onTap: () => Util.pushPage(const PettyCashScreen(), context),
      iconBadge: const _PettyCashIconBadge(),
      pattern: Stack(
        clipBehavior: Clip.hardEdge,
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -36.w,
            top: -48.uh,
            child: Container(
              width: 200.w,
              height: 200.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4ADE80).withValues(alpha: 0.26),
                    const Color(0xFF4ADE80).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            right: 4.w,
            top: 2.uh,
            child: CustomPaint(
              size: Size(108.w, 108.w),
              painter: _PettyCashRingPainter(),
            ),
          ),
          Positioned(
            right: 2.w,
            bottom: -6.uh,
            child: Text(
              'د.إ',
              style: GoogleFonts.poppins(
                fontSize: 58.usp,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.18),
                height: 1,
              ),
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BALANCE',
            style: GoogleFonts.poppins(
              fontSize: 10.usp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF9CA3AF),
              letterSpacing: 0.55,
              height: 1.1,
            ),
          ),
          SizedBox(height: 4.uh),
          Text(
            'Petty Cash',
            style: GoogleFonts.poppins(
              fontSize: 17.usp,
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
                _PettyCashStatColumn(
                  label: 'Available',
                  value: data.availableDisplay,
                  valueColor: availableColor,
                  valueFontSize: 22.usp,
                ),
                const _PettyCashStatDivider(),
                _PettyCashStatColumn(
                  label: 'Spent',
                  value: data.spentDisplay,
                  valueColor: const Color(0xFFF59E3D),
                  valueFontSize: 22.usp,
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
                fontSize: 11.usp,
                fontWeight: FontWeight.w600,
                color: trendColor,
                height: 1.15,
              ),
            ),
          if (data.pendingLabel.isNotEmpty) ...[
            SizedBox(height: 2.uh),
            Text(
              data.pendingLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 10.usp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF59E0B),
                height: 1.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Color _trendColor(PettyCashWidgetRecord data) {
  switch (data.statusFlag) {
    case 'overspent':
      return const Color(0xFFFF6B7A);
    case 'empty':
      return const Color(0xFF9CA3AF);
    default:
      return const Color(0xFF89B7E9);
  }
}

class _PettyCashUnauthorizedCard extends StatelessWidget {
  const _PettyCashUnauthorizedCard();

  @override
  Widget build(BuildContext context) {
    return const _PettyCashFullCardShell(
      iconBadge: _PettyCashIconBadge(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BALANCE',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9CA3AF),
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Petty Cash',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Not authorized',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _PettyCashFullCardShell extends StatelessWidget {
  const _PettyCashFullCardShell({
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
      Color(0xFF3A3D45),
      Color(0xFF2A2D35),
      Color(0xFF1F2229),
      Color(0xFF181B22),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final innerRadius =
        (22.ur - CategoryWidgetGradientBorder.width).clamp(0.0, double.infinity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.ur),
        child: Container(
          height: height ?? double.infinity,
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
                clipBehavior: Clip.hardEdge,
                fit: StackFit.expand,
                children: [
                  if (pattern != null)
                    IgnorePointer(child: pattern!),
                  Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 12.uh, 46.w, 12.uh),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth,
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
  }
}

class _PettyCashIconBadge extends StatelessWidget {
  const _PettyCashIconBadge();

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
          colors: [Color(0xFF4ADE80), Color(0xFF22C55E)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        Icons.account_balance_wallet_rounded,
        size: 20.usp,
        color: Colors.white,
      ),
    );
  }
}

class _PettyCashStatColumn extends StatelessWidget {
  const _PettyCashStatColumn({
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
              fontSize: 9.usp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF9CA3AF),
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

class _PettyCashStatDivider extends StatelessWidget {
  const _PettyCashStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.uh),
      color: Colors.white.withValues(alpha: 0.14),
    );
  }
}

class _PettyCashRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width * 0.55, size.height * 0.45);
    canvas.drawCircle(center, size.width * 0.38, paint);
    canvas.drawCircle(center, size.width * 0.27, paint);
    canvas.drawCircle(center, size.width * 0.16, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

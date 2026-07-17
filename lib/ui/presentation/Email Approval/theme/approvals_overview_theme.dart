import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:ui';

import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/core/ui/device_ui_capability.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Visual tokens for the Waiting Approval overview (All tab).
class ApprovalsOverviewTheme {
  ApprovalsOverviewTheme._();

  static const Color screenDeep = Color(0xFF136B8D);
  static const Color screenMid = Color(0xFF198EBA);
  static const Color screenLight = Color(0xFF2D9ECA);

  /// Light periwinkle screen background (reference).
  static const Color screenBase = Color(0xFFF6F9FD);
  static const Color screenTintLight = Color(0xFFEEF3FB);
  static const Color screenTintMid = Color(0xFFE4ECF8);
  static const Color screenTintSoft = Color(0xFFDAE5F4);

  static const Color statCardWarm = Color(0xFFFCEAD0);
  static const Color statCardMint = Color(0xFFE2EDE7);

  /// Richer saturated tile backgrounds (glass overlay applied in widget).
  static const Color statCardRfq = Color(0xFFFFD966);
  static const Color statCardInvoice = Color(0xFFFFB899);
  static const Color statCardHr = Color(0xFFA8C4F5);
  static const Color statCardPettyCash = Color(0xFF8FD4AA);

  static const Color rorChartLine = Color(0xFF3B7DD8);
  static const Color rorChartFill = Color(0xFF3B7DD8);

  static Color statCardBackgroundFor(String id) {
    switch (id) {
      case 'rfq':
        return statCardRfq;
      case 'invoice':
        return statCardInvoice;
      case 'petty_cash':
        return statCardPettyCash;
      case 'hr':
      case 'hr_request':
        return statCardHr;
      default:
        return statCardWarm;
    }
  }

  static const Color white = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textSoft = Color(0xFF9CA3AF);
  static const Color textOnCyan = Color(0xFFFFFFFF);

  static const Color hr = Color(0xFFD21B2E);
  static const Color rfq = Color(0xFFBD9B2E);
  static const Color petty = Color(0xFF1A5C3A);
  static const Color invoice = Color(0xFFD4562A);

  static const LinearGradient screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      screenBase,
      screenTintLight,
      screenTintMid,
      screenTintSoft,
    ],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  static const SystemUiOverlayStyle overlay = SystemUiOverlayStyle(
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    statusBarColor: Colors.transparent,
  );

  static Color accentFor(String key) {
    switch (key) {
      case 'hr':
        return hr;
      case 'rfq':
        return rfq;
      case 'petty_cash':
        return petty;
      case 'invoice':
        return invoice;
      default:
        return textMuted;
    }
  }

  /// Soft top-left → bottom-right tile gradient (reference style).
  static LinearGradient statCardGradient(Color base) {
    final hsl = HSLColor.fromColor(base);
    final start = hsl
        .withSaturation((hsl.saturation * 1.12).clamp(0.0, 1.0))
        .withLightness((hsl.lightness * 0.94).clamp(0.0, 1.0))
        .toColor();
    final mid = Color.lerp(base, white, 0.38)!;
    final end = Color.lerp(base, white, 0.78)!;

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [start, mid, end],
      stops: const [0.0, 0.42, 1.0],
    );
  }

  /// Darker accent text derived from tile base (for subtitles).
  static Color statCardAccentText(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withSaturation((hsl.saturation * 1.25).clamp(0.0, 1.0))
        .withLightness((hsl.lightness * 0.52).clamp(0.0, 1.0))
        .toColor();
  }

  /// Short category badge shown on stat tiles (RFQ, INVOICE, …).
  static String statCardShortLabel(String id) {
    switch (id) {
      case 'rfq':
        return 'RFQ';
      case 'invoice':
        return 'INVOICE';
      case 'petty_cash':
        return 'PTSH';
      case 'hr':
      case 'hr_request':
        return 'HR';
      default:
        return id.toUpperCase();
    }
  }

  /// Faded background illustration per tile category (same assets as My Actions).
  static String? statCardBackgroundImage(String id) {
    switch (id) {
      case 'rfq':
        return 'assets/newapp/newicon/rfq.png';
      case 'invoice':
        return 'assets/newapp/newicon/Invoice.png';
      case 'petty_cash':
        return 'assets/newapp/newicon/Cash.png';
      case 'hr':
      case 'hr_request':
        return 'assets/newapp/newicon/hr.png';
      default:
        return null;
    }
  }

  /// Tint applied to the faded tile background illustration.
  static Color statCardIllustrationTint(String id) {
    switch (id) {
      case 'rfq':
        return rfq;
      case 'invoice':
        return invoice;
      case 'petty_cash':
        return petty;
      case 'hr':
      case 'hr_request':
        return hr;
      default:
        return screenDeep;
    }
  }

  /// Navy glass heading strip for the overview (Waiting for approvals).
  static const LinearGradient waitingHeadingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xE61E2365),
      Color(0xCC1A4F7A),
      Color(0xB3136B8D),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static BoxDecoration waitingHeadingDecoration({double radius = 22}) {
    return BoxDecoration(
      gradient: waitingHeadingGradient,
      borderRadius: BorderRadius.circular(radius.tr),
      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1E2365).withValues(alpha: 0.18),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static BoxDecoration whiteFadedGlass({
    double radius = 20,
    double fillAlpha = 0.82,
    double borderAlpha = 0.55,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius.tr),
      color: white.withValues(alpha: fillAlpha),
      border: Border.all(
        color: white.withValues(alpha: borderAlpha),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: screenDeep.withValues(alpha: 0.1),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

/// Frosted white panel — subtle fade (not heavy glass).
class OverviewGlassPanel extends StatelessWidget {
  const OverviewGlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.radius = 22,
    this.fillAlpha = 0.82,
    this.blurSigma = 8,
    this.borderAlpha = 0.55,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double fillAlpha;
  final double blurSigma;
  final double borderAlpha;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? EdgeInsets.all(14.tw),
      child: child,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius.tr),
      child: AdaptiveGlassLayer(
        borderRadius: BorderRadius.circular(radius.tr),
        sigma: blurSigma,
        fallbackColor: ApprovalsOverviewTheme.white
            .withValues(alpha: fillAlpha.clamp(0.75, 0.92)),
        fallbackBorder: Border.all(
          color: ApprovalsOverviewTheme.white.withValues(alpha: borderAlpha),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius.tr),
            child: Ink(
              decoration: ApprovalsOverviewTheme.whiteFadedGlass(
                radius: radius,
                fillAlpha: fillAlpha,
                borderAlpha: borderAlpha,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Top-right arrow on tiles (reference layout).
class OverviewArrowButton extends StatelessWidget {
  const OverviewArrowButton({super.key, this.onTap, this.size = 28});

  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size.tw,
        height: size.tw,
        decoration: BoxDecoration(
          color: ApprovalsOverviewTheme.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Icon(
          Icons.north_east_rounded,
          size: (size * 0.46).tsp,
          color: ApprovalsOverviewTheme.textDark,
        ),
      ),
    );
  }
}

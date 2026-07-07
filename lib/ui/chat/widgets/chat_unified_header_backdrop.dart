import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// One continuous grey → light glassy navy gradient for chat top chrome + merged header.
abstract final class ChatUnifiedHeaderBackdrop {
  /// Grey at top, soft light navy at bottom (no hard band stops).
  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFB4B9C2),
      Color(0xFF8E98A8),
      Color(0xFF6E7A92),
      Color(0xFF525E7A),
      Color(0xFF3D4768),
      Color(0xFF2C3560),
      Color(0xFF222B58),
      Color(0xFF1A2248),
      Color(0xFF161B54),
    ],
    stops: [0.0, 0.12, 0.28, 0.42, 0.55, 0.68, 0.8, 0.9, 1.0],
  );

  /// Frosted sheen on the lower (navy) portion.
  static const LinearGradient glassSheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0x33FFFFFF),
      Color(0x1AFFFFFF),
    ],
    stops: [0.35, 0.72, 1.0],
  );

  static LinearGradient tintedGradient(Color accent, {double strength = 0.44}) {
    Color blend(Color base, double amount) =>
        Color.lerp(base, accent, amount.clamp(0.0, 1.0))!;

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        blend(const Color(0xFFB4B9C2), strength),
        blend(const Color(0xFF8E98A8), strength * 0.95),
        blend(const Color(0xFF6E7A92), strength * 0.88),
        blend(const Color(0xFF525E7A), strength * 0.78),
        blend(const Color(0xFF3D4768), strength * 0.62),
        const Color(0xFF2C3560),
        const Color(0xFF222B58),
        const Color(0xFF1A2248),
        const Color(0xFF161B54),
      ],
      stops: gradient.stops,
    );
  }

  static Widget layer({BorderRadius? bottomRadius, Color? accentTint}) {
    final headerGradient =
        accentTint != null ? tintedGradient(accentTint) : gradient;

    return ClipRRect(
      borderRadius: bottomRadius ?? BorderRadius.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(gradient: headerGradient),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.68,
                child: Image.asset(
                  'assets/png/header_bg.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
              ),
            ),
          ),
          Positioned(
            top: -4.h,
            left: -12.w,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.52,
                child: Image.asset(
                  'assets/png/lines.png',
                  width: 240.w,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topLeft,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: -20.w,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.35,
                child: Image.asset(
                  'assets/png/lines.png',
                  width: 180.w,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topRight,
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: glassSheen)),
          ),
        ],
      ),
    );
  }
}

/// Message list + bubble colors aligned with [ChatUnifiedHeaderBackdrop].
abstract final class ChatSurfaceTheme {
  static const LinearGradient messageAreaGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF8F9FC),
      Color(0xFFEEF2FA),
      Color(0xFFE6EBF5),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient sentMessageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF161B54),
      Color(0xFF222B58),
      Color(0xFF2C3560),
      Color(0xFF3D4768),
    ],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  static const LinearGradient receivedMessageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF5F7FB),
      Color(0xFFEEF2FA),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const Color watermark = Color(0xFF8E98A8);
  static const Color dateChipFill = Color(0xFFE8ECF4);
  static const Color dateChipText = Color(0xFF525E7A);
  static const Color senderName = Color(0xFF6E7A92);
  static const Color receivedText = Color(0xFF1A2248);
  static const Color accentGold = Color(0xFFE9B23A);
}

/// Wraps logo bar + scroll header so one gradient runs through the full height.
class ChatListHeaderChrome extends StatelessWidget {
  const ChatListHeaderChrome({
    super.key,
    required this.topBar,
    required this.scrollContent,
  });

  final Widget topBar;
  final Widget scrollContent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ChatUnifiedHeaderBackdrop.layer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            topBar,
            Expanded(child: scrollContent),
          ],
        ),
      ],
    );
  }
}

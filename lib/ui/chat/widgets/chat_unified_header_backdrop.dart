import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Soft translucent wash so the blue geometric wallpaper reads through.
abstract final class ChatUnifiedHeaderBackdrop {
  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x660A1628),
      Color(0x440A1628),
      Color(0x220A1628),
      Color(0x00000000),
    ],
    stops: [0.0, 0.45, 0.8, 1.0],
  );

  static const LinearGradient glassSheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x33FFFFFF),
      Colors.transparent,
      Color(0x22A8D0F0),
    ],
    stops: [0.0, 0.4, 1.0],
  );

  static LinearGradient tintedGradient(Color accent, {double strength = 0.18}) {
    Color blend(Color base, double amount) =>
        Color.lerp(base, accent, amount.clamp(0.0, 1.0))!;

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        blend(const Color(0x660A1628), strength * 0.4),
        const Color(0x440A1628),
        blend(const Color(0x220A1628), strength),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 0.8, 1.0],
    );
  }

  static Widget layer({
    BorderRadius? bottomRadius,
    Color? accentTint,
    bool showLines = true,
  }) {
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
                opacity: 0.12,
                child: Image.asset(
                  'assets/png/header_bg.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
              ),
            ),
          ),
          if (showLines)
            Positioned(
              top: -4.h,
              left: -12.w,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.1,
                  child: Image.asset(
                    'assets/png/lines.png',
                    width: 240.w,
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topLeft,
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

/// Message list + bubble colors for glass chat on blue wallpaper.
abstract final class ChatSurfaceTheme {
  /// Transparent so [BlueGeometricBackground] shows through.
  static const LinearGradient messageAreaGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000),
      Color(0x140A1628),
      Color(0x220A1628),
    ],
    stops: [0.0, 0.6, 1.0],
  );

  static const LinearGradient sentMessageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x664A90C8),
      Color(0x553D7AB8),
      Color(0x442A6AA8),
      Color(0x331E5080),
    ],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  static const LinearGradient receivedMessageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x33FFFFFF),
      Color(0x22FFFFFF),
      Color(0x18FFFFFF),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const Color watermark = Color(0x55FFFFFF);
  static const Color dateChipFill = Color(0x33FFFFFF);
  static const Color dateChipText = Color(0xE6FFFFFF);
  static const Color senderName = Color(0xFFFFFFFF);
  static const Color receivedText = Color(0xFFFFFFFF);
  static const Color accentGold = Color(0xFFFFFFFF);
  static const Color sentBubbleBorder = Color(0x73FFFFFF);
  static const Color receivedBubbleBorder = Color(0x55FFFFFF);
}

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

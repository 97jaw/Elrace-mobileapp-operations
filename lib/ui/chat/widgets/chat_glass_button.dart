import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/ui/chat/theme/chat_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ChatGlassButtonVariant { gold, silver, frost }

/// Glassmorphism CTA used across chat screens.
class ChatGlassButton extends StatelessWidget {
  const ChatGlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ChatGlassButtonVariant.gold,
    this.icon,
    this.expand = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.fontSize = 15,
  });

  final String label;
  final VoidCallback? onPressed;
  final ChatGlassButtonVariant variant;
  final IconData? icon;
  final bool expand;
  final EdgeInsetsGeometry padding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(999);

    final Gradient? gradient = switch (variant) {
      ChatGlassButtonVariant.gold => ChatGlassTheme.goldButtonGradient,
      ChatGlassButtonVariant.silver => ChatGlassTheme.silverButtonGradient,
      ChatGlassButtonVariant.frost => null,
    };

    final textColor = switch (variant) {
      ChatGlassButtonVariant.gold => const Color(0xFF1A3A5C),
      ChatGlassButtonVariant.silver => const Color(0xFF1A3A5C),
      ChatGlassButtonVariant.frost => ChatGlassTheme.textPrimary,
    };

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: fontSize + 4, color: textColor),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: textColor,
            shadows: const [
              Shadow(
                color: Color(0x1A000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );

    Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: gradient,
            color: variant == ChatGlassButtonVariant.frost
                ? ChatGlassTheme.waterFillStrong
                : null,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (variant == ChatGlassButtonVariant.frost) {
      button = AdaptiveGlassLayer(
        borderRadius: radius,
        sigma: 14,
        fallbackColor: ChatGlassTheme.waterFillStrong,
        child: button,
      );
    } else {
      // Soft top highlight for metallic glass feel
      button = ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            button,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1.2,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.55),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

/// Circular frosted icon button (overflow, attach, etc.).
class ChatGlassIconButton extends StatelessWidget {
  const ChatGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 40,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    final btn = AdaptiveGlassLayer(
      borderRadius: radius,
      sigma: 12,
      fallbackColor: ChatGlassTheme.waterFillStrong,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Ink(
            width: size,
            height: size,
            decoration: ChatGlassTheme.glassDecoration(borderRadius: radius),
            child: Icon(
              icon,
              size: size * 0.48,
              color: iconColor ?? ChatGlassTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

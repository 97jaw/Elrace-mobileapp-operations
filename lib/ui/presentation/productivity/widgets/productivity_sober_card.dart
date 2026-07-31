import 'package:el_race/ui/presentation/productivity/theme/productivity_light_theme.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_light_widgets.dart';
import 'package:flutter/material.dart';

/// Sober list card — title+badge row, marquee overflow, taller progress.
class ProductivitySoberCard extends StatelessWidget {
  const ProductivitySoberCard({
    super.key,
    required this.title,
    required this.statusLabel,
    required this.statusBackground,
    this.subtitle,
    this.leadingAvatar,
    this.dateText,
    this.progress,
    this.titleTrailing,
    this.onTap,
  });

  final String title;
  final String statusLabel;
  final Color statusBackground;
  final String? subtitle;
  final Widget? leadingAvatar;
  final String? dateText;
  final double? progress;
  final Widget? titleTrailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const radius = ProductivityLightTheme.boxRadius;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Ink(
            decoration: BoxDecoration(
              color: ProductivityLightTheme.card,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _SlowMarqueeText(
                          text: title,
                          style: ProductivityLightTheme.cardTitle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ProductivityStatusPill(
                        label: statusLabel,
                        background: statusBackground,
                      ),
                      if (titleTrailing != null) ...[
                        const SizedBox(width: 4),
                        titleTrailing!,
                      ],
                    ],
                  ),
                  if ((subtitle != null && subtitle!.isNotEmpty) ||
                      leadingAvatar != null ||
                      (dateText != null && dateText!.isNotEmpty)) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (leadingAvatar != null) ...[
                          leadingAvatar!,
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            (subtitle != null && subtitle!.isNotEmpty)
                                ? subtitle!
                                : 'Unassigned',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ProductivityLightTheme.cardSubtitle,
                          ),
                        ),
                        if (dateText != null && dateText!.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: ProductivityLightTheme.inkMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            dateText!,
                            style: ProductivityLightTheme.cardMeta,
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (progress != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'Progress',
                          style: ProductivityLightTheme.cardSubtitle,
                        ),
                        const Spacer(),
                        Text(
                          '${(progress!.clamp(0.0, 1.0) * 100).round()}%',
                          style: ProductivityLightTheme.cardSubtitle.copyWith(
                            color: ProductivityLightTheme.ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _StripedProgressBar(value: progress!.clamp(0.0, 1.0)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slow horizontal slide when [text] exceeds one line of available width.
class _SlowMarqueeText extends StatefulWidget {
  const _SlowMarqueeText({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  State<_SlowMarqueeText> createState() => _SlowMarqueeTextState();
}

class _SlowMarqueeTextState extends State<_SlowMarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _overflow = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant _SlowMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _overflow = 0;
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _configure(double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final overflow = (painter.width - maxWidth).clamp(0.0, double.infinity);
    if ((overflow - _overflow).abs() < 0.5) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _overflow = overflow);
      if (overflow <= 0) {
        _controller.stop();
        _controller.value = 0;
        return;
      }

      // ~28px/sec — slow readable slide, ping-pong.
      final seconds = (overflow / 28).clamp(4.0, 14.0);
      _controller.duration = Duration(milliseconds: (seconds * 1000).round());
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _configure(constraints.maxWidth);
        return ClipRect(
          child: SizedBox(
            height: (widget.style.fontSize ?? 18) * (widget.style.height ?? 1.25),
            width: constraints.maxWidth,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final dx = _overflow <= 0 ? 0.0 : -_overflow * _controller.value;
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: child,
                );
              },
              child: Text(
                widget.text,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: widget.style,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// High-contrast teal striped progress with a marker.
class _StripedProgressBar extends StatelessWidget {
  const _StripedProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final fillWidth = width * value;
          final markerLeft = (fillWidth - 1.5).clamp(0.0, width - 3);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 6,
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: ProductivityLightTheme.progressTrack,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: const Color(0xFFD1D5DB),
                      width: 1,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    width: fillWidth,
                    height: 18,
                    child: CustomPaint(
                      painter: _DiagonalStripePainter(
                        color: ProductivityLightTheme.progressStripe,
                        background: ProductivityLightTheme.progressFillSoft,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: markerLeft,
                top: 2,
                child: Column(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: ProductivityLightTheme.progressFill,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2.5,
                      height: 20,
                      color: ProductivityLightTheme.progressFill,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DiagonalStripePainter extends CustomPainter {
  _DiagonalStripePainter({
    required this.color,
    required this.background,
  });

  final Color color;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = background,
    );

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    const spacing = 7.0;
    final extent = size.width + size.height;
    for (double i = -size.height; i < extent; i += spacing) {
      canvas.drawLine(
        Offset(i, size.height),
        Offset(i + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiagonalStripePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.background != background;
}

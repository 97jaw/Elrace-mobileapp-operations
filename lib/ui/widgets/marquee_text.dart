import 'package:flutter/material.dart';

/// Single-line text that stays still when it fits, and scrolls slowly with a
/// pause at each end when it overflows.
class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.textDirection,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle style;
  final TextDirection? textDirection;
  final TextAlign textAlign;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _overflow = 0;
  int _runId = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _overflow = -1;
    }
  }

  @override
  void dispose() {
    _runId++;
    _controller.dispose();
    super.dispose();
  }

  void _measure(BoxConstraints constraints) {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: widget.textDirection ?? Directionality.of(context),
    )..layout();
    final overflow = (painter.width - constraints.maxWidth).clamp(0.0, 9999.0);
    if ((overflow - _overflow).abs() <= 0.5) return;
    _overflow = overflow;
    final runId = ++_runId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || runId != _runId) return;
      if (_overflow > 0) {
        final secs = (6 + _overflow / 28).clamp(6, 16).toInt();
        _controller.duration = Duration(seconds: secs);
        _loop(runId);
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    });
  }

  Future<void> _loop(int runId) async {
    while (mounted && runId == _runId && _overflow > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted || runId != _runId || _overflow <= 0) return;
      await _controller.forward(from: 0);
      if (!mounted || runId != _runId || _overflow <= 0) return;
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted || runId != _runId || _overflow <= 0) return;
      await _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _measure(constraints);
        return ClipRect(
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
              textDirection: widget.textDirection,
              textAlign: widget.textAlign,
              style: widget.style,
            ),
          ),
        );
      },
    );
  }
}

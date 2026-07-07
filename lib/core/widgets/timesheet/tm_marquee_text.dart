import 'package:flutter/material.dart';

/// Horizontal marquee for long project titles (medium speed).
class TmMarqueeText extends StatefulWidget {
  const TmMarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.height = 22,
  });

  final String text;
  final TextStyle style;
  final double height;

  @override
  State<TmMarqueeText> createState() => _TmMarqueeTextState();
}

class _TmMarqueeTextState extends State<TmMarqueeText> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loop());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loop() async {
    if (!mounted || !_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    if (max <= 0) return;
    while (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (!mounted || !_controller.hasClients) return;
      await _controller.animateTo(
        max,
        duration: Duration(
          milliseconds: (widget.text.length * 140).clamp(6000, 16000),
        ),
        curve: Curves.linear,
      );
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted || !_controller.hasClients) return;
      _controller.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRect(
        child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          children: [
            Text(widget.text, style: widget.style, maxLines: 1),
            const SizedBox(width: 40),
            Text(widget.text, style: widget.style, maxLines: 1),
          ],
        ),
        ),
      ),
    );
  }
}

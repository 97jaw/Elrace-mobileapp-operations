import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single-line title with slow horizontal slide when text overflows.
class ProjectDocumentsOneLineMarquee extends StatefulWidget {
  const ProjectDocumentsOneLineMarquee({
    super.key,
    required this.text,
    this.fontSize,
    this.fontWeight = FontWeight.w500,
    this.italic = true,
    this.color,
    this.lineHeight = 1.2,
  });

  final String text;
  final double? fontSize;
  final FontWeight fontWeight;
  final bool italic;
  final Color? color;
  final double lineHeight;

  @override
  State<ProjectDocumentsOneLineMarquee> createState() =>
      _ProjectDocumentsOneLineMarqueeState();
}

class _ProjectDocumentsOneLineMarqueeState
    extends State<ProjectDocumentsOneLineMarquee>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool _marquee = false;
  double _overflow = 0;
  double _lastWidth = 0;

  TextStyle get _style => GoogleFonts.poppins(
        fontSize: widget.fontSize ?? 14.tsp,
        fontStyle: widget.italic ? FontStyle.italic : FontStyle.normal,
        fontWeight: widget.fontWeight,
        color: widget.color ?? ProjectsDashboardTheme.greyDeep,
        height: widget.lineHeight,
      );

  double get _lineHeightPx => (widget.fontSize ?? 14.tsp) * widget.lineHeight;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _evaluate(double maxWidth) {
    if (maxWidth <= 0 || maxWidth == _lastWidth) return;
    _lastWidth = maxWidth;

    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: _style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    final needsMarquee = painter.didExceedMaxLines;
    if (needsMarquee == _marquee && (_controller != null) == needsMarquee) return;

    _controller?.dispose();
    _controller = null;
    _marquee = needsMarquee;

    if (needsMarquee) {
      final full = TextPainter(
        text: TextSpan(text: widget.text, style: _style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: double.infinity);
      _overflow = (full.width - maxWidth + 24.tw).clamp(0, double.infinity);
      _controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: (9000 + _overflow * 12).round()),
      )..repeat();
    }

    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ProjectDocumentsOneLineMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _lastWidth = 0;
      _marquee = false;
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _evaluate(constraints.maxWidth);
        });

        if (_marquee && _controller != null) {
          return SizedBox(
            height: _lineHeightPx,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _controller!,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(-_overflow * _controller!.value, 0),
                      child: child,
                    );
                  },
                  child: Text(widget.text, maxLines: 1, style: _style),
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: _lineHeightPx,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _style,
            ),
          ),
        );
      },
    );
  }
}

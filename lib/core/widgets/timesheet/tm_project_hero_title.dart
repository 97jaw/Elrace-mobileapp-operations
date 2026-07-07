import 'package:el_race/core/widgets/timesheet/tm_marquee_text.dart';
import 'package:flutter/material.dart';

/// Hero title: first line centered; overflow on a second sliding line.
class TmProjectHeroTitle extends StatelessWidget {
  const TmProjectHeroTitle({
    super.key,
    required this.text,
    required this.style,
    this.maxHeight = 56,
  });

  final String text;
  final TextStyle style;
  final double maxHeight;

  static (String, String?) splitLines(String raw) {
    final trimmed = raw.trim();
    if (trimmed.length <= 32) return (trimmed, null);

    final mid = trimmed.length ~/ 2;
    var splitAt = trimmed.lastIndexOf(' ', mid);
    if (splitAt < 12) {
      splitAt = trimmed.indexOf(' ', mid);
    }
    if (splitAt < 0) splitAt = mid;

    final line1 = trimmed.substring(0, splitAt).trim();
    var line2 = trimmed.substring(splitAt).trim();
    if (line1.isEmpty) return (trimmed, null);
    if (line2.isEmpty) return (line1, null);
    return (line1, line2);
  }

  @override
  Widget build(BuildContext context) {
    final (line1, line2) = splitLines(text);

    return SizedBox(
      height: maxHeight,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            line1,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
          if (line2 != null) ...[
            const SizedBox(height: 4),
            TmMarqueeText(
              text: line2,
              height: 20,
              style: style.copyWith(fontSize: (style.fontSize ?? 24) * 0.92),
            ),
          ],
        ],
      ),
    );
  }
}

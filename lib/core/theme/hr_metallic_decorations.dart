import 'package:flutter/material.dart';

/// Light “brushed metal” surfaces for HR Requests KPI tiles and list cards.
abstract final class HrMetallicDecorations {
  /// KPI counter — soft gradient + pearl edge from a status tint.
  static BoxDecoration kpiTile({
    required Color statusTint,
    double borderRadius = 12,
  }) {
    final top = Color.lerp(statusTint, Colors.white, 0.72)!;
    final bottom = Color.lerp(statusTint, const Color(0xFFD5DEE6), 0.45)!;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [top, bottom],
      ),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.88),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF5C6B7A).withValues(alpha: 0.12),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Request list row — silver base kissed by status hue.
  static BoxDecoration requestCard({
    required Color statusAccent,
    double borderRadius = 12,
  }) {
    final top = Color.lerp(statusAccent, const Color(0xFFF5F7FA), 0.88)!;
    final bottom = Color.lerp(statusAccent, const Color(0xFFE1E6EC), 0.78)!;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [top, bottom],
      ),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.82),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.055),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}

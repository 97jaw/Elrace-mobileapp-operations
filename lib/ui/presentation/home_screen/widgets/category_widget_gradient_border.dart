import 'package:flutter/material.dart';

/// Thin white-dominant → soft grey gradient rim for home category widget cards.
class CategoryWidgetGradientBorder {
  CategoryWidgetGradientBorder._();

  static const double width = 1;

  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF8F9FB),
      Color(0xFFD0D4DC),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const List<BoxShadow> defaultShadow = [
    BoxShadow(
      color: Color(0x14293D61),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static BoxDecoration outer({
    required double borderRadius,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: gradient,
      boxShadow: boxShadow ?? defaultShadow,
    );
  }

  static BoxDecoration inner({
    required double borderRadius,
    Gradient? fillGradient,
    Color? fillColor,
  }) {
    final innerRadius = (borderRadius - width).clamp(0.0, double.infinity);
    return BoxDecoration(
      borderRadius: BorderRadius.circular(innerRadius),
      gradient: fillGradient,
      color: fillColor,
    );
  }

  static EdgeInsets get padding => const EdgeInsets.all(width);
}

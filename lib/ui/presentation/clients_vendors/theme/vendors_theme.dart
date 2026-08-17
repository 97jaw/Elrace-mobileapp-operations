import 'package:flutter/material.dart';

/// Vendors palette — charcoal screen shell + light metallic KPI cards.
///
/// Screen: `#464648`, `#5D5D5F`, `#636365`, `#9BA1B5`
/// KPI cards: `#BAB9BD`, `#DBDBDD` · icons: `#4C8DA8`, `#4EA2B4`, `#384A4F`
class VendorsTheme {
  VendorsTheme._();

  static const deepLight = Color(0xFF636365);
  static const deepMid = Color(0xFF5D5D5F);
  static const deepDark = Color(0xFF464648);

  static const glowBright = Color(0xFF9BA1B5);
  static const glowMid = Color(0xFF8A90A3);
  static const glowSoft = Color(0xFF7A808F);
  static const glowEdge = Color(0xFF5D5D5F);

  static const kpiGradientTop = Color(0xFFDBDBDD);
  static const kpiGradientBottom = Color(0xFFBAB9BD);

  static const iconPurchases = Color(0xFF4C8DA8);
  static const iconPaid = Color(0xFF4EA2B4);
  static const iconPayables = Color(0xFF384A4F);
  static const iconActive = Color(0xFF3D9A6A);
  static const iconExpiring = Color(0xFFD69E2E);
  static const iconContracts = Color(0xFF4C8DA8);

  static const electricBorder = Color(0xFF4EA2B4);

  static const kpiTitle = Color(0xFF384A4F);
  static const kpiValue = Color(0xFF384A4F);
  static const kpiMuted = Color(0xFF4C8DA8);

  static const chartBg = Color(0xFF464648);
  static const chartLine = Color(0xFFDBDBDD);
  static const chartAxis = Color(0xFF9BA1B5);
  static const chartPeak = Color(0xFF4C8DA8);
  static const chartHighlight = Color(0xFF4EA2B4);
  static const chartTitle = Color(0xFF384A4F);

  static Color lightBar(Color icon) =>
      Color.lerp(icon, kpiGradientTop, 0.42) ?? icon;

  static const iconAccent = Color(0xFF9BA1B5);
  static const vignette = Color(0x66000000);
}

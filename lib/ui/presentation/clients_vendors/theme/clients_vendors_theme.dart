import 'package:flutter/material.dart';

/// Shared palette for Client & Vendors screens — keep subsequent screens
/// on these same colors.
class ClientsVendorsTheme {
  ClientsVendorsTheme._();

  // Screen background (deep navy tier).
  static const deepLight = Color(0xFF014894);
  static const deepMid = Color(0xFF024790);
  static const deepDark = Color(0xFF03468C);

  // Glow accents.
  static const glowBright = Color(0xFF12A5F5);
  static const glowMid = Color(0xFF0A95E3);
  static const glowSoft = Color(0xFF2A99F0);
  static const glowEdge = Color(0xFF085CA8);

  // Feature / chart card gradients.
  static const cardGradientTop = Color(0xFF0659A3);
  static const cardGradientBottom = Color(0xFF002760);
  static const cardGradientTopAlt = Color(0xFF0D71BF);
  static const cardGradientBottomAlt = Color(0xFF023F80);

  // Chart / metric surfaces (from reference screenshot).
  static const chartPanel = Color(0xFF0A3A6E);
  static const metricPill = Color(0xFF1A4A7A);
  static const chartLine = Colors.white;
  static const chartArea = Color(0x66FFFFFF);
  static const tooltipBg = Color(0xFF1E293B);
  static const axisLabel = Color(0xB3FFFFFF);

  // Metric tile accent colors (spec).
  static const amountDueOverdue = Color(0xFFE53E3E);
  static const amountDueOpen = Color(0xFFED8936);
  static const amountPaid = Color(0xFF3B82F6);

  static const iconAccent = Color(0xFF3CC6FC);
}

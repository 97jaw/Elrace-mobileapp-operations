import 'package:flutter/material.dart';

abstract final class ElraceAiTheme {
  static const electricLavender = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEDE9FE), Color(0xFFC4B5FD), Color(0xFF9F7AEA)],
  );

  static const aqua = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE0F7FA), Color(0xFF67E8F9), Color(0xFF06B6D4)],
  );

  static const blackberry = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F0A2E), Color(0xFF4C1D95), Color(0xFF7C3AED)],
  );

  static const blueFrost = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0F9FF), Color(0xFFBAE6FD), Color(0xFF7DD3FC)],
  );

  static const ghostPurple = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5F3FF), Color(0xFFDDD6FE), Color(0xFFA78BFA)],
  );

  static const rosewood = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF1F2), Color(0xFFFDA4AF), Color(0xFFBE123C)],
  );

  static const accentPurple = Color(0xFF7C3AED);
  static const accentDeep = Color(0xFF5B21B6);
  static const textPrimary = Color(0xFF1E3A5F);
  static const textSecondary = Color(0xFF5B7A9A);
  static const textMuted = Color(0xFF8FA8C0);
}

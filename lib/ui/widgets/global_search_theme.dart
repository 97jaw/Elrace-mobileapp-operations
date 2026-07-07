import 'package:flutter/material.dart';

/// Brand palette: maroon, navy, grey, white, green.
abstract final class GlobalSearchTheme {
  static const Color maroon = Color(0xFF8B1A2B);
  static const Color maroonDark = Color(0xFF6E1522);
  static const Color navy = Color(0xFF161B54);
  static const Color navyMid = Color(0xFF1A2248);
  static const Color grey = Color(0xFF6B7280);
  static const Color greyLight = Color(0xFFADB2BD);
  static const Color green = Color(0xFF2D6B52);
  static const Color greenBright = Color(0xFF059669);
  static const Color white = Color(0xFFFFFFFF);

  static const Color screenBase = navy;

  static const LinearGradient searchBarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF8FAFC),
      Color(0xFFE8ECF2),
      Color(0xFFD6DCE6),
    ],
  );

  /// Search field on light gradient bar.
  static const Color searchInputText = Color(0xFF161B54);
  static const Color searchHintText = Color(0xFF475569);

  static const Color onGlassMuted = Color(0xB3FFFFFF);
  static const Color sectionHeader = Color(0xF2FFFFFF);

  /// Text on faded glass cards (over navy screen).
  static const Color cardTitle = white;
  static const Color cardSubtitle = Color(0xFFD6DCE6);
  static const Color cardBody = Color(0xFFF1F5F9);
  static const Color cardMeta = greyLight;
  static const Color cardDetailValue = Color(0xFFE2E8F0);

  static const double backgroundIconOpacity = 0.17;

  static Color accentFor(String category) {
    switch (category) {
      case 'lpo':
        return maroon;
      case 'petty_cash':
        return greenBright;
      case 'projects':
        return navyMid;
      case 'my_actions':
        return maroonDark;
      case 'notes':
        return grey;
      case 'documents':
        return greyLight;
      case 'tasks':
        return green;
      default:
        return grey;
    }
  }

  /// Faded glass card fill (less transparent than before).
  static Color cardFillFor(String category) {
    return white.withValues(alpha: 0.2);
  }

  static Color cardBorderFor(String category) {
    return accentFor(category).withValues(alpha: 0.42);
  }

  /// Large watermark icon — category color, faded.
  static Color watermarkIconFor(String category) {
    if (category == 'projects') {
      return greyLight.withValues(alpha: 0.22);
    }
    if (category == 'documents') {
      return grey.withValues(alpha: backgroundIconOpacity + 0.03);
    }
    return accentFor(category).withValues(alpha: backgroundIconOpacity);
  }

  static Color detailIconColor(String category, {int index = 0}) {
    const cycle = [maroon, navyMid, green, greyLight, greenBright, maroonDark];
    return cycle[index % cycle.length];
  }

  static IconData iconFor(String category) {
    switch (category) {
      case 'lpo':
        return Icons.receipt_long_rounded;
      case 'petty_cash':
        return Icons.account_balance_wallet_rounded;
      case 'projects':
        return Icons.apartment_rounded;
      case 'my_actions':
        return Icons.fact_check_rounded;
      case 'notes':
        return Icons.sticky_note_2_rounded;
      case 'documents':
        return Icons.folder_copy_rounded;
      case 'tasks':
        return Icons.task_alt_rounded;
      default:
        return Icons.search_rounded;
    }
  }

  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'done':
        return greenBright;
      case 'rejected':
      case 'cancelled':
      case 'canceled':
        return maroon;
      default:
        return greyLight;
    }
  }
}

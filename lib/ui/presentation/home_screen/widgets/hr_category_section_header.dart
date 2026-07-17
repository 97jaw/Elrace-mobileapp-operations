import 'package:el_race/ui/presentation/home_screen/widgets/home_category_section_header.dart';
import 'package:flutter/material.dart';

/// Human Resource section row — icon + title only.
class HrCategorySectionHeader extends StatelessWidget {
  const HrCategorySectionHeader({
    super.key,
    this.compact = false,
  });

  /// Peek state: smaller icon, short label to save vertical space for cards.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return HomeCategorySectionHeader(
      title: 'Human Resource',
      icon: Icons.person_outline_rounded,
      iconColor: const Color(0xFFE63946),
      compact: compact,
    );
  }
}

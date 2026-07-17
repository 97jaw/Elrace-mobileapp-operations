import 'package:el_race/ui/presentation/home_screen/widgets/home_category_section_header.dart';
import 'package:flutter/material.dart';

/// Finance section row — icon + title.
class FinanceCategorySectionHeader extends StatelessWidget {
  const FinanceCategorySectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeCategorySectionHeader(
      title: 'Finance',
      icon: Icons.show_chart_rounded,
      iconColor: Color(0xFF2A2D35),
    );
  }
}

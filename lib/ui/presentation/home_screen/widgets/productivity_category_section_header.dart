import 'package:el_race/ui/presentation/home_screen/widgets/home_category_section_header.dart';
import 'package:flutter/material.dart';

/// Productivity section row — icon + title.
class ProductivityCategorySectionHeader extends StatelessWidget {
  const ProductivityCategorySectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeCategorySectionHeader(
      title: 'Productivity',
      icon: Icons.task_alt_rounded,
      iconColor: Color(0xFF2D7FF0),
    );
  }
}

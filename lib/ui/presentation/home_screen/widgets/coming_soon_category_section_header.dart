import 'package:el_race/ui/presentation/home_screen/widgets/home_category_section_header.dart';
import 'package:flutter/material.dart';

class ComingSoonCategorySectionHeader extends StatelessWidget {
  const ComingSoonCategorySectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeCategorySectionHeader(
      title: 'Coming soon',
      icon: Icons.auto_awesome_rounded,
      iconColor: Color(0xFF7C3AED),
      iconGradient: LinearGradient(
        colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
      ),
    );
  }
}

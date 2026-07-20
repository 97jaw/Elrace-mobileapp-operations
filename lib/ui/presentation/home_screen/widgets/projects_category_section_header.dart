import 'package:el_race/ui/presentation/home_screen/widgets/home_category_section_header.dart';
import 'package:flutter/material.dart';

/// Projects section row — icon + title only.
class ProjectsCategorySectionHeader extends StatelessWidget {
  const ProjectsCategorySectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeCategorySectionHeader(
      title: 'Projects',
      icon: Icons.apartment_rounded,
      iconColor: Color(0xFF1A2A4F),
    );
  }
}

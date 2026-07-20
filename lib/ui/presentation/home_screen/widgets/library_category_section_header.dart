import 'package:el_race/ui/presentation/home_screen/widgets/home_category_section_header.dart';
import 'package:flutter/material.dart';

/// Library section row — icon + title.
class LibraryCategorySectionHeader extends StatelessWidget {
  const LibraryCategorySectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeCategorySectionHeader(
      title: 'Library',
      icon: Icons.folder_copy_outlined,
      iconColor: Color(0xFF6B7A94),
    );
  }
}

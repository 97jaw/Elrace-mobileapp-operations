import 'package:el_race/ui/presentation/home_screen/widgets/home_category_section_header.dart';
import 'package:flutter/material.dart';

/// Purchase section row — icon + title only.
class PurchaseCategorySectionHeader extends StatelessWidget {
  const PurchaseCategorySectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeCategorySectionHeader(
      title: 'Purchase',
      icon: Icons.receipt_long_rounded,
      iconColor: Color(0xFF1E2A4A),
    );
  }
}

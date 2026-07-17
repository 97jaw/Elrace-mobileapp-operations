import 'package:el_race/ui/presentation/home_screen/widgets/home_category_section_header.dart';
import 'package:flutter/material.dart';

/// Clients & Vendors section row — icon + title only.
class ClientsVendorsCategorySectionHeader extends StatelessWidget {
  const ClientsVendorsCategorySectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeCategorySectionHeader(
      title: 'Clients & Vendors',
      icon: Icons.handshake_rounded,
      iconColor: Color(0xFF003D4E),
    );
  }
}

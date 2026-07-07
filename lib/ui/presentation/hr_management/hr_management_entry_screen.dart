import 'package:el_race/ui/presentation/hr_management/hr_management_hub_screen.dart';
import 'package:flutter/material.dart';

/// Opens the HR Management **hub** (module picker). Individual modules push their own stacks.
class HrManagementEntryScreen extends StatelessWidget {
  const HrManagementEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HrManagementHubScreen();
  }
}

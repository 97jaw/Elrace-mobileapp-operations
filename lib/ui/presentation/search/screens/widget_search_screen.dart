import 'package:el_race/ui/widgets/global_search_screen.dart';
import 'package:flutter/material.dart';

/// Legacy route wrapper — redirects to unified global search.
@Deprecated('Use GlobalSearchScreen directly')
class WidgetSearchScreen extends StatelessWidget {
  const WidgetSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const GlobalSearchScreen();
  }
}

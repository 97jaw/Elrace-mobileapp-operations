import 'package:el_race/ui/presentation/my_actions/theme/my_actions_module_theme.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_landing_scaffold.dart';
import 'package:flutter/material.dart';

class SignaturesScreen extends StatelessWidget {
  const SignaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MyActionsLandingScaffold(
      module: MyActionsModule.signature,
      items: const [],
      loading: false,
      onRefresh: () async {},
      onRetry: () {},
      onItemTap: (_) {},
      filter: MyActionFilter.all,
      onFilterChanged: (_) {},
      onShowAll: () {},
      underPlanning: true,
      planningMessage:
          'Signature actions are under planning.\nWe\'re preparing a unified experience — check back soon.',
    );
  }
}

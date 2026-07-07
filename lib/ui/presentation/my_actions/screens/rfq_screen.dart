import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/theme/my_actions_module_theme.dart';
import 'package:el_race/ui/presentation/my_actions/utils/my_actions_detail_navigation.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_landing_scaffold.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_pagination_mixin.dart';
import 'package:flutter/material.dart';

class RfqScreen extends StatefulWidget {
  const RfqScreen({super.key});

  @override
  State<RfqScreen> createState() => _RfqScreenState();
}

class _RfqScreenState extends State<RfqScreen>
    with MyActionsPaginationMixin<RfqScreen> {
  MyActionFilter _filter = MyActionFilter.all;

  @override
  MyActionsType get actionsType => MyActionsType.rfq;

  @override
  void initState() {
    super.initState();
    initActionsPagination();
  }

  @override
  void dispose() {
    disposeActionsPagination();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MyActionsLandingScaffold(
      module: MyActionsModule.rfq,
      items: actionItems,
      loading: actionsInitialLoading,
      error: actionsError,
      onRefresh: refreshActions,
      onRetry: retryInitialActionsLoad,
      onItemTap: (item) =>
          MyActionsDetailNavigation.open(context, MyActionsModule.rfq, item),
      filter: _filter,
      onFilterChanged: (f) => setState(() => _filter = f),
      subtitleBuilder: MyActionsDetailNavigation.rfqSubtitle,
      onShowAll: () => showMyActionsAllSheet(
        context: context,
        module: MyActionsModule.rfq,
        filter: _filter,
        onItemTap: (item) =>
            MyActionsDetailNavigation.open(context, MyActionsModule.rfq, item),
        subtitleBuilder: MyActionsDetailNavigation.rfqSubtitle,
      ),
    );
  }
}

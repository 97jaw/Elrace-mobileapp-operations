import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/theme/my_actions_module_theme.dart';
import 'package:el_race/ui/presentation/my_actions/utils/my_actions_detail_navigation.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_landing_scaffold.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_pagination_mixin.dart';
import 'package:flutter/material.dart';

class PettyCashMyActionScreen extends StatefulWidget {
  const PettyCashMyActionScreen({super.key});

  @override
  State<PettyCashMyActionScreen> createState() =>
      _PettyCashMyActionScreenState();
}

class _PettyCashMyActionScreenState extends State<PettyCashMyActionScreen>
    with MyActionsPaginationMixin<PettyCashMyActionScreen> {
  MyActionFilter _filter = MyActionFilter.all;

  @override
  MyActionsType get actionsType => MyActionsType.ptsh;

  void _onItemTap(MyActionItem item) {
    MyActionsDetailNavigation.showPreview(
      context,
      MyActionsModule.pettyCash,
      item,
    );
  }

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
      module: MyActionsModule.pettyCash,
      items: actionItems,
      loading: actionsInitialLoading,
      error: actionsError,
      onRefresh: refreshActions,
      onRetry: retryInitialActionsLoad,
      onItemTap: _onItemTap,
      filter: _filter,
      onFilterChanged: (f) => setState(() => _filter = f),
      subtitleBuilder: MyActionsDetailNavigation.pettyCashSubtitle,
      onShowAll: () => showMyActionsAllSheet(
        context: context,
        module: MyActionsModule.pettyCash,
        filter: _filter,
        onItemTap: _onItemTap,
        subtitleBuilder: MyActionsDetailNavigation.pettyCashSubtitle,
      ),
    );
  }
}

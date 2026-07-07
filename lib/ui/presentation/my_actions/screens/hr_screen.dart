import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/theme/my_actions_module_theme.dart';
import 'package:el_race/ui/presentation/my_actions/utils/my_actions_detail_navigation.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_landing_scaffold.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_pagination_mixin.dart';
import 'package:flutter/material.dart';

class HrScreen extends StatefulWidget {
  const HrScreen({super.key});

  @override
  State<HrScreen> createState() => _HrScreenState();
}

class _HrScreenState extends State<HrScreen>
    with MyActionsPaginationMixin<HrScreen> {
  MyActionFilter _filter = MyActionFilter.all;

  @override
  MyActionsType get actionsType => MyActionsType.hr;

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

  void _openDetail(MyActionItem item) {
    MyActionsDetailNavigation.open(context, MyActionsModule.hr, item);
  }

  @override
  Widget build(BuildContext context) {
    return MyActionsLandingScaffold(
      module: MyActionsModule.hr,
      items: actionItems,
      loading: actionsInitialLoading,
      error: actionsError,
      onRefresh: refreshActions,
      onRetry: retryInitialActionsLoad,
      onItemTap: _openDetail,
      filter: _filter,
      onFilterChanged: (f) => setState(() => _filter = f),
      onShowAll: () => showMyActionsAllSheet(
        context: context,
        module: MyActionsModule.hr,
        filter: _filter,
        onItemTap: _openDetail,
      ),
    );
  }
}

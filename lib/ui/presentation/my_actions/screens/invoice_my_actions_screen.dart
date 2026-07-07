import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/theme/my_actions_module_theme.dart';
import 'package:el_race/ui/presentation/my_actions/utils/my_actions_detail_navigation.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_landing_scaffold.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_pagination_mixin.dart';
import 'package:flutter/material.dart';

class InvoiceMyActionsScreen extends StatefulWidget {
  const InvoiceMyActionsScreen({super.key});

  @override
  State<InvoiceMyActionsScreen> createState() => _InvoiceMyActionsScreenState();
}

class _InvoiceMyActionsScreenState extends State<InvoiceMyActionsScreen>
    with MyActionsPaginationMixin<InvoiceMyActionsScreen> {
  MyActionFilter _filter = MyActionFilter.all;

  @override
  MyActionsType get actionsType => MyActionsType.invoice;

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
      module: MyActionsModule.invoice,
      items: actionItems,
      loading: actionsInitialLoading,
      error: actionsError,
      onRefresh: refreshActions,
      onRetry: retryInitialActionsLoad,
      onItemTap: (item) =>
          MyActionsDetailNavigation.open(context, MyActionsModule.invoice, item),
      filter: _filter,
      onFilterChanged: (f) => setState(() => _filter = f),
      subtitleBuilder: MyActionsDetailNavigation.invoiceSubtitle,
      onShowAll: () => showMyActionsAllSheet(
        context: context,
        module: MyActionsModule.invoice,
        filter: _filter,
        onItemTap: (item) => MyActionsDetailNavigation.open(
          context,
          MyActionsModule.invoice,
          item,
        ),
        subtitleBuilder: MyActionsDetailNavigation.invoiceSubtitle,
      ),
    );
  }
}

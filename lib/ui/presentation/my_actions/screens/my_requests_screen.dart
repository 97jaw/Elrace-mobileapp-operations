import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/data/my_actions_repository.dart';
import 'package:el_race/ui/presentation/my_actions/theme/my_actions_module_theme.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_landing_scaffold.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_actions_local_all_sheet.dart';
import 'package:flutter/material.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final MyActionsRepository _repo = MyActionsRepository();
  MyActionFilter _filter = MyActionFilter.all;
  bool _loading = true;
  Object? _error;
  List<MyActionItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.fetchMyRequests();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MyActionsLandingScaffold(
      module: MyActionsModule.myRequests,
      items: _items,
      loading: _loading,
      error: _error,
      onRefresh: _load,
      onRetry: _load,
      onItemTap: (_) {},
      filter: _filter,
      onFilterChanged: (f) => setState(() => _filter = f),
      onShowAll: () => MyActionsLocalAllSheet.show(
        context,
        module: MyActionsModule.myRequests,
        items: _items,
        initialFilter: _filter,
        onItemTap: (_) {},
      ),
    );
  }
}

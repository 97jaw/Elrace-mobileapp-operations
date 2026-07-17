import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:async';

import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/data/my_actions_repository.dart';
import 'package:el_race/ui/presentation/my_actions/theme/my_actions_module_theme.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_action_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class MyActionsAllSheet extends StatefulWidget {
  const MyActionsAllSheet({
    super.key,
    required this.theme,
    required this.actionsType,
    required this.onItemTap,
    required this.initialFilter,
    this.subtitleBuilder,
  });

  final MyActionsModuleTheme theme;
  final MyActionsType actionsType;
  final void Function(MyActionItem item) onItemTap;
  final MyActionFilter initialFilter;
  final String? Function(MyActionItem item)? subtitleBuilder;

  static Future<void> show(
    BuildContext context, {
    required MyActionsModuleTheme theme,
    required MyActionsType actionsType,
    required void Function(MyActionItem item) onItemTap,
    MyActionFilter initialFilter = MyActionFilter.all,
    String? Function(MyActionItem item)? subtitleBuilder,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.sizeOf(context).height * 0.08,
        ),
        child: MyActionsAllSheet(
          theme: theme,
          actionsType: actionsType,
          onItemTap: onItemTap,
          initialFilter: initialFilter,
          subtitleBuilder: subtitleBuilder,
        ),
      ),
    );
  }

  @override
  State<MyActionsAllSheet> createState() => _MyActionsAllSheetState();
}

class _MyActionsAllSheetState extends State<MyActionsAllSheet> {
  final MyActionsRepository _repo = MyActionsRepository();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listController = ScrollController();
  Timer? _debounce;

  final List<MyActionItem> _items = [];
  MyActionFilter _filter = MyActionFilter.all;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String _keyword = '';
  Object? _error;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _searchController.addListener(_onSearchChanged);
    _listController.addListener(_onScroll);
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final next = _searchController.text.trim();
      if (next == _keyword) return;
      _keyword = next;
      _fetch(reset: true);
    });
  }

  void _onScroll() {
    if (!_listController.hasClients ||
        _loading ||
        _loadingMore ||
        !_hasMore) {
      return;
    }
    if (_listController.position.pixels >=
        _listController.position.maxScrollExtent - 280) {
      _fetch();
    }
  }

  List<MyActionItem> _applyFilter(List<MyActionItem> source) {
    return source
        .where((item) => MyActionsModuleTheme.matchesFilter(item.status, _filter))
        .toList();
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loadingMore && !reset) return;

    final nextPage = reset ? 1 : _page + 1;
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final pageItems = await _repo.fetchByType(
        widget.actionsType,
        page: nextPage,
        perPage: MyActionsRepository.defaultPerPage,
        keyword: _keyword,
      );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(pageItems);
        } else {
          _items.addAll(pageItems);
        }
        _page = nextPage;
        _hasMore = pageItems.length == MyActionsRepository.defaultPerPage;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final filtered = _applyFilter(_items);
    final theme = widget.theme;

    return Container(
      decoration: BoxDecoration(
        color: MyActionsModuleTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.tr)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(height: 10.th),
          Container(
            width: 40.tw,
            height: 4.th,
            decoration: BoxDecoration(
              color: MyActionsModuleTheme.textMuted.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.tw, 16.th, 12.tw, 8.th),
            child: Row(
              children: [
                Text('All ${theme.title}', style: theme.sectionTitle),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, size: 22.tsp),
                  color: MyActionsModuleTheme.textMuted,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.tw),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by reference, name, project…',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13.tsp,
                  color: MyActionsModuleTheme.textMuted,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: MyActionsModuleTheme.textMuted,
                  size: 22.tsp,
                ),
                filled: true,
                fillColor: theme.wash,
                contentPadding: EdgeInsets.symmetric(vertical: 12.th),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.tr),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(height: 12.th),
          _FilterStrip(
            theme: theme,
            active: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          SizedBox(height: 8.th),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: theme.primary),
                  )
                : _error != null && filtered.isEmpty
                    ? Center(
                        child: TextButton(
                          onPressed: () => _fetch(reset: true),
                          child: const Text('Retry'),
                        ),
                      )
                    : filtered.isEmpty
                        ? _EmptyState(keyword: _keyword)
                        : ListView.separated(
                            controller: _listController,
                            padding: EdgeInsets.fromLTRB(
                              20.tw,
                              4.th,
                              20.tw,
                              20.th + bottomInset,
                            ),
                            itemCount:
                                filtered.length + (_loadingMore ? 1 : 0),
                            separatorBuilder: (_, __) => SizedBox(height: 10.th),
                            itemBuilder: (context, index) {
                              if (index >= filtered.length) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12.th),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.primary,
                                    ),
                                  ),
                                );
                              }
                              final item = filtered[index];
                              return MyActionListTile(
                                item: item,
                                theme: theme,
                                compact: true,
                                subtitle: widget.subtitleBuilder?.call(item),
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onItemTap(item);
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.theme,
    required this.active,
    required this.onChanged,
  });

  final MyActionsModuleTheme theme;
  final MyActionFilter active;
  final ValueChanged<MyActionFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 20.tw),
      child: Row(
        children: MyActionFilter.values.map((filter) {
          final selected = filter == active;
          return Padding(
            padding: EdgeInsets.only(right: 8.tw),
            child: ChoiceChip(
              label: Text(_label(filter)),
              selected: selected,
              onSelected: (_) => onChanged(filter),
              labelStyle: GoogleFonts.poppins(
                fontSize: 12.tsp,
                fontWeight: FontWeight.w600,
                color: selected ? theme.primary : MyActionsModuleTheme.textMuted,
              ),
              selectedColor: theme.soft,
              backgroundColor: theme.wash,
              side: BorderSide(
                color: selected
                    ? theme.primary.withValues(alpha: 0.35)
                    : Colors.transparent,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(MyActionFilter filter) {
    switch (filter) {
      case MyActionFilter.all:
        return 'All';
      case MyActionFilter.pending:
        return 'Pending';
      case MyActionFilter.approved:
        return 'Approved';
      case MyActionFilter.rejected:
        return 'Rejected';
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.keyword});

  final String keyword;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.tw),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48.tsp,
              color: MyActionsModuleTheme.textMuted,
            ),
            SizedBox(height: 12.th),
            Text(
              keyword.isEmpty
                  ? 'No requests found'
                  : 'No results for "$keyword"',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.tsp,
                color: MyActionsModuleTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

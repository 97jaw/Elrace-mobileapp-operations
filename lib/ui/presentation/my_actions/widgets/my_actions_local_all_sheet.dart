import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/theme/my_actions_module_theme.dart';
import 'package:el_race/ui/presentation/my_actions/widgets/my_action_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class MyActionsLocalAllSheet extends StatefulWidget {
  const MyActionsLocalAllSheet({
    super.key,
    required this.theme,
    required this.items,
    required this.initialFilter,
    required this.onItemTap,
    this.subtitleBuilder,
  });

  final MyActionsModuleTheme theme;
  final List<MyActionItem> items;
  final MyActionFilter initialFilter;
  final void Function(MyActionItem item) onItemTap;
  final String? Function(MyActionItem item)? subtitleBuilder;

  static Future<void> show(
    BuildContext context, {
    required MyActionsModule module,
    required List<MyActionItem> items,
    required MyActionFilter initialFilter,
    required void Function(MyActionItem item) onItemTap,
    String? Function(MyActionItem item)? subtitleBuilder,
  }) {
    final theme = MyActionsModuleTheme.of(module);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.sizeOf(context).height * 0.08,
        ),
        child: MyActionsLocalAllSheet(
          theme: theme,
          items: items,
          initialFilter: initialFilter,
          onItemTap: onItemTap,
          subtitleBuilder: subtitleBuilder,
        ),
      ),
    );
  }

  @override
  State<MyActionsLocalAllSheet> createState() => _MyActionsLocalAllSheetState();
}

class _MyActionsLocalAllSheetState extends State<MyActionsLocalAllSheet> {
  final TextEditingController _searchController = TextEditingController();
  MyActionFilter _filter = MyActionFilter.all;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _searchController.addListener(() {
      setState(() => _keyword = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MyActionItem> get _visible {
    return widget.items.where((item) {
      if (!MyActionsModuleTheme.matchesFilter(item.status, _filter)) {
        return false;
      }
      if (_keyword.isEmpty) return true;
      final haystack = [
        item.name,
        item.reference,
        item.project,
        item.requestType,
        item.employeeName,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(_keyword);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final visible = _visible;

    return Container(
      decoration: BoxDecoration(
        color: MyActionsModuleTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: Column(
        children: [
          SizedBox(height: 10.h),
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: MyActionsModuleTheme.textMuted.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 12.w, 8.h),
            child: Row(
              children: [
                Text('All ${theme.title}', style: theme.sectionTitle),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, size: 22.sp),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search requests…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: theme.wash,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: MyActionFilter.values.map((f) {
                final selected = f == _filter;
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: ChoiceChip(
                    label: Text(f.name),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: theme.soft,
                    backgroundColor: theme.wash,
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      'No results',
                      style: GoogleFonts.poppins(
                        color: MyActionsModuleTheme.textMuted,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      20.w,
                      4.h,
                      20.w,
                      20.h + bottomInset,
                    ),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10.h),
                    itemBuilder: (context, index) {
                      final item = visible[index];
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

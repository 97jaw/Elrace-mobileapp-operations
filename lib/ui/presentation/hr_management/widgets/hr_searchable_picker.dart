import 'package:el_race/ui/presentation/hr_management/widgets/hr_request_form_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Draggable bottom sheet with search — used for HR create-form selections.
class HrSearchablePicker {
  HrSearchablePicker._();

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required List<T> items,
    required String Function(T) labelOf,
    T? selected,
    bool allowClear = false,
    String? clearLabel,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => _HrSearchablePickerSheet<T>(
        title: title,
        items: items,
        labelOf: labelOf,
        selected: selected,
        allowClear: allowClear,
        clearLabel: clearLabel ?? 'None',
      ),
    );
  }
}

class _HrSearchablePickerSheet<T> extends StatefulWidget {
  const _HrSearchablePickerSheet({
    required this.title,
    required this.items,
    required this.labelOf,
    required this.selected,
    required this.allowClear,
    required this.clearLabel,
  });

  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final T? selected;
  final bool allowClear;
  final String clearLabel;

  @override
  State<_HrSearchablePickerSheet<T>> createState() =>
      _HrSearchablePickerSheetState<T>();
}

class _HrSearchablePickerSheetState<T>
    extends State<_HrSearchablePickerSheet<T>> {
  final _search = TextEditingController();
  late List<T> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List<T>.from(widget.items);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _filter(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? List<T>.from(widget.items)
          : widget.items
              .where((i) => widget.labelOf(i).toLowerCase().contains(query))
              .toList();
    });
  }

  bool _isSelected(T item) {
    final sel = widget.selected;
    if (sel == null) return false;
    return widget.labelOf(sel) == widget.labelOf(item);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 14.h, 8.w, 4.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: GoogleFonts.poppins(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                            color: HrRequestFormUi.primary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 10.h),
                  child: TextField(
                    controller: _search,
                    onChanged: _filter,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.grey[600],
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: const BorderSide(
                          color: HrRequestFormUi.accentGrey,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.allowClear)
                  ListTile(
                    leading: Icon(
                      Icons.highlight_off_rounded,
                      color: Colors.grey[600],
                    ),
                    title: Text(widget.clearLabel),
                    onTap: () => Navigator.pop(context, null),
                  ),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No matches',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final item = _filtered[index];
                            final selected = _isSelected(item);
                            return ListTile(
                              onTap: () => Navigator.pop(context, item),
                              title: Text(
                                widget.labelOf(item),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 14.sp,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: HrRequestFormUi.primary,
                                ),
                              ),
                              trailing: selected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: HrRequestFormUi.accentGrey,
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

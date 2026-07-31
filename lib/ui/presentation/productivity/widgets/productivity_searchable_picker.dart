import 'package:el_race/ui/presentation/productivity/theme/productivity_light_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Themed bottom-up searchable single-select picker.
class ProductivitySearchablePicker {
  ProductivitySearchablePicker._();

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
      builder: (_) => _ProductivitySearchablePickerSheet<T>(
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

class _ProductivitySearchablePickerSheet<T> extends StatefulWidget {
  const _ProductivitySearchablePickerSheet({
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
  State<_ProductivitySearchablePickerSheet<T>> createState() =>
      _ProductivitySearchablePickerSheetState<T>();
}

class _ProductivitySearchablePickerSheetState<T>
    extends State<_ProductivitySearchablePickerSheet<T>> {
  static const _accent = Color(0xFF4C8BF5);
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
    if (widget.selected == null) return false;
    return widget.labelOf(widget.selected!) == widget.labelOf(item);
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
              color: ProductivityLightTheme.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: ProductivityLightTheme.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ProductivityLightTheme.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: ProductivityLightTheme.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: TextField(
                    controller: _search,
                    onChanged: _filter,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: GoogleFonts.roboto(
                        color: ProductivityLightTheme.inkMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: ProductivityLightTheme.inkMuted,
                      ),
                      filled: true,
                      fillColor: ProductivityLightTheme.iconChip,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: ProductivityLightTheme.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: _accent, width: 1.4),
                      ),
                    ),
                  ),
                ),
                if (widget.allowClear)
                  ListTile(
                    leading: const Icon(
                      Icons.highlight_off_rounded,
                      color: ProductivityLightTheme.inkMuted,
                    ),
                    title: Text(widget.clearLabel),
                    onTap: () => Navigator.pop(context, null),
                  ),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No matches',
                            style: GoogleFonts.roboto(
                              color: ProductivityLightTheme.inkMuted,
                            ),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.roboto(
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                              trailing: selected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: _accent,
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

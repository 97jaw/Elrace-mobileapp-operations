import 'package:el_race/ui/presentation/timesheet/widgets/tm_animated_list_item.dart';
import 'package:flutter/material.dart';

/// Client-side infinite scroll over an in-memory list (page size chunks).
class TmPaginatedListView extends StatefulWidget {
  const TmPaginatedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.pageSize = 15,
    this.padding,
    this.itemSpacing = 0,
    this.header,
    this.animateItems = true,
    this.controller,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int pageSize;
  final EdgeInsetsGeometry? padding;
  final double itemSpacing;
  final Widget? header;
  final bool animateItems;
  final ScrollController? controller;

  @override
  State<TmPaginatedListView> createState() => _TmPaginatedListViewState();
}

class _TmPaginatedListViewState extends State<TmPaginatedListView> {
  late ScrollController _scrollController;
  late bool _ownsController;
  int _visibleCount = 0;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _scrollController = widget.controller ?? ScrollController();
    _visibleCount = _initialVisible;
    _scrollController.addListener(_onScroll);
  }

  int get _initialVisible =>
      widget.itemCount == 0 ? 0 : widget.pageSize.clamp(1, widget.itemCount);

  @override
  void didUpdateWidget(covariant TmPaginatedListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount) {
      _visibleCount = _initialVisible;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (_ownsController) _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 280) return;
    if (_visibleCount >= widget.itemCount) return;
    setState(() => _loadingMore = true);
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      setState(() {
        _visibleCount =
            (_visibleCount + widget.pageSize).clamp(0, widget.itemCount);
        _loadingMore = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleCount.clamp(0, widget.itemCount);
    final hasMore = visible < widget.itemCount;

    return ListView(
      controller: _scrollController,
      padding: widget.padding,
      children: [
        if (widget.header != null) widget.header!,
        for (var i = 0; i < visible; i++) ...[
          if (i > 0 && widget.itemSpacing > 0)
            SizedBox(height: widget.itemSpacing),
          _buildItem(i),
        ],
        if (hasMore || _loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildItem(int index) {
    final child = widget.itemBuilder(context, index);
    if (!widget.animateItems) return child;
    return TmAnimatedListItem(index: index, child: child);
  }
}

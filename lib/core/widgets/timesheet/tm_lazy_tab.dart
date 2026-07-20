import 'package:flutter/material.dart';

/// Defers building a tab's content until the tab is first shown. By default
/// also keeps it alive afterward so switching tabs doesn't dispose providers
/// and refetch data — set [keepAlive] to false for a tab that's rarely
/// revisited or expensive to keep warm (e.g. camera/ML-heavy), so leaving it
/// lets its providers dispose (and, once .autoDispose, cancel any in-flight
/// request) instead of accumulating alongside every other pinned tab.
class TmLazyTab extends StatefulWidget {
  const TmLazyTab({super.key, required this.builder, this.keepAlive = true});

  final WidgetBuilder builder;
  final bool keepAlive;

  @override
  State<TmLazyTab> createState() => _TmLazyTabState();
}

class _TmLazyTabState extends State<TmLazyTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.builder(context);
  }
}

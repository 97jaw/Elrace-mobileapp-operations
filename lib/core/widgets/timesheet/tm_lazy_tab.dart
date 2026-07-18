import 'package:flutter/material.dart';

/// Defers building a tab's content until the tab is first shown, then keeps
/// it alive so switching tabs doesn't dispose providers and refetch data.
class TmLazyTab extends StatefulWidget {
  const TmLazyTab({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<TmLazyTab> createState() => _TmLazyTabState();
}

class _TmLazyTabState extends State<TmLazyTab>
    with AutomaticKeepAliveClientMixin {
  // Once this tab's page is first built by TabBarView, keep it alive so
  // Riverpod providers behind it are not disposed on tab switch.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.builder(context);
  }
}

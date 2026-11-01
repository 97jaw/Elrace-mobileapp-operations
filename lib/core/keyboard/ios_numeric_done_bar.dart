import 'package:flutter/material.dart';

/// iOS accessory above number and phone keypads. Android is unchanged.
class IosNumericDoneBar extends StatefulWidget {
  const IosNumericDoneBar({super.key, required this.child});

  final Widget child;

  @override
  State<IosNumericDoneBar> createState() => _IosNumericDoneBarState();
}

class _IosNumericDoneBarState extends State<IosNumericDoneBar> {
  static const double _barHeight = 44;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow(context)) return widget.child;

    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    return MediaQuery(
      data: media.copyWith(
        viewInsets: media.viewInsets.copyWith(bottom: keyboard + _barHeight),
      ),
      child: Stack(
        children: [
          widget.child,
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboard,
            child: const _DoneBar(height: _barHeight),
          ),
        ],
      ),
    );
  }

  bool _shouldShow(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.iOS) return false;
    if (MediaQuery.viewInsetsOf(context).bottom <= 0) return false;
    final type = _keyboardTypeOf(FocusManager.instance.primaryFocus);
    if (type == null) return false;
    return type.index == TextInputType.number.index ||
        type.index == TextInputType.phone.index;
  }
}

TextInputType? _keyboardTypeOf(FocusNode? node) {
  final context = node?.context;
  if (context is! Element) return null;

  if (context is StatefulElement && context.state is EditableTextState) {
    return (context.state as EditableTextState).widget.keyboardType;
  }

  final ancestor = context.findAncestorStateOfType<EditableTextState>();
  if (ancestor != null) return ancestor.widget.keyboardType;

  EditableTextState? descendant;
  void visit(Element element) {
    if (descendant != null) return;
    if (element is StatefulElement && element.state is EditableTextState) {
      descendant = element.state as EditableTextState;
      return;
    }
    element.visitChildElements(visit);
  }

  context.visitChildElements(visit);
  return descendant?.widget.keyboardType;
}

class _DoneBar extends StatelessWidget {
  const _DoneBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFD1D3D9),
      child: SizedBox(
        height: height,
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: const Text('Done'),
          ),
        ),
      ),
    );
  }
}

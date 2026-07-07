import 'package:flutter/material.dart';

class MyReportsBackground extends StatelessWidget {
  const MyReportsBackground({
    super.key,
    required this.gradient,
    required this.child,
  });

  final Gradient gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: child,
    );
  }
}

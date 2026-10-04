import 'dart:async';

import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Login loading: the usual spinner with a status line under it.
///
/// Login is a single request, so the text advances on a timer and the last
/// line stays until loading ends.
class LoginProgressCard extends StatefulWidget {
  const LoginProgressCard({
    super.key,
    this.steps = defaultSteps,
    this.finishing,
  });

  final List<({String en, String ar})> steps;

  /// When true, the text switches to "Taking you in..." until the card closes.
  final ValueListenable<bool>? finishing;

  static const finishingStep = (en: 'Taking you in...', ar: 'جارٍ الدخول...');

  static const defaultSteps = <({String en, String ar})>[
    (en: 'Verifying your credentials...', ar: 'التحقق من بيانات الدخول...'),
    (en: 'Checking access rights...', ar: 'التحقق من صلاحيات الوصول...'),
    (en: 'Applying your role rules...', ar: 'تطبيق قواعد دورك...'),
    (en: 'Preparing your dashboard...', ar: 'تجهيز لوحة التحكم...'),
  ];

  @override
  State<LoginProgressCard> createState() => _LoginProgressCardState();
}

class _LoginProgressCardState extends State<LoginProgressCard> {
  static const _stepDuration = Duration(milliseconds: 1300);

  List<({String en, String ar})> get _steps => widget.steps;

  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_stepDuration, (timer) {
      if (!mounted || _current >= _steps.length - 1) {
        timer.cancel();
        return;
      }
      setState(() => _current++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finishing = widget.finishing;
    if (finishing == null) return _buildStep(context, _current);
    return ValueListenableBuilder<bool>(
      valueListenable: finishing,
      builder: (context, done, _) => _buildStep(context, done ? -1 : _current),
    );
  }

  Widget _buildStep(BuildContext context, int index) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final step = index < 0 ? LoginProgressCard.finishingStep : _steps[index];
    return PopScope(
      canPop: false,
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              SizedBox(height: 16.th),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  arabic ? step.ar : step.en,
                  key: ValueKey(index),
                  textAlign: TextAlign.center,
                  textDirection:
                      arabic ? TextDirection.rtl : TextDirection.ltr,
                  style: GoogleFonts.poppins(
                    fontSize: 13.tsp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

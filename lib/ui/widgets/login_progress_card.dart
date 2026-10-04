import 'dart:async';

import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Login loading: the usual spinner with a status line under it.
///
/// Login is a single request, so the text advances on a timer and the last
/// line stays until loading ends.
class LoginProgressCard extends StatefulWidget {
  const LoginProgressCard({super.key});

  @override
  State<LoginProgressCard> createState() => _LoginProgressCardState();
}

class _LoginProgressCardState extends State<LoginProgressCard> {
  static const _stepDuration = Duration(milliseconds: 1300);

  static const _steps = <({String en, String ar})>[
    (en: 'Verifying your credentials...', ar: 'التحقق من بيانات الدخول...'),
    (en: 'Checking access rights...', ar: 'التحقق من صلاحيات الوصول...'),
    (en: 'Applying your role rules...', ar: 'تطبيق قواعد دورك...'),
    (en: 'Preparing your dashboard...', ar: 'تجهيز لوحة التحكم...'),
  ];

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
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final step = _steps[_current];
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
                  key: ValueKey(_current),
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

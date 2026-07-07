import 'dart:async';

import 'package:el_race/ui/presentation/elrace_ai/elrace_ai_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class _NotesFeature {
  const _NotesFeature({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
}

/// Attractive preview of upcoming Notes AI capabilities (visual only).
class NotesAiComingSoonSection extends StatefulWidget {
  const NotesAiComingSoonSection({super.key});

  @override
  State<NotesAiComingSoonSection> createState() =>
      _NotesAiComingSoonSectionState();
}

class _NotesAiComingSoonSectionState extends State<NotesAiComingSoonSection>
    with SingleTickerProviderStateMixin {
  static const _features = [
    _NotesFeature(
      title: 'AI Assistant',
      subtitle: 'Ask questions about your notes',
      icon: Icons.auto_awesome_rounded,
      gradient: ElraceAiTheme.electricLavender,
    ),
    _NotesFeature(
      title: 'Transcribe',
      subtitle: 'Voice → structured notes',
      icon: Icons.mic_rounded,
      gradient: ElraceAiTheme.aqua,
    ),
    _NotesFeature(
      title: 'Smart Notes',
      subtitle: 'Auto-tag & organize',
      icon: Icons.note_alt_outlined,
      gradient: ElraceAiTheme.ghostPurple,
    ),
    _NotesFeature(
      title: 'Summarize',
      subtitle: 'TL;DR for long notes',
      icon: Icons.summarize_outlined,
      gradient: ElraceAiTheme.blueFrost,
    ),
  ];

  late final AnimationController _pulse;
  Timer? _cycleTimer;
  int _active = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _cycleTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _active = (_active + 1) % _features.length);
    });
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spotlight = _features[_active];

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEDE9FE),
            Color(0xFFE0F2FE),
            Color(0xFFF5F3FF),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: ElraceAiTheme.accentPurple.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: Stack(
          children: [
            Positioned(
              right: -24.w,
              top: -18.h,
              child: Icon(
                spotlight.icon,
                size: 96.sp,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: ElraceAiTheme.accentPurple
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          'COMING SOON',
                          style: GoogleFonts.poppins(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: ElraceAiTheme.accentDeep,
                          ),
                        ),
                      ),
                      const Spacer(),
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) {
                          return Container(
                            width: 8.w,
                            height: 8.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ElraceAiTheme.accentPurple.withValues(
                                alpha: 0.45 + _pulse.value * 0.55,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'In development',
                        style: GoogleFonts.poppins(
                          fontSize: 10.sp,
                          color: ElraceAiTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    'Notes AI',
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: ElraceAiTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Write, speak, and summarize — all in one place.',
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      height: 1.4,
                      color: ElraceAiTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _SpotlightCard(
                      key: ValueKey(spotlight.title),
                      feature: spotlight,
                      pulse: _pulse,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: List.generate(_features.length, (i) {
                      final f = _features[i];
                      final selected = i == _active;
                      return GestureDetector(
                        onTap: () => setState(() => _active = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14.r),
                            gradient: selected ? f.gradient : null,
                            color: selected
                                ? null
                                : Colors.white.withValues(alpha: 0.55),
                            border: Border.all(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                f.icon,
                                size: 14.sp,
                                color: ElraceAiTheme.textPrimary,
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                f.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  color: ElraceAiTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({
    super.key,
    required this.feature,
    required this.pulse,
  });

  final _NotesFeature feature;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = pulse.value;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            gradient: feature.gradient,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(feature.icon, size: 18.sp, color: ElraceAiTheme.textPrimary),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      feature.title,
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: ElraceAiTheme.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ElraceAiTheme.accentPurple
                          .withValues(alpha: 0.5 + t * 0.5),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                feature.subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 11.sp,
                  color: ElraceAiTheme.textPrimary.withValues(alpha: 0.75),
                ),
              ),
              SizedBox(height: 10.h),
              _ShimmerLine(widthFactor: 0.62 + t * 0.15),
              SizedBox(height: 5.h),
              _ShimmerLine(widthFactor: 0.48 + t * 0.2),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  const _ShimmerLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor.clamp(0.3, 1.0),
      alignment: Alignment.centerLeft,
      child: Container(
        height: 5.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

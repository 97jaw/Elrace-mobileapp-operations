import 'dart:async';

import 'package:el_race/ui/presentation/elrace_ai/elrace_ai_assistant_screen.dart';
import 'package:el_race/ui/presentation/elrace_ai/elrace_ai_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class _TourModule {
  const _TourModule({
    required this.module,
    required this.headline,
    required this.caption,
    required this.gradient,
    required this.icon,
    required this.demoLabel,
    required this.demoLines,
  });

  final String module;
  final String headline;
  final String caption;
  final LinearGradient gradient;
  final IconData icon;
  final String demoLabel;
  final List<String> demoLines;
}

/// Single-screen AI tour — fully themed, all modules visible with live demos.
class ElraceAiTourScreen extends StatefulWidget {
  const ElraceAiTourScreen({super.key});

  @override
  State<ElraceAiTourScreen> createState() => _ElraceAiTourScreenState();
}

class _ElraceAiTourScreenState extends State<ElraceAiTourScreen>
    with TickerProviderStateMixin {
  static const _modules = [
    _TourModule(
      module: 'Purchase',
      headline: 'RFQ & LPO intelligence',
      caption: 'Summarize waiting RFQs, draft invoices, and spend trends.',
      gradient: ElraceAiTheme.electricLavender,
      icon: Icons.receipt_long_outlined,
      demoLabel: 'Scanning purchase pipeline…',
      demoLines: ['3 RFQs need review', 'Draft invoice ready', 'Spend ↑ 12% MoM'],
    ),
    _TourModule(
      module: 'Projects',
      headline: 'Portfolio progress AI',
      caption: 'Spot delayed WOs, S-curve variance, and document gaps.',
      gradient: ElraceAiTheme.aqua,
      icon: Icons.apartment_outlined,
      demoLabel: 'Analyzing project health…',
      demoLines: ['WO-204 delayed 4 days', 'S-curve behind plan', '2 docs missing'],
    ),
    _TourModule(
      module: 'HR & Attendance',
      headline: 'Workforce assistant',
      caption: 'Check-in insights, leave patterns, and HR triage.',
      gradient: ElraceAiTheme.blueFrost,
      icon: Icons.badge_outlined,
      demoLabel: 'Reviewing attendance signals…',
      demoLines: ['Late check-ins: 2 today', 'Leave pattern detected', 'HR request queued'],
    ),
    _TourModule(
      module: 'Documents',
      headline: 'Smart document search',
      caption: 'Find contracts and drawings in natural language.',
      gradient: ElraceAiTheme.ghostPurple,
      icon: Icons.folder_open_outlined,
      demoLabel: 'Indexing document library…',
      demoLines: ['Contract v3 found', 'Drawing A-12 matched', 'Approval pending'],
    ),
    _TourModule(
      module: 'Timesheet',
      headline: 'Hours & anomaly detection',
      caption: 'Flag unusual entries and prepare weekly summaries.',
      gradient: ElraceAiTheme.rosewood,
      icon: Icons.schedule_outlined,
      demoLabel: 'Validating timesheet entries…',
      demoLines: ['Overtime spike flagged', 'Weekly summary ready', '3 entries reviewed'],
    ),
    _TourModule(
      module: 'Finance',
      headline: 'Petty cash & approvals',
      caption: 'Categorize expenses and prioritize approval queues.',
      gradient: ElraceAiTheme.blackberry,
      icon: Icons.account_balance_wallet_outlined,
      demoLabel: 'Processing finance queue…',
      demoLines: ['AED 2.4K pending', 'Auto-categorized: 8', 'Top priority: PC-441'],
    ),
  ];

  late final List<AnimationController> _modulePulses;
  late final AnimationController _heroGlow;

  @override
  void initState() {
    super.initState();
    _heroGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _modulePulses = List.generate(
      _modules.length,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1200 + i * 180),
      )..repeat(reverse: true),
    );
  }

  @override
  void dispose() {
    _heroGlow.dispose();
    for (final c in _modulePulses) {
      c.dispose();
    }
    super.dispose();
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ElraceAiAssistantScreen(
          title: 'Elrace AI',
          subtitle:
              'Your intelligent copilot across purchase, projects, HR, and finance.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEDE9FE),
            Color(0xFFE0F7FA),
            Color(0xFFF0F9FF),
            Color(0xFFF5F3FF),
            Color(0xFFE0F2FE),
          ],
          stops: [0.0, 0.22, 0.48, 0.72, 1.0],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned(
              right: -60.w,
              top: topPad + 40.h,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 180.sp,
                color: ElraceAiTheme.accentPurple.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              left: -40.w,
              bottom: 120.h,
              child: Icon(
                Icons.hub_outlined,
                size: 140.sp,
                color: ElraceAiTheme.accentDeep.withValues(alpha: 0.06),
              ),
            ),
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, topPad + 8.h, 16.w, 0),
                    child: Row(
                      children: [
                        _GlassIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        _GlassIconButton(
                          icon: Icons.chat_bubble_outline_rounded,
                          onTap: _openChat,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
                    child: _HeroIntro(glow: _heroGlow),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: _ModuleTourCard(
                          module: _modules[i],
                          pulse: _modulePulses[i],
                          index: i,
                        ),
                      ),
                      childCount: _modules.length,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
                    child: _AutomationStrip(pulse: _heroGlow),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: _openChat,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ElraceAiTheme.accentPurple,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome, size: 18.sp),
                            SizedBox(width: 8.w),
                            Text(
                              'Ask Elrace AI',
                              style: GoogleFonts.poppins(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.paddingOf(context).bottom + 16.h,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.r),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.75)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(10.w),
          child: Icon(icon, size: 18.sp, color: ElraceAiTheme.textPrimary),
        ),
      ),
    );
  }
}

class _HeroIntro extends StatelessWidget {
  const _HeroIntro({required this.glow});

  final AnimationController glow;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glow,
      builder: (context, _) {
        final t = glow.value;
        return Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  const Color(0xFF7C3AED),
                  const Color(0xFF06B6D4),
                  t * 0.35,
                )!
                    .withValues(alpha: 0.88),
                Color.lerp(
                  const Color(0xFF5B21B6),
                  const Color(0xFF0891B2),
                  t * 0.25,
                )!
                    .withValues(alpha: 0.92),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: ElraceAiTheme.accentPurple.withValues(alpha: 0.22 + t * 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 22.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your ERP copilot',
                          style: GoogleFonts.poppins(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        Text(
                          'AI automation across every module',
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              _LiveStatusRow(
                label: 'Tour automation running',
                pulse: t,
              ),
              SizedBox(height: 8.h),
              Text(
                'Watch live previews below — each module shows how Elrace AI will work for you.',
                style: GoogleFonts.poppins(
                  fontSize: 11.sp,
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LiveStatusRow extends StatelessWidget {
  const _LiveStatusRow({required this.label, required this.pulse});

  final String label;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16 + pulse * 0.06),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 14.w,
            height: 14.w,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white.withValues(alpha: 0.7 + pulse * 0.3),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Icon(Icons.bolt_rounded, size: 16.sp, color: Colors.white.withValues(alpha: 0.9)),
        ],
      ),
    );
  }
}

class _ModuleTourCard extends StatefulWidget {
  const _ModuleTourCard({
    required this.module,
    required this.pulse,
    required this.index,
  });

  final _TourModule module;
  final AnimationController pulse;
  final int index;

  @override
  State<_ModuleTourCard> createState() => _ModuleTourCardState();
}

class _ModuleTourCardState extends State<_ModuleTourCard> {
  Timer? _lineTimer;
  int _lineIndex = 0;

  @override
  void initState() {
    super.initState();
    _lineTimer = Timer.periodic(
      Duration(milliseconds: 2200 + widget.index * 300),
      (_) {
        if (!mounted) return;
        setState(() {
          _lineIndex = (_lineIndex + 1) % widget.module.demoLines.length;
        });
      },
    );
  }

  @override
  void dispose() {
    _lineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.module;
    final lightText = m.gradient == ElraceAiTheme.blackberry;

    return AnimatedBuilder(
      animation: widget.pulse,
      builder: (context, _) {
        final t = widget.pulse.value;
        final textColor =
            lightText ? Colors.white : ElraceAiTheme.textPrimary;
        final subColor = lightText
            ? Colors.white.withValues(alpha: 0.78)
            : ElraceAiTheme.textPrimary.withValues(alpha: 0.72);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            gradient: m.gradient,
            border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
            boxShadow: [
              BoxShadow(
                color: ElraceAiTheme.accentPurple.withValues(alpha: 0.08 + t * 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: Stack(
              children: [
                Positioned(
                  right: -20.w,
                  top: -12.h,
                  child: Icon(
                    m.icon,
                    size: 72.sp,
                    color: (lightText ? Colors.white : ElraceAiTheme.textPrimary)
                        .withValues(alpha: 0.12),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: lightText ? 0.18 : 0.35),
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Text(
                              m.module.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: textColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(m.icon, size: 16.sp, color: textColor.withValues(alpha: 0.85)),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        m.headline,
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        m.caption,
                        style: GoogleFonts.poppins(
                          fontSize: 10.sp,
                          height: 1.4,
                          color: subColor,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      _MiniDemoPanel(
                        label: m.demoLabel,
                        activeLine: m.demoLines[_lineIndex],
                        pulse: t,
                        lightSurface: lightText,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniDemoPanel extends StatelessWidget {
  const _MiniDemoPanel({
    required this.label,
    required this.activeLine,
    required this.pulse,
    required this.lightSurface,
  });

  final String label;
  final String activeLine;
  final double pulse;
  final bool lightSurface;

  @override
  Widget build(BuildContext context) {
    final textColor =
        lightSurface ? Colors.white : ElraceAiTheme.textPrimary;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: lightSurface ? 0.12 + pulse * 0.06 : 0.42 + pulse * 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: lightSurface ? 0.22 : 0.65),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 12.w,
                height: 12.w,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: (lightSurface ? Colors.white : ElraceAiTheme.accentPurple)
                      .withValues(alpha: 0.55 + pulse * 0.45),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Text(
              activeLine,
              key: ValueKey(activeLine),
              style: GoogleFonts.poppins(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          SizedBox(height: 6.h),
          _TypingLine(widthFactor: 0.55 + pulse * 0.2, light: lightSurface),
          SizedBox(height: 4.h),
          _TypingLine(widthFactor: 0.38 + pulse * 0.15, light: lightSurface),
        ],
      ),
    );
  }
}

class _TypingLine extends StatelessWidget {
  const _TypingLine({required this.widthFactor, this.light = false});

  final double widthFactor;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor.clamp(0.25, 1.0),
      alignment: Alignment.centerLeft,
      child: Container(
        height: 4.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: light
              ? Colors.white.withValues(alpha: 0.35)
              : ElraceAiTheme.accentPurple.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _AutomationStrip extends StatelessWidget {
  const _AutomationStrip({required this.pulse});

  final AnimationController pulse;

  static const _tags = [
    'Auto-summarize',
    'Smart search',
    'Anomaly alerts',
    'Approval triage',
    'Weekly reports',
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.42 + pulse.value * 0.08),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Automation highlights',
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: ElraceAiTheme.textPrimary,
                ),
              ),
              SizedBox(height: 10.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: _tags.map((tag) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      gradient: ElraceAiTheme.electricLavender,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 12.sp,
                          color: ElraceAiTheme.accentDeep,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          tag,
                          style: GoogleFonts.poppins(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                            color: ElraceAiTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

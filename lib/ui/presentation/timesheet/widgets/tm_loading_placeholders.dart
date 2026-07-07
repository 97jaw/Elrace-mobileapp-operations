import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';

/// Pulsing placeholder block (shimmer-style without extra packages).
class TmShimmerBox extends StatefulWidget {
  const TmShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<TmShimmerBox> createState() => _TmShimmerBoxState();
}

class _TmShimmerBoxState extends State<TmShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = 0.35 + (_controller.value * 0.35);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: TimesheetModuleColors.divider.withValues(alpha: t),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// Full-screen list loading placeholders.
class TimesheetListLoadingPlaceholders extends StatelessWidget {
  const TimesheetListLoadingPlaceholders({
    super.key,
    this.itemCount = 4,
    this.cardHeight = 88,
  });

  final int itemCount;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(TimesheetModuleLayout.screenPaddingH),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) =>
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
      itemBuilder: (_, __) => Container(
        height: cardHeight,
        padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
        decoration: BoxDecoration(
          color: TimesheetModuleColors.surface,
          borderRadius:
              BorderRadius.circular(TimesheetModuleLayout.cardRadiusLg),
          border: Border.all(color: TimesheetModuleColors.divider),
        ),
        child: Row(
          children: [
            const TmShimmerBox(width: 56, height: 56, borderRadius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  TmShimmerBox(width: double.infinity, height: 14),
                  SizedBox(height: 8),
                  TmShimmerBox(width: 120, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Folder card gradient placeholder.
class TimesheetFolderCardPlaceholder extends StatelessWidget {
  const TimesheetFolderCardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.navyTint,
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          TmShimmerBox(width: 180, height: 16, borderRadius: 6),
          SizedBox(height: 10),
          TmShimmerBox(width: 100, height: 12, borderRadius: 6),
          Spacer(),
          Row(
            children: [
              TmShimmerBox(width: 44, height: 44, borderRadius: 8),
              SizedBox(width: 6),
              TmShimmerBox(width: 44, height: 44, borderRadius: 8),
              SizedBox(width: 6),
              TmShimmerBox(width: 44, height: 44, borderRadius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

/// Gallery grid placeholders.
class TimesheetGalleryLoadingPlaceholders extends StatelessWidget {
  const TimesheetGalleryLoadingPlaceholders({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(TimesheetModuleLayout.screenPaddingH),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const TmShimmerBox(
        width: double.infinity,
        height: double.infinity,
        borderRadius: 12,
      ),
    );
  }
}

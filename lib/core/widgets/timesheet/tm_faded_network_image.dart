import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Client / partner image shown faded on dark contrast areas.
class TmFadedNetworkImage extends StatelessWidget {
  const TmFadedNetworkImage({
    super.key,
    required this.imageUrl,
    this.height = 92,
    this.width = 86,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  final String imageUrl;
  final double height;
  final double width;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ??
        BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: fit,
                color: Colors.white.withValues(alpha: 0.35),
                colorBlendMode: BlendMode.modulate,
                errorBuilder: (_, __, ___) => _placeholder(radius),
              )
            else
              _placeholder(radius),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    TimesheetModuleColors.navy.withValues(alpha: 0.15),
                    TimesheetModuleColors.primary.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BorderRadius radius) {
    return Container(
      decoration: BoxDecoration(
        color: TimesheetModuleColors.surface.withValues(alpha: 0.12),
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Icon(
        PhosphorIcons.buildings(),
        color: TimesheetModuleColors.surface.withValues(alpha: 0.5),
        size: 32,
      ),
    );
  }
}

/// Full-width hero with faded client image (project detail).
class TmFadedHeroImage extends StatelessWidget {
  const TmFadedHeroImage({
    super.key,
    required this.imageUrl,
    required this.height,
    this.borderRadius,
  });

  final String imageUrl;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ??
        const BorderRadius.vertical(
          top: Radius.circular(TimesheetModuleLayout.cardRadiusLg),
        );

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    TimesheetModuleColors.navy,
                    TimesheetModuleColors.primary,
                  ],
                ),
              ),
            ),
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                color: Colors.white.withValues(alpha: 0.28),
                colorBlendMode: BlendMode.modulate,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

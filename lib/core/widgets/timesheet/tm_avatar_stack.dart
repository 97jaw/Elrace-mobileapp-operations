import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';

class TmAvatarStack extends StatelessWidget {
  const TmAvatarStack({
    super.key,
    required this.labels,
    this.imageUrls = const [],
    this.maxVisible = 3,
    this.size = TimesheetModuleLayout.avatarSize,
  });

  final List<String> labels;
  final List<String?> imageUrls;
  final int maxVisible;
  final double size;

  @override
  Widget build(BuildContext context) {
    final visibleCount = labels.length.clamp(0, maxVisible);
    final extraCount = labels.length - visibleCount;

    return SizedBox(
      width: (visibleCount + (extraCount > 0 ? 1 : 0)) * (size * 0.72),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < visibleCount; i++)
            Positioned(
              left: i * (size * 0.62),
              child: _TmAvatarBubble(
                label: labels[i],
                imageUrl: i < imageUrls.length ? imageUrls[i] : null,
                size: size,
              ),
            ),
          if (extraCount > 0)
            Positioned(
              left: visibleCount * (size * 0.62),
              child: _TmAvatarBubble(
                label: '+$extraCount',
                size: size,
                isCount: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _TmAvatarBubble extends StatelessWidget {
  const _TmAvatarBubble({
    required this.label,
    required this.size,
    this.imageUrl,
    this.isCount = false,
  });

  final String label;
  final String? imageUrl;
  final double size;
  final bool isCount;

  @override
  Widget build(BuildContext context) {
    final text = isCount
        ? label
        : label.trim().isEmpty
            ? '?'
            : label.trim().characters.first.toUpperCase();
    final url = imageUrl?.trim() ?? '';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isCount
            ? TimesheetModuleColors.text
            : TimesheetModuleColors.primaryTint,
        shape: BoxShape.circle,
        border: Border.all(
          color: TimesheetModuleColors.surface,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: !isCount && url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, __, ___) => Text(
                text,
                style: TimesheetModuleTypography.caption().copyWith(
                  color: TimesheetModuleColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Text(
              text,
              style: TimesheetModuleTypography.caption().copyWith(
                color: isCount
                    ? TimesheetModuleColors.surface
                    : TimesheetModuleColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

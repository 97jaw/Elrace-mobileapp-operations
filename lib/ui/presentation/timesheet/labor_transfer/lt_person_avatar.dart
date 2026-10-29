import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:flutter/material.dart';

class LtPersonAvatar extends StatelessWidget {
  const LtPersonAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 28,
  });

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: TimesheetModuleColors.iconSurface,
        border: Border.all(color: TimesheetModuleColors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? TmFastNetworkImage(
              url: photoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              memCacheWidth: (size * 3).round(),
            )
          : Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w700,
                  color: TimesheetModuleColors.ink,
                ),
              ),
            ),
    );
  }
}

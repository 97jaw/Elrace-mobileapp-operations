import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:flutter/material.dart';

/// Profile image that does not throw when the URL 404s — uses [Image.network] + [errorBuilder].
class AttendanceNetworkAvatar extends StatelessWidget {
  const AttendanceNetworkAvatar({
    super.key,
    required this.radius,
    this.imageUrl,
    required this.fallback,
  });

  final double radius;
  final String? imageUrl;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: HrModuleColors.lightBg,
        child: fallback,
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: HrModuleColors.lightBg,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => Container(
              width: size,
              height: size,
              color: HrModuleColors.lightBg,
              alignment: Alignment.center,
              child: fallback,
            ),
          ),
        ),
      ),
    );
  }
}

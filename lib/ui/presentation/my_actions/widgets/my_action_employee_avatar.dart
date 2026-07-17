import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:el_race/ui/presentation/my_actions/theme/my_actions_module_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

abstract final class MyActionEmployeeAvatar {
  static String? sanitizeUrl(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (lower == 'false' || lower == 'null' || lower == 'none') return null;
    if (lower.contains('/image/false') || lower.endsWith('/false')) {
      return null;
    }
    return value;
  }

  static Widget circle({
    required String? imageUrl,
    required Color statusColor,
    required Color fallbackTint,
    required Color fallbackIcon,
    double size = 44,
  }) {
    final url = sanitizeUrl(imageUrl);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size.tw,
          height: size.tw,
          decoration: BoxDecoration(
            color: fallbackTint,
            shape: BoxShape.circle,
            border: Border.all(color: MyActionsModuleTheme.white, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: url != null
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _fallback(fallbackTint, fallbackIcon, size),
                  errorWidget: (_, __, ___) =>
                      _fallback(fallbackTint, fallbackIcon, size),
                )
              : _fallback(fallbackTint, fallbackIcon, size),
        ),
        Positioned(
          bottom: -1,
          right: -1,
          child: Container(
            width: 12.tw,
            height: 12.tw,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: MyActionsModuleTheme.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _fallback(Color bg, Color iconColor, double size) {
    return Container(
      color: bg,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        color: iconColor,
        size: size * 0.5,
      ),
    );
  }
}

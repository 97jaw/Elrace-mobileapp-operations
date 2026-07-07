import 'package:cached_network_image/cached_network_image.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/material.dart';

/// Memory-cached network image for projects module (reduces decode cost).
class ProjectsCachedImage extends StatelessWidget {
  const ProjectsCachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  Map<String, String>? get _headers {
    final token = SharedPref.getLoginData().result?.token ?? '';
    if (token.isEmpty) return null;
    return {'Accept': 'image/*', 'Authorization': 'Bearer $token'};
  }

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return errorWidget ?? const SizedBox.shrink();
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = width != null ? (width! * dpr).round() : null;
    final memH = height != null ? (height! * dpr).round() : null;

    Widget child = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      httpHeaders: _headers,
      memCacheWidth: memW,
      memCacheHeight: memH,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, __) =>
          placeholder ??
          SizedBox(
            width: width,
            height: height,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      errorWidget: (_, __, ___) =>
          errorWidget ?? const SizedBox.shrink(),
    );

    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }
}

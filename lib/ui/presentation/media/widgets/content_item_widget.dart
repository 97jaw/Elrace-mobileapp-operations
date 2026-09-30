import 'package:el_race/utils/color_utils.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../data/content_model.dart';

class ContentItemWidget extends StatelessWidget {
  final ContentModel content;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ContentItemWidget({
    super.key,
    required this.content,
    this.onTap,
    this.onLongPress,
  });

  Widget _buildThumbnail({bool withBorder = true}) {
    final String imageUrl = content.displayImageUrl;
    final borderRadius = BorderRadius.circular(18.tr);
    const borderColor = Color(0xB8484848);

    Widget placeholder() {
      return Container(
        color: Colors.black.withOpacity(0.04),
        alignment: Alignment.center,
        child: Icon(
          content.is360View ? Icons.threesixty : Icons.image_outlined,
          size: 44.tsp,
          color: appFontColor.withOpacity(0.55),
        ),
      );
    }

    Widget buildNetworkImage() {
      // Check if URL is a web link (like vercel) vs image
      final isWebUrl = imageUrl.contains('vercel.app') ||
          imageUrl.contains('.html') ||
          !_isImageUrl(imageUrl);

      if (isWebUrl) {
        return placeholder();
      }

      return Image.network(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => placeholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 22.tw,
              height: 22.tw,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: withBorder ? Border.all(color: borderColor, width: 1) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: buildNetworkImage(),
      ),
    );
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.contains('/image/');
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(22.tr);
    const borderColor = Color(0xB8484848);

    final uploadedText = content.dateCreated == null
        ? null
        : 'Uploaded at ${DateFormat('dd/MM/yyyy').format(content.dateCreated!)}';

    if (content.is360View) {
      const start = Color(0xFF444D56);
      const end = Color(0xFF434D56);

      return Material(
        color: Colors.transparent,
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            height: 180.th,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [start, end],
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.tw, vertical: 14.th),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 110.tw,
                        height: 150.th,
                        child: _buildThumbnail(withBorder: false),
                      ),
                      SizedBox(width: 14.tw),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: 64.tw),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '360 TOUR',
                                  textAlign: TextAlign.left,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.tsp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withOpacity(0.75),
                                    letterSpacing: 1.0,
                                  ),
                                  maxLines: null,
                                  overflow: TextOverflow.visible,
                                ),
                                SizedBox(height: 4.th),
                                Text(
                                  content.displayName,
                                  textAlign: TextAlign.left,
                                  style: GoogleFonts.poppins(
                                    fontSize: 18.tsp,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.visible,
                                ),
                                if (content.projectName.isNotEmpty) ...[
                                  SizedBox(height: 2.th),
                                  Text(
                                    content.projectName,
                                    textAlign: TextAlign.left,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.tsp,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.75),
                                    ),
                                    maxLines: null,
                                    overflow: TextOverflow.visible,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 14.th,
                  right: 16.tw,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16.tr),
                    onTap: onTap,
                    child: Container(
                      height: 34.th,
                      padding: EdgeInsets.symmetric(horizontal: 20.tw),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(16.tr),
                      ),
                      child: Text(
                        'Go',
                        style: GoogleFonts.poppins(
                          fontSize: 13.tsp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12.th,
                  right: 12.tw,
                  child: Opacity(
                    opacity: 0.9,
                    child: Image.asset(
                      'assets/newapp/newicon/360 degrees.png',
                      width: 28.tw,
                      height: 28.tw,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE6E6E6),
            borderRadius: borderRadius,
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 10.th, right: 14.tw, left: 14.tw),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    uploadedText ?? (content.is360View ? '360° VIEW' : 'PHOTO'),
                    style: GoogleFonts.poppins(
                      fontSize: 11.tsp,
                      color: const Color(0xFF6E6E6E),
                      letterSpacing: 0.8,
                    ),
                    maxLines: null,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 14.tw, vertical: 10.th),
                child: SizedBox(
                  width: double.infinity,
                  height: 170.th,
                  child: _buildThumbnail(),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: 16.tw,
                  right: 12.tw,
                  bottom: 14.th,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content.displayName,
                            style: GoogleFonts.poppins(
                              fontSize: 16.tsp,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                            maxLines: null,
                            overflow: TextOverflow.visible,
                          ),
                          if (content.projectName.isNotEmpty) ...[
                            SizedBox(height: 2.th),
                            Text(
                              content.projectName,
                              style: GoogleFonts.poppins(
                                fontSize: 12.tsp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF6E6E6E),
                              ),
                              maxLines: null,
                              overflow: TextOverflow.visible,
                            ),
                          ],
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(12.tr),
                      onTap: onTap,
                      child: Container(
                        height: 30.th,
                        padding: EdgeInsets.symmetric(horizontal: 14.tw),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6E6E6E),
                          borderRadius: BorderRadius.circular(12.tr),
                        ),
                        child: Text(
                          'View',
                          style: GoogleFonts.poppins(
                            fontSize: 12.tsp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.tw),
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _shareContent(context),
                      child: SizedBox(
                        width: 42.tw,
                        height: 42.tw,
                        child: Center(
                          child: Image.asset(
                            'assets/newapp/newicon/media_share_icon.png',
                            width: 40.tw,
                            height: 24.th,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareContent(BuildContext context) async {
    try {
      final shareText = content.is360View
          ? '${content.fileName}\n360° View: ${content.previewUrl}'
          : '${content.fileName}\n${content.previewUrl}';

      await SharePlus.instance.share(
        ShareParams(text: shareText),
      );
    } catch (e) {
      debugPrint('Error sharing content: $e');
    }
  }
}

import 'package:flutter/material.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/content_model.dart';
import '../theme/media_theme.dart';
import 'media_content_thumbnail.dart';

/// Profile-style swipeable hero card for photos / 360° content.
class MediaContentHero extends StatefulWidget {
  const MediaContentHero({
    super.key,
    required this.items,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
    required this.is360Mode,
    this.onBack,
    this.onMore,
    this.onPrimaryAction,
    this.imageHeaders,
  });

  final List<ContentModel> items;
  final PageController pageController;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final bool is360Mode;
  final VoidCallback? onBack;
  final VoidCallback? onMore;
  final VoidCallback? onPrimaryAction;
  final Map<String, String>? imageHeaders;

  @override
  State<MediaContentHero> createState() => _MediaContentHeroState();
}

class _MediaContentHeroState extends State<MediaContentHero> {
  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final topPadding = MediaQuery.paddingOf(context).top + 8.th;
    final index = widget.currentIndex.clamp(0, widget.items.length - 1);
    final item = widget.items[index];

    return Padding(
      padding: EdgeInsets.fromLTRB(12.tw, topPadding, 12.tw, 10.th),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MediaTheme.heroCardRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: widget.pageController,
              itemCount: widget.items.length,
              onPageChanged: widget.onPageChanged,
              itemBuilder: (context, index) {
                return MediaContentThumbnail(
                  content: widget.items[index],
                  imageHeaders: widget.imageHeaders,
                  borderRadius: BorderRadius.zero,
                );
              },
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: MediaTheme.heroBottomScrim,
              ),
            ),
            Positioned(
              top: 8.th,
              left: 8.tw,
              right: 8.tw,
              child: Row(
                children: [
                  if (widget.onBack != null)
                    MediaTheme.backButton(onTap: widget.onBack!)
                  else
                    SizedBox(width: 40.tw),
                  const Spacer(),
                  if (widget.items.length > 1)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.tw,
                        vertical: 4.th,
                      ),
                      decoration: BoxDecoration(
                        color: MediaTheme.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${index + 1}/${widget.items.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 11.tsp,
                          fontWeight: FontWeight.w600,
                          color: MediaTheme.white,
                        ),
                      ),
                    ),
                  SizedBox(width: 8.tw),
                  if (widget.onMore != null)
                    MediaTheme.moreButton(onTap: widget.onMore!),
                ],
              ),
            ),
            Positioned(
              left: 16.tw,
              right: 16.tw,
              bottom: 16.th,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MediaTheme.titleLg,
                        ),
                        if (item.projectName.isNotEmpty) ...[
                          SizedBox(height: 4.th),
                          Text(
                            item.projectName,
                            style: GoogleFonts.poppins(
                              fontSize: 13.tsp,
                              fontWeight: FontWeight.w500,
                              color: MediaTheme.textSecondary,
                            ),
                          ),
                        ],
                        if (item.dateCreated != null) ...[
                          SizedBox(height: 4.th),
                          Text(
                            _formatDate(item.dateCreated),
                            style: MediaTheme.labelSm,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.onPrimaryAction != null) ...[
                    SizedBox(width: 12.tw),
                    MediaTheme.pillButton(
                      label: widget.is360Mode ? 'View 360°' : 'View',
                      onTap: widget.onPrimaryAction!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

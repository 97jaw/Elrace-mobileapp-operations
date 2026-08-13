import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Icon-only floating composer toolbar with gold active state.
class NotesComposerToolbar extends StatelessWidget {
  const NotesComposerToolbar({
    super.key,
    required this.bottomPadding,
    required this.onFormat,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onToggleBullet,
    required this.onMarker,
    required this.onLink,
    required this.onAttachFile,
    required this.onScan,
    required this.onPhotoLibrary,
    required this.onTakePhoto,
    required this.onVideo,
    required this.onAudio,
    required this.onAi,
    this.boldSelected = false,
    this.italicSelected = false,
    this.underlineSelected = false,
    this.bulletSelected = false,
    this.markerSelected = false,
    this.enabled = true,
  });

  final double bottomPadding;
  final VoidCallback? onFormat;
  final VoidCallback? onBold;
  final VoidCallback? onItalic;
  final VoidCallback? onUnderline;
  final VoidCallback? onToggleBullet;
  final VoidCallback? onMarker;
  final VoidCallback? onLink;
  final VoidCallback? onAttachFile;
  final VoidCallback? onScan;
  final VoidCallback? onPhotoLibrary;
  final VoidCallback? onTakePhoto;
  final VoidCallback? onVideo;
  final VoidCallback? onAudio;
  final VoidCallback? onAi;
  final bool boldSelected;
  final bool italicSelected;
  final bool underlineSelected;
  final bool bulletSelected;
  final bool markerSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, bottomPadding),
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 52.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: NotesTheme.isLight
                ? NotesTheme.surface.withValues(alpha: 0.98)
                : NotesTheme.charcoal.withValues(alpha: 0.94),
            border: Border.all(
              color: NotesTheme.bronze.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: NotesTheme.isLight ? 0.1 : 0.4),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            children: [
              NotesComposerToolbarIcon(
                icon: Icons.auto_awesome,
                tooltip: 'AI',
                onTap: enabled ? onAi : null,
              ),
              NotesComposerToolbarIcon(
                icon: Icons.mic_none_rounded,
                tooltip: 'Audio',
                onTap: enabled ? onAudio : null,
              ),
              NotesComposerToolbarIcon(
                icon: Icons.videocam_outlined,
                tooltip: 'Video',
                onTap: enabled ? onVideo : null,
              ),
              NotesComposerToolbarIcon(
                icon: Icons.photo_camera_outlined,
                tooltip: 'Take photo',
                onTap: enabled ? onTakePhoto : null,
              ),
              NotesComposerToolbarIcon(
                icon: Icons.photo_library_outlined,
                tooltip: 'Photo library',
                onTap: enabled ? onPhotoLibrary : null,
              ),
              NotesComposerToolbarIcon(
                icon: Icons.document_scanner_outlined,
                tooltip: 'Scan document',
                onTap: enabled ? onScan : null,
              ),
              NotesComposerToolbarIcon(
                icon: Icons.attach_file_rounded,
                tooltip: 'Attach file',
                onTap: enabled ? onAttachFile : null,
              ),
              NotesComposerToolbarIcon(
                icon: Icons.link_rounded,
                tooltip: 'Link',
                onTap: enabled ? onLink : null,
              ),
              NotesComposerToolbarIcon(
                icon: Icons.highlight_alt_rounded,
                tooltip: 'Marker',
                selected: markerSelected,
                onTap: enabled ? onMarker : null,
              ),
              NotesComposerToolbarIcon(
                icon: Icons.format_list_bulleted,
                tooltip: 'Bullets',
                selected: bulletSelected,
                onTap: enabled ? onToggleBullet : null,
              ),
              NotesComposerToolbarIcon(
                icon: Icons.format_underline,
                tooltip: 'Underline',
                selected: underlineSelected,
                onTap: enabled ? onUnderline : null,
              ),
              NotesComposerToolbarIcon(
                icon: Icons.format_italic,
                tooltip: 'Italic',
                selected: italicSelected,
                onTap: enabled ? onItalic : null,
              ),
              NotesComposerToolbarIcon(
                icon: Icons.format_bold,
                tooltip: 'Bold',
                selected: boldSelected,
                onTap: enabled ? onBold : null,
              ),
              NotesComposerToolbarIcon(
                icon: Icons.text_format_rounded,
                tooltip: 'Format',
                onTap: enabled ? onFormat : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotesComposerToolbarIcon extends StatelessWidget {
  const NotesComposerToolbarIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final activeColor = NotesTheme.isLight
        ? const Color(0xFF2C3E50)
        : NotesTheme.pureBlack;

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 6.h),
        child: Material(
          color: selected ? NotesTheme.bronze : Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 40.w,
              height: 40.w,
              child: Icon(
                icon,
                size: 22.sp,
                color: !enabled
                    ? NotesTheme.textPrimary.withValues(alpha: 0.28)
                    : selected
                        ? activeColor
                        : NotesTheme.textPrimary.withValues(alpha: 0.78),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/utils/notes_markdown_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui show TextDirection;

Future<void> showNotesFormatSheet(
  BuildContext context, {
  required TextEditingController contentController,
  TextAlign textAlign = TextAlign.start,
  ui.TextDirection textDirection = ui.TextDirection.ltr,
  ValueChanged<TextAlign>? onTextAlignChanged,
  ValueChanged<ui.TextDirection>? onTextDirectionChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: NotesTheme.surface,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (ctx) {
      return _NotesFormatSheetBody(
        contentController: contentController,
        initialAlign: textAlign,
        initialDirection: textDirection,
        onTextAlignChanged: onTextAlignChanged,
        onTextDirectionChanged: onTextDirectionChanged,
      );
    },
  );
}

class _NotesFormatSheetBody extends StatefulWidget {
  const _NotesFormatSheetBody({
    required this.contentController,
    required this.initialAlign,
    required this.initialDirection,
    this.onTextAlignChanged,
    this.onTextDirectionChanged,
  });

  final TextEditingController contentController;
  final TextAlign initialAlign;
  final ui.TextDirection initialDirection;
  final ValueChanged<TextAlign>? onTextAlignChanged;
  final ValueChanged<ui.TextDirection>? onTextDirectionChanged;

  @override
  State<_NotesFormatSheetBody> createState() => _NotesFormatSheetBodyState();
}

class _NotesFormatSheetBodyState extends State<_NotesFormatSheetBody> {
  late TextAlign _align;
  late ui.TextDirection _direction;
  late int _headingLevel;

  @override
  void initState() {
    super.initState();
    _align = widget.initialAlign;
    _direction = widget.initialDirection;
    _headingLevel =
        NotesMarkdownFormat.currentHeadingLevel(widget.contentController);
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Format',
                  style: GoogleFonts.poppins(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: NotesTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Material(
                  color: NotesTheme.textPrimary.withValues(alpha: 0.08),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: EdgeInsets.all(8.w),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18.sp,
                        color: NotesTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            // Title / Heading / Subheading / Body
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StyleChip(
                    label: 'Title',
                    selected: _headingLevel == 1,
                    onTap: () {
                      NotesMarkdownFormat.headingLevel(
                          widget.contentController, 1);
                      setState(() => _headingLevel = 1);
                    },
                  ),
                  SizedBox(width: 8.w),
                  _StyleChip(
                    label: 'Heading',
                    selected: _headingLevel == 2,
                    onTap: () {
                      NotesMarkdownFormat.headingLevel(
                          widget.contentController, 2);
                      setState(() => _headingLevel = 2);
                    },
                  ),
                  SizedBox(width: 8.w),
                  _StyleChip(
                    label: 'Subheading',
                    selected: _headingLevel == 3,
                    onTap: () {
                      NotesMarkdownFormat.headingLevel(
                          widget.contentController, 3);
                      setState(() => _headingLevel = 3);
                    },
                  ),
                  SizedBox(width: 8.w),
                  _StyleChip(
                    label: 'Body',
                    selected: _headingLevel == 0,
                    onTap: () {
                      NotesMarkdownFormat.headingLevel(
                          widget.contentController, 0);
                      setState(() => _headingLevel = 0);
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),
            // Bold / Italic / Underline / Strike
            Row(
              children: [
                _SegGroup(
                  children: [
                    _SegIcon(
                      selected: false,
                      onTap: () {
                        NotesMarkdownFormat.bold(widget.contentController);
                        _refresh();
                      },
                      child: Text(
                        'B',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 16.sp,
                          color: NotesTheme.textPrimary,
                        ),
                      ),
                    ),
                    _SegIcon(
                      selected: false,
                      onTap: () {
                        NotesMarkdownFormat.italic(widget.contentController);
                        _refresh();
                      },
                      child: Text(
                        'I',
                        style: GoogleFonts.poppins(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          fontSize: 16.sp,
                          color: NotesTheme.textPrimary,
                        ),
                      ),
                    ),
                    _SegIcon(
                      selected: false,
                      onTap: () {
                        NotesMarkdownFormat.underline(widget.contentController);
                        _refresh();
                      },
                      child: Text(
                        'U',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16.sp,
                          decoration: TextDecoration.underline,
                          color: NotesTheme.textPrimary,
                        ),
                      ),
                    ),
                    _SegIcon(
                      selected: false,
                      onTap: () {
                        NotesMarkdownFormat.strikethrough(
                            widget.contentController);
                        _refresh();
                      },
                      child: Text(
                        'S',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16.sp,
                          decoration: TextDecoration.lineThrough,
                          color: NotesTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 10.w),
                _RoundIcon(
                  icon: Icons.edit_rounded,
                  color: NotesTheme.bronze,
                  onTap: () {
                    NotesMarkdownFormat.highlight(widget.contentController);
                    _refresh();
                  },
                ),
                SizedBox(width: 8.w),
                _RoundIcon(
                  icon: Icons.circle,
                  color: NotesTheme.bronze,
                  onTap: () {
                    NotesMarkdownFormat.highlight(widget.contentController);
                    _refresh();
                  },
                ),
              ],
            ),
            SizedBox(height: 14.h),
            // Lists + alignment + RTL/LTR
            Row(
              children: [
                _SegGroup(
                  children: [
                    _SegIcon(
                      selected: NotesMarkdownFormat.isBulletLine(
                          widget.contentController),
                      onTap: () {
                        NotesMarkdownFormat.toggleBullet(
                            widget.contentController);
                        _refresh();
                      },
                      child: Icon(
                        Icons.format_list_bulleted,
                        size: 20.sp,
                        color: NotesTheme.textPrimary,
                      ),
                    ),
                    _SegIcon(
                      selected: false,
                      onTap: () {
                        NotesMarkdownFormat.checklist(
                            widget.contentController);
                        _refresh();
                      },
                      child: Icon(
                        Icons.checklist_rounded,
                        size: 20.sp,
                        color: NotesTheme.textPrimary,
                      ),
                    ),
                    _SegIcon(
                      selected: false,
                      onTap: () {
                        NotesMarkdownFormat.numberedList(
                            widget.contentController);
                        _refresh();
                      },
                      child: Icon(
                        Icons.format_list_numbered,
                        size: 20.sp,
                        color: NotesTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 10.w),
                _SegGroup(
                  children: [
                    _SegIcon(
                      selected: _align == TextAlign.left ||
                          _align == TextAlign.start,
                      onTap: () {
                        setState(() => _align = TextAlign.left);
                        widget.onTextAlignChanged?.call(TextAlign.left);
                      },
                      child: Icon(
                        Icons.format_align_left,
                        size: 20.sp,
                        color: NotesTheme.textPrimary,
                      ),
                    ),
                    _SegIcon(
                      selected: _align == TextAlign.center,
                      onTap: () {
                        setState(() => _align = TextAlign.center);
                        widget.onTextAlignChanged?.call(TextAlign.center);
                      },
                      child: Icon(
                        Icons.format_align_center,
                        size: 20.sp,
                        color: NotesTheme.textPrimary,
                      ),
                    ),
                    _SegIcon(
                      selected: _align == TextAlign.right ||
                          _align == TextAlign.end,
                      onTap: () {
                        setState(() => _align = TextAlign.right);
                        widget.onTextAlignChanged?.call(TextAlign.right);
                      },
                      child: Icon(
                        Icons.format_align_right,
                        size: 20.sp,
                        color: NotesTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 10.w),
                _SegGroup(
                  children: [
                    _SegIcon(
                      selected: _direction == ui.TextDirection.ltr,
                      onTap: () {
                        setState(() => _direction = ui.TextDirection.ltr);
                        widget.onTextDirectionChanged
                            ?.call(ui.TextDirection.ltr);
                      },
                      child: Text(
                        'LTR',
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: NotesTheme.textPrimary,
                        ),
                      ),
                    ),
                    _SegIcon(
                      selected: _direction == ui.TextDirection.rtl,
                      onTap: () {
                        setState(() => _direction = ui.TextDirection.rtl);
                        widget.onTextDirectionChanged
                            ?.call(ui.TextDirection.rtl);
                      },
                      child: Text(
                        'RTL',
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: NotesTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? NotesTheme.bronze : NotesTheme.glassFill,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: selected
                  ? NotesTheme.bronze
                  : NotesTheme.glassBorder,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: selected
                  ? (NotesTheme.isLight
                      ? const Color(0xFF2C3E50)
                      : NotesTheme.pureBlack)
                  : NotesTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SegGroup extends StatelessWidget {
  const _SegGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: NotesTheme.glassFill,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: NotesTheme.glassBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _SegIcon extends StatelessWidget {
  const _SegIcon({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? NotesTheme.bronze : Colors.transparent,
      borderRadius: BorderRadius.circular(10.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          width: 40.w,
          height: 36.h,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NotesTheme.glassFill,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40.w,
          height: 40.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: NotesTheme.glassBorder),
          ),
          child: Icon(icon, size: 18.sp, color: color),
        ),
      ),
    );
  }
}

import 'package:el_race/core/drawing_studio/drawing_studio_config.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

InputDecoration studioFieldDecoration({
  required String label,
  String? errorText,
  String? helperText,
}) {
  return InputDecoration(
    labelText: label,
    errorText: errorText,
    helperText: helperText,
    filled: true,
    fillColor: const Color(0xFFF2F4F8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.ur),
      borderSide: BorderSide.none,
    ),
    labelStyle: GoogleFonts.poppins(
      fontSize: 12.usp,
      fontWeight: FontWeight.w500,
      color: const Color(0xFF7A849C),
    ),
  );
}

/// Collapsed section row — tap opens a smart popup editor.
class StudioSectionTile extends StatelessWidget {
  const StudioSectionTile({
    super.key,
    required this.title,
    required this.summary,
    required this.onTap,
    this.hasError = false,
  });

  final String title;
  final String summary;
  final VoidCallback onTap;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.uh),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.ur),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.ur),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.uh),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.ur),
              border: Border.all(
                color: hasError
                    ? const Color(0xFFE63946).withValues(alpha: 0.55)
                    : const Color(0xFFE4E8F0),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5.usp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A2A4F),
                        ),
                      ),
                      SizedBox(height: 3.uh),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5.usp,
                          fontWeight: FontWeight.w500,
                          color: hasError
                              ? const Color(0xFFE63946)
                              : const Color(0xFF7A849C),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(
                  Icons.edit_outlined,
                  color: const Color(0xFFB0BAC8),
                  size: 20.usp,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showStudioSmartPopup<T>({
  required BuildContext context,
  required String title,
  required Widget Function(BuildContext context, VoidCallback close) builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, anim, secondary) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.uh),
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 420.w,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.78,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18.ur),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(16.w, 14.uh, 8.w, 8.uh),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.poppins(
                                  fontSize: 15.usp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A2A4F),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE4E8F0)),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(16.w, 12.uh, 16.w, 8.uh),
                          child: builder(
                            context,
                            () => Navigator.of(context).maybePop(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim, secondary, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class StudioEnumDropdown extends StatelessWidget {
  const StudioEnumDropdown({
    super.key,
    required this.config,
    required this.enumField,
    required this.value,
    required this.label,
    required this.onChanged,
    this.errorText,
    this.fallbackKeys = const [],
  });

  final DrawingStudioConfig config;
  final String enumField;
  final String value;
  final String label;
  final ValueChanged<String> onChanged;
  final String? errorText;
  final List<String> fallbackKeys;

  @override
  Widget build(BuildContext context) {
    var keys = config.enumKeys(enumField);
    if (keys.isEmpty) keys = fallbackKeys;
    if (keys.isEmpty) keys = [value];
    final selected = keys.contains(value) ? value : keys.first;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.uh),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$enumField-$selected'),
        isExpanded: true,
        initialValue: selected,
        decoration: studioFieldDecoration(label: label, errorText: errorText),
        selectedItemBuilder: (context) {
          return [
            for (final key in keys)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  config.enumLabel(enumField, key),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ];
        },
        items: [
          for (final key in keys)
            DropdownMenuItem(
              value: key,
              child: Text(
                config.enumLabel(enumField, key),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class StudioChipMultiSelect extends StatelessWidget {
  const StudioChipMultiSelect({
    super.key,
    required this.config,
    required this.enumField,
    required this.selected,
    required this.onChanged,
    this.fallbackKeys = const [],
    this.errorText,
  });

  final DrawingStudioConfig config;
  final String enumField;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final List<String> fallbackKeys;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    var keys = config.enumKeys(enumField);
    if (keys.isEmpty) keys = fallbackKeys;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8.w,
          runSpacing: 8.uh,
          children: [
            for (final key in keys)
              FilterChip(
                selected: selected.contains(key),
                label: Text(config.enumLabel(enumField, key)),
                onSelected: (on) {
                  final next = [...selected];
                  if (on) {
                    if (!next.contains(key)) next.add(key);
                  } else {
                    next.remove(key);
                  }
                  onChanged(next);
                },
              ),
          ],
        ),
        if (errorText != null) ...[
          SizedBox(height: 6.uh),
          Text(
            errorText!,
            style: GoogleFonts.poppins(
              fontSize: 11.usp,
              color: const Color(0xFFE63946),
            ),
          ),
        ],
      ],
    );
  }
}

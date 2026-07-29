import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Large stacked "My" / "Notes" page title from the design mock.
class NotesPageHeading extends StatelessWidget {
  const NotesPageHeading({super.key});

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.poppins(
      fontSize: 40.sp,
      fontWeight: FontWeight.w700,
      color: NotesTheme.textPrimary,
      height: 1.05,
      letterSpacing: -0.5,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My', style: style),
          Text('Notes', style: style),
        ],
      ),
    );
  }
}

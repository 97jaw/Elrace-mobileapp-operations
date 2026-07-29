import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_bottom_nav_bar.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_capture_grid.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_filter_chips.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_list_section.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_page_heading.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_royal_bronze_background.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// My Notes first screen — heading, tags, capture grid, notes list, bottom bar.
class MyNotesScreen extends StatefulWidget {
  const MyNotesScreen({super.key});

  @override
  State<MyNotesScreen> createState() => _MyNotesScreenState();
}

class _MyNotesScreenState extends State<MyNotesScreen> {
  int _selectedFilter = 0;
  NotesBottomNavTab _bottomTab = NotesBottomNavTab.home;

  @override
  Widget build(BuildContext context) {
    final bottomPad = context.systemBottomInset;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: NotesTheme.pureBlack,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: NotesRoyalBronzeBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ContextualGlassChromeHeader(
                showBack: false,
                onLightSurface: false,
                scrimColor: NotesTheme.pureBlack,
                scrimTopOpacity: 0.22,
                transparentGlassBar: true,
                titleColor: NotesTheme.textPrimary,
              ),
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        0,
                        8.h,
                        0,
                        bottomPad + 88.h,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const NotesPageHeading(),
                          SizedBox(height: 16.h),
                          NotesFilterChips(
                            selectedIndex: _selectedFilter,
                            onSelected: (index) {
                              setState(() => _selectedFilter = index);
                            },
                          ),
                          SizedBox(height: 20.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: NotesCaptureGrid(
                              onStartRecording: () {},
                              onNewTextNote: () {},
                              onImageNotes: () {},
                            ),
                          ),
                          SizedBox(height: 28.h),
                          NotesListSection(
                            onViewAll: () {},
                            onNoteTap: (_) {},
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 28.w,
                      right: 28.w,
                      bottom: bottomPad + 12.h,
                      child: NotesBottomNavBar(
                        selected: _bottomTab,
                        onSelected: (tab) {
                          setState(() => _bottomTab = tab);
                        },
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
}

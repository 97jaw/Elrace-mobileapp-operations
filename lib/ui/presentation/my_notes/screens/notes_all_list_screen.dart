import 'package:el_race/ui/presentation/my_notes/bloc/notes_bloc.dart';
import 'package:el_race/ui/presentation/my_notes/data/note_model.dart';
import 'package:el_race/ui/presentation/my_notes/screens/note_detail_screen.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme_controller.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_bottom_nav_bar.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_list_section.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_royal_bronze_background.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full notes list with floating search (opened from home "View all").
class NotesAllListScreen extends StatefulWidget {
  const NotesAllListScreen({super.key});

  @override
  State<NotesAllListScreen> createState() => _NotesAllListScreenState();
}

class _NotesAllListScreenState extends State<NotesAllListScreen> {
  @override
  void initState() {
    super.initState();
    NotesThemeController.instance.addListener(_onNotesThemeChanged);
  }

  void _onNotesThemeChanged() {
    if (!mounted) return;
    setState(() {});
    SystemChrome.setSystemUIOverlayStyle(NotesTheme.systemOverlay);
  }

  @override
  void dispose() {
    NotesThemeController.instance.removeListener(_onNotesThemeChanged);
    super.dispose();
  }

  void _onSearchQueryChanged(String query) {
    final bloc = context.read<NotesBloc>();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      bloc.add(const ClearSearch());
    } else {
      bloc.add(SearchNotes(trimmed));
    }
  }

  void _onNoteTap(NoteModel note) {
    final notesBloc = context.read<NotesBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: notesBloc,
          child: NoteDetailScreen(note: note),
        ),
      ),
    );
  }

  NotesState _resolveDisplayState(NotesState state) {
    if (state is NoteActionLoading && state.previousState != null) {
      return state.previousState!;
    }
    if (state is NoteActionError && state.previousState != null) {
      return state.previousState!;
    }
    return state;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = context.systemBottomInset;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: NotesTheme.systemOverlay,
      child: NotesRoyalBronzeBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ContextualGlassChromeHeader(
                showBack: true,
                onBack: () => Navigator.of(context).maybePop(),
                onLightSurface: NotesTheme.isLight,
                scrimColor: NotesTheme.canvas,
                scrimTopOpacity: NotesTheme.isLight ? 0.08 : 0.22,
                transparentGlassBar: true,
                titleColor: NotesTheme.textPrimary,
              ),
              Expanded(
                child: Stack(
                  children: [
                    BlocBuilder<NotesBloc, NotesState>(
                      builder: (context, state) {
                        final displayState = _resolveDisplayState(state);
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            0,
                            8.h,
                            0,
                            bottomPad + 80.h,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding:
                                    EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 12.h),
                                child: Text(
                                  'All notes',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24.sp,
                                    fontWeight: FontWeight.w700,
                                    color: NotesTheme.textPrimary,
                                  ),
                                ),
                              ),
                              _buildNotesSection(displayState),
                            ],
                          ),
                        );
                      },
                    ),
                    Positioned(
                      left: 20.w,
                      right: 20.w,
                      bottom: bottomPad + 12.h,
                      child: NotesFloatingSearchBar(
                        onQueryChanged: _onSearchQueryChanged,
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

  Widget _buildNotesSection(NotesState state) {
    if (state is NotesLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
        child: const Center(
          child: CircularProgressIndicator(color: NotesTheme.bronze),
        ),
      );
    }

    if (state is NotesError) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                size: 48.sp,
                color: NotesTheme.textPrimary.withValues(alpha: 0.5),
              ),
              SizedBox(height: 12.h),
              Text(
                state.message.contains('permission-denied')
                    ? 'Permission denied.\nDeploy Firestore notes rules, then Retry.'
                    : 'Failed to load notes',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: NotesTheme.textPrimary.withValues(alpha: 0.7),
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 8.h),
              TextButton(
                onPressed: () {
                  context.read<NotesBloc>().add(const WatchNotes());
                },
                child: const Text(
                  'Retry',
                  style: TextStyle(color: NotesTheme.bronze),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state is NotesLoaded) {
      if (state.notes.isEmpty) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
          child: Center(
            child: Column(
              children: [
                Icon(
                  state.isSearching
                      ? Icons.search_off_rounded
                      : Icons.note_add_outlined,
                  size: 56.sp,
                  color: NotesTheme.textPrimary.withValues(alpha: 0.3),
                ),
                SizedBox(height: 16.h),
                Text(
                  state.isSearching
                      ? 'No notes match your search'
                      : 'No notes yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: NotesTheme.textPrimary.withValues(alpha: 0.5),
                    fontSize: 14.sp,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return NotesListSection(
        notes: state.notes,
        title: state.isSearching ? 'Search results' : 'All Notes',
        showAll: true,
        onNoteTap: _onNoteTap,
      );
    }

    return const SizedBox.shrink();
  }
}

import 'package:el_race/ui/presentation/my_notes/bloc/notes_bloc.dart';
import 'package:el_race/ui/presentation/my_notes/data/note_model.dart';
import 'package:el_race/ui/presentation/my_notes/repository/firebase_notes_repository.dart';
import 'package:el_race/ui/presentation/my_notes/repository/i_notes_repository.dart';
import 'package:el_race/ui/presentation/my_notes/screens/add_note_screen.dart';
import 'package:el_race/ui/presentation/my_notes/screens/note_detail_screen.dart';
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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MyNotesScreen extends StatelessWidget {
  const MyNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotesBloc(
        notesRepository: FirebaseNotesRepository(),
      )..add(const WatchNotes()),
      child: const _MyNotesView(),
    );
  }
}

class _MyNotesView extends StatefulWidget {
  const _MyNotesView();

  @override
  State<_MyNotesView> createState() => _MyNotesViewState();
}

class _MyNotesViewState extends State<_MyNotesView> {
  NotesBottomNavTab _bottomTab = NotesBottomNavTab.home;

  int _filterToIndex(NotesFilter filter) {
    switch (filter) {
      case NotesFilter.all:
        return 0;
      case NotesFilter.important:
        return 1;
      case NotesFilter.todo:
        return 2;
    }
  }

  NotesFilter _indexToFilter(int index) {
    switch (index) {
      case 1:
        return NotesFilter.important;
      case 2:
        return NotesFilter.todo;
      default:
        return NotesFilter.all;
    }
  }

  void _onFilterSelected(int index) {
    final filter = _indexToFilter(index);
    context.read<NotesBloc>().add(FilterNotes(filter));
  }

  void _onNewTextNote() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: context.read<NotesBloc>(),
          child: const AddNoteScreen(),
        ),
      ),
    );
  }

  void _onStartRecording() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Audio recording coming in Release 2'),
        backgroundColor: NotesTheme.charcoal,
      ),
    );
  }

  void _onImageNotes() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image notes coming in Release 3'),
        backgroundColor: NotesTheme.charcoal,
      ),
    );
  }

  void _onNoteTap(NoteModel note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: this.context.read<NotesBloc>(),
          child: NoteDetailScreen(note: note),
        ),
      ),
    );
  }

  void _onViewAllNotes() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('View all notes'),
        backgroundColor: NotesTheme.charcoal,
      ),
    );
  }

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
                    BlocConsumer<NotesBloc, NotesState>(
                      listener: (context, state) {
                        if (state is NotesError) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                state.message.contains('permission-denied')
                                    ? 'Notes access denied. Deploy Firestore rules for /users/{uid}/notes.'
                                    : state.message,
                              ),
                              backgroundColor: NotesTheme.charcoal,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        } else if (state is NoteActionError) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(state.message),
                              backgroundColor: NotesTheme.charcoal,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        } else if (state is NoteActionSuccess &&
                            state.message != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(state.message!),
                              backgroundColor: NotesTheme.charcoal,
                            ),
                          );
                        }
                      },
                      builder: (context, state) {
                        final displayState = _resolveDisplayState(state);
                        return SingleChildScrollView(
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
                              _buildFilterChips(displayState),
                              SizedBox(height: 20.h),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20.w),
                                child: NotesCaptureGrid(
                                  onStartRecording: _onStartRecording,
                                  onNewTextNote: _onNewTextNote,
                                  onImageNotes: _onImageNotes,
                                ),
                              ),
                              SizedBox(height: 28.h),
                              _buildNotesSection(displayState),
                            ],
                          ),
                        );
                      },
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

  NotesState _resolveDisplayState(NotesState state) {
    if (state is NoteActionLoading && state.previousState != null) {
      return state.previousState!;
    }
    if (state is NoteActionError && state.previousState != null) {
      return state.previousState!;
    }
    if (state is NoteActionSuccess) {
      // Stream will refresh; keep last loaded view if available.
      return state;
    }
    return state;
  }

  Widget _buildFilterChips(NotesState state) {
    int selectedIndex = 0;
    int totalCount = 0;
    int importantCount = 0;
    int todoCount = 0;

    if (state is NotesLoaded) {
      selectedIndex = _filterToIndex(state.currentFilter);
      totalCount = state.totalCount;
      importantCount = state.importantCount;
      todoCount = state.todoCount;
    }

    return NotesFilterChips(
      selectedIndex: selectedIndex,
      onSelected: _onFilterSelected,
      options: [
        NotesFilterOption(label: 'All', count: totalCount > 0 ? totalCount : null),
        NotesFilterOption(label: 'Important', count: importantCount > 0 ? importantCount : null),
        NotesFilterOption(label: 'To-do', count: todoCount > 0 ? todoCount : null),
      ],
    );
  }

  Widget _buildNotesSection(NotesState state) {
    if (state is NotesLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
        child: const Center(
          child: CircularProgressIndicator(
            color: NotesTheme.bronze,
          ),
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
        return _buildEmptyState(state.currentFilter);
      }

      return NotesListSection(
        notes: state.notes,
        onViewAll: _onViewAllNotes,
        onNoteTap: _onNoteTap,
      );
    }

    // NoteActionSuccess / transient states — show empty placeholder, not spinner.
    return _buildEmptyState(NotesFilter.all);
  }

  Widget _buildEmptyState(NotesFilter filter) {
    String message;
    IconData icon;

    switch (filter) {
      case NotesFilter.important:
        message = 'No important notes yet';
        icon = Icons.star_outline;
        break;
      case NotesFilter.todo:
        message = 'No to-do notes yet';
        icon = Icons.check_circle_outline;
        break;
      case NotesFilter.all:
      default:
        message = 'No notes yet\nTap above to create your first note';
        icon = Icons.note_add_outlined;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              size: 56.sp,
              color: NotesTheme.textPrimary.withValues(alpha: 0.3),
            ),
            SizedBox(height: 16.h),
            Text(
              message,
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
}

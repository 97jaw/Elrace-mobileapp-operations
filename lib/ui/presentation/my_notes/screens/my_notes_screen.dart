import 'package:el_race/ui/presentation/my_notes/bloc/notes_bloc.dart';
import 'package:el_race/ui/presentation/my_notes/data/note_model.dart';
import 'package:el_race/ui/presentation/my_notes/screens/add_note_screen.dart';
import 'package:el_race/ui/presentation/my_notes/screens/note_detail_screen.dart';
import 'package:el_race/ui/presentation/my_notes/screens/notes_all_list_screen.dart';
import 'package:el_race/ui/presentation/my_notes/screens/notes_templates_stub_screen.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme_controller.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_capture_grid.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_list_section.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_page_heading.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_royal_bronze_background.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Uses the app-level [NotesBloc] from [MultiBlocProvider] so list + add/edit
/// always share the same Firebase-backed instance.
class MyNotesScreen extends StatefulWidget {
  const MyNotesScreen({super.key});

  @override
  State<MyNotesScreen> createState() => _MyNotesScreenState();
}

class _MyNotesScreenState extends State<MyNotesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotesBloc>().add(const WatchNotes());
    });
  }

  @override
  Widget build(BuildContext context) {
    return const _MyNotesView();
  }
}

class _MyNotesView extends StatefulWidget {
  const _MyNotesView();

  @override
  State<_MyNotesView> createState() => _MyNotesViewState();
}

class _MyNotesViewState extends State<_MyNotesView> {
  @override
  void initState() {
    super.initState();
    NotesThemeController.instance.ensureLoaded();
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

  void _onCreateNote() {
    final notesBloc = context.read<NotesBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: notesBloc,
          child: const AddNoteScreen(),
        ),
      ),
    );
  }

  void _onScanNotes() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Coming soon'),
        backgroundColor: NotesTheme.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onImageNotes() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotesTemplatesStubScreen(),
      ),
    );
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

  Future<void> _onViewAllNotes() async {
    final notesBloc = context.read<NotesBloc>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: notesBloc,
          child: const NotesAllListScreen(),
        ),
      ),
    );
    if (!mounted) return;
    notesBloc.add(const ClearSearch());
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
                showBack: false,
                onLightSurface: NotesTheme.isLight,
                scrimColor: NotesTheme.canvas,
                scrimTopOpacity: NotesTheme.isLight ? 0.08 : 0.22,
                transparentGlassBar: true,
                titleColor: NotesTheme.textPrimary,
              ),
              Expanded(
                child: BlocConsumer<NotesBloc, NotesState>(
                  listener: (context, state) {
                    if (state is NotesError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            state.message.contains('permission-denied')
                                ? 'Notes access denied. Deploy Firestore rules for /users/{uid}/notes.'
                                : state.message,
                          ),
                          backgroundColor: NotesTheme.surface,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    } else if (state is NoteActionError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: NotesTheme.surface,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  },
                  builder: (context, state) {
                    final displayState = _resolveDisplayState(state);
                    return _buildHome(displayState, bottomPad);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHome(NotesState displayState, double bottomPad) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(0, 8.h, 0, bottomPad + 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const NotesPageHeading(),
          SizedBox(height: 20.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: NotesCaptureGrid(
              onCreateNote: _onCreateNote,
              onScanNotes: _onScanNotes,
              onImageNotes: _onImageNotes,
            ),
          ),
          SizedBox(height: 28.h),
          _buildNotesSection(displayState),
        ],
      ),
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
        return _buildEmptyState();
      }

      return NotesListSection(
        notes: state.notes,
        title: 'Recent',
        showAll: false,
        maxItems: 5,
        onViewAll: _onViewAllNotes,
        onNoteTap: _onNoteTap,
      );
    }

    return _buildEmptyState();
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.note_add_outlined,
              size: 56.sp,
              color: NotesTheme.textPrimary.withValues(alpha: 0.3),
            ),
            SizedBox(height: 16.h),
            Text(
              'No notes yet\nTap Create your note to get started',
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

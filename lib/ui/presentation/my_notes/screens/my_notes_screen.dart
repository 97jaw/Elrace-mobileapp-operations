import 'dart:async';

import 'package:el_race/ui/presentation/my_notes/bloc/notes_bloc.dart';
import 'package:el_race/ui/presentation/my_notes/data/note_model.dart';
import 'package:el_race/ui/presentation/my_notes/repository/firebase_notes_repository.dart';
import 'package:el_race/ui/presentation/my_notes/screens/add_note_screen.dart';
import 'package:el_race/ui/presentation/my_notes/screens/audio_recording_screen.dart';
import 'package:el_race/ui/presentation/my_notes/screens/note_detail_screen.dart';
import 'package:el_race/ui/presentation/my_notes/screens/notes_templates_stub_screen.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme_controller.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_bottom_nav_bar.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_capture_grid.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_glass_card.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_list_section.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_page_heading.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_royal_bronze_background.dart';
import 'package:el_race/ui/widgets/contextual_glass_chrome_header.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

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
  NotesBottomNavTab _bottomTab = NotesBottomNavTab.home;
  final FirebaseNotesRepository _repo = FirebaseNotesRepository();
  List<SharedNoteRef> _sharedRefs = [];
  StreamSubscription<List<SharedNoteRef>>? _sharedSub;

  @override
  void initState() {
    super.initState();
    NotesThemeController.instance.ensureLoaded();
    NotesThemeController.instance.addListener(_onNotesThemeChanged);
    _sharedSub = _repo.watchSharedWithMe().listen((refs) {
      if (!mounted) return;
      setState(() => _sharedRefs = refs);
    });
  }

  void _onNotesThemeChanged() {
    if (!mounted) return;
    // Rebuild header / system chrome / body that bake theme into ctor args.
    setState(() {});
    SystemChrome.setSystemUIOverlayStyle(NotesTheme.systemOverlay);
  }

  @override
  void dispose() {
    NotesThemeController.instance.removeListener(_onNotesThemeChanged);
    _sharedSub?.cancel();
    super.dispose();
  }

  void _onNewTextNote() {
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

  void _onStartRecording() {
    final notesBloc = context.read<NotesBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: notesBloc,
          child: const AudioRecordingScreen(),
        ),
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

  Future<void> _onSharedRefTap(SharedNoteRef ref) async {
    final notesBloc = context.read<NotesBloc>();
    try {
      final note = await _repo.getSharedNote(
        ownerId: ref.ownerId,
        noteId: ref.noteId,
      );
      if (!mounted || note == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared note not found'),
            backgroundColor: NotesTheme.surface,
          ),
        );
        return;
      }
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: notesBloc,
            child: NoteDetailScreen(note: note, readOnly: true),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open shared note: $e'),
          backgroundColor: NotesTheme.surface,
        ),
      );
    }
  }

  void _onViewAllNotes() {
    setState(() => _bottomTab = NotesBottomNavTab.list);
  }

  void _onCreateTap() {
    _onNewTextNote();
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
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: KeyedSubtree(
                            key: ValueKey(_bottomTab),
                            child: _buildTabBody(displayState, bottomPad),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      left: 20.w,
                      right: 20.w,
                      bottom: bottomPad + 12.h,
                      child: NotesBottomNavBar(
                        selected: _bottomTab,
                        onSelected: (tab) {
                          setState(() => _bottomTab = tab);
                        },
                        onCreateTap: _onCreateTap,
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

  Widget _buildTabBody(NotesState displayState, double bottomPad) {
    switch (_bottomTab) {
      case NotesBottomNavTab.home:
        return _buildHomeTab(displayState, bottomPad);
      case NotesBottomNavTab.list:
        return _buildListTab(displayState, bottomPad);
      case NotesBottomNavTab.shared:
        return _buildSharedTab(bottomPad);
    }
  }

  Widget _buildHomeTab(NotesState displayState, double bottomPad) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(0, 8.h, 0, bottomPad + 96.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const NotesPageHeading(),
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
          _buildNotesSection(displayState, preview: true),
        ],
      ),
    );
  }

  Widget _buildListTab(NotesState displayState, double bottomPad) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(0, 8.h, 0, bottomPad + 96.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 12.h),
            child: Text(
              'All notes',
              style: GoogleFonts.poppins(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: NotesTheme.textPrimary,
              ),
            ),
          ),
          _buildNotesSection(displayState, preview: false),
        ],
      ),
    );
  }

  Widget _buildSharedTab(double bottomPad) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, bottomPad + 96.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Shared with me',
            style: GoogleFonts.poppins(
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
              color: NotesTheme.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Notes others shared with you · view only',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              color: NotesTheme.textPrimary.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: 16.h),
          if (_sharedRefs.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 48.h),
              child: Column(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 56.sp,
                    color: NotesTheme.textPrimary.withValues(alpha: 0.3),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'No shared notes yet',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: NotesTheme.textPrimary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._sharedRefs.map((ref) {
              return Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: GestureDetector(
                  onTap: () => _onSharedRefTap(ref),
                  child: NotesGlassCard(
                    padding: EdgeInsets.all(14.w),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_shared_outlined,
                          color: NotesTheme.bronze,
                          size: 22.sp,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ref.title,
                                style: GoogleFonts.poppins(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: NotesTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'View only',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.sp,
                                  color: NotesTheme.textPrimary
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color:
                              NotesTheme.textPrimary.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildNotesSection(NotesState state, {required bool preview}) {
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
        title: preview ? 'Recent' : 'All Notes',
        showAll: !preview,
        maxItems: 5,
        onViewAll: preview ? _onViewAllNotes : null,
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
              'No notes yet\nTap + to create your first note',
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

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/note_model.dart';
import '../repository/i_notes_repository.dart';

part 'notes_event.dart';
part 'notes_state.dart';

class NotesBloc extends Bloc<NotesEvent, NotesState> {
  final INotesRepository notesRepository;
  StreamSubscription<List<NoteModel>>? _notesSubscription;
  NotesFilter _currentFilter = NotesFilter.all;

  static NotesBloc get(BuildContext context) => BlocProvider.of(context);

  NotesBloc({required this.notesRepository}) : super(NotesInitial()) {
    on<FetchNotes>(_fetchNotes);
    on<WatchNotes>(_watchNotes);
    on<StopWatchingNotes>(_stopWatchingNotes);
    on<FilterNotes>(_filterNotes);
    on<NotesUpdated>(_notesUpdated);
    on<AddNote>(_addNote);
    on<UpdateNote>(_updateNote);
    on<DeleteNote>(_deleteNote);
    on<ToggleNoteImportant>(_toggleImportant);
    on<ToggleNoteTodo>(_toggleTodo);
    on<SearchNotes>(_searchNotes);
    on<ClearSearch>(_clearSearch);
  }

  @override
  Future<void> close() {
    _notesSubscription?.cancel();
    return super.close();
  }

  Future<void> _fetchNotes(
    FetchNotes event,
    Emitter<NotesState> emit,
  ) async {
    try {
      emit(NotesLoading());
      _currentFilter = event.filter;

      final notes = await notesRepository.getNotes(filter: event.filter);
      final counts = await _getCounts();

      emit(NotesLoaded(
        notes: notes,
        currentFilter: event.filter,
        totalCount: counts['total']!,
        importantCount: counts['important']!,
        todoCount: counts['todo']!,
      ));
    } catch (e) {
      emit(NotesError(e.toString()));
    }
  }

  Future<void> _watchNotes(
    WatchNotes event,
    Emitter<NotesState> emit,
  ) async {
    try {
      emit(NotesLoading());
      _currentFilter = event.filter;

      await _notesSubscription?.cancel();

      _notesSubscription = notesRepository
          .watchNotes(filter: event.filter)
          .listen((notes) {
        add(NotesUpdated(notes));
      });
    } catch (e) {
      emit(NotesError(e.toString()));
    }
  }

  Future<void> _stopWatchingNotes(
    StopWatchingNotes event,
    Emitter<NotesState> emit,
  ) async {
    await _notesSubscription?.cancel();
    _notesSubscription = null;
  }

  Future<void> _filterNotes(
    FilterNotes event,
    Emitter<NotesState> emit,
  ) async {
    _currentFilter = event.filter;

    if (_notesSubscription != null) {
      add(WatchNotes(filter: event.filter));
    } else {
      add(FetchNotes(filter: event.filter));
    }
  }

  Future<void> _notesUpdated(
    NotesUpdated event,
    Emitter<NotesState> emit,
  ) async {
    try {
      final counts = await _getCounts();

      emit(NotesLoaded(
        notes: event.notes,
        currentFilter: _currentFilter,
        totalCount: counts['total']!,
        importantCount: counts['important']!,
        todoCount: counts['todo']!,
      ));
    } catch (e) {
      emit(NotesLoaded(
        notes: event.notes,
        currentFilter: _currentFilter,
      ));
    }
  }

  Future<void> _addNote(
    AddNote event,
    Emitter<NotesState> emit,
  ) async {
    final previousState = state is NotesLoaded ? state as NotesLoaded : null;

    try {
      emit(NoteActionLoading(previousState: previousState));
      await notesRepository.addNote(event.note);
      emit(const NoteActionSuccess(message: 'Note created'));

      if (_notesSubscription == null) {
        add(FetchNotes(filter: _currentFilter));
      }
    } catch (e) {
      emit(NoteActionError(e.toString(), previousState: previousState));
    }
  }

  Future<void> _updateNote(
    UpdateNote event,
    Emitter<NotesState> emit,
  ) async {
    final previousState = state is NotesLoaded ? state as NotesLoaded : null;

    try {
      emit(NoteActionLoading(previousState: previousState));
      await notesRepository.updateNote(event.note);
      emit(const NoteActionSuccess(message: 'Note updated'));

      if (_notesSubscription == null) {
        add(FetchNotes(filter: _currentFilter));
      }
    } catch (e) {
      emit(NoteActionError(e.toString(), previousState: previousState));
    }
  }

  Future<void> _deleteNote(
    DeleteNote event,
    Emitter<NotesState> emit,
  ) async {
    final previousState = state is NotesLoaded ? state as NotesLoaded : null;

    try {
      emit(NoteActionLoading(previousState: previousState));
      await notesRepository.deleteNote(event.noteId);
      emit(const NoteActionSuccess(message: 'Note deleted'));

      if (_notesSubscription == null) {
        add(FetchNotes(filter: _currentFilter));
      }
    } catch (e) {
      emit(NoteActionError(e.toString(), previousState: previousState));
    }
  }

  Future<void> _toggleImportant(
    ToggleNoteImportant event,
    Emitter<NotesState> emit,
  ) async {
    try {
      await notesRepository.toggleImportant(event.noteId, event.isImportant);

      if (_notesSubscription == null) {
        add(FetchNotes(filter: _currentFilter));
      }
    } catch (e) {
      emit(NotesError(e.toString()));
    }
  }

  Future<void> _toggleTodo(
    ToggleNoteTodo event,
    Emitter<NotesState> emit,
  ) async {
    try {
      await notesRepository.toggleTodo(event.noteId, event.isTodo);

      if (_notesSubscription == null) {
        add(FetchNotes(filter: _currentFilter));
      }
    } catch (e) {
      emit(NotesError(e.toString()));
    }
  }

  Future<void> _searchNotes(
    SearchNotes event,
    Emitter<NotesState> emit,
  ) async {
    if (state is! NotesLoaded) return;

    final currentState = state as NotesLoaded;

    if (event.query.isEmpty) {
      add(const ClearSearch());
      return;
    }

    try {
      final allNotes = await notesRepository.getNotes();
      final lowerQuery = event.query.toLowerCase();

      final filteredNotes = allNotes.where((note) {
        return note.title.toLowerCase().contains(lowerQuery) ||
            note.content.toLowerCase().contains(lowerQuery) ||
            note.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
      }).toList();

      emit(currentState.copyWith(
        notes: filteredNotes,
        isSearching: true,
        searchQuery: event.query,
      ));
    } catch (e) {
      emit(NotesError(e.toString()));
    }
  }

  Future<void> _clearSearch(
    ClearSearch event,
    Emitter<NotesState> emit,
  ) async {
    if (_notesSubscription != null) {
      add(WatchNotes(filter: _currentFilter));
    } else {
      add(FetchNotes(filter: _currentFilter));
    }
  }

  Future<Map<String, int>> _getCounts() async {
    try {
      final total = await notesRepository.getNotesCount();
      final important =
          await notesRepository.getNotesCount(filter: NotesFilter.important);
      final todo =
          await notesRepository.getNotesCount(filter: NotesFilter.todo);

      return {
        'total': total,
        'important': important,
        'todo': todo,
      };
    } catch (e) {
      return {'total': 0, 'important': 0, 'todo': 0};
    }
  }
}

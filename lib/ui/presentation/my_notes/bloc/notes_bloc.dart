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
  List<NoteModel> _allNotes = const [];

  static NotesBloc get(BuildContext context) => BlocProvider.of(context);

  NotesBloc({required this.notesRepository}) : super(NotesInitial()) {
    on<FetchNotes>(_fetchNotes);
    on<WatchNotes>(_watchNotes);
    on<StopWatchingNotes>(_stopWatchingNotes);
    on<FilterNotes>(_filterNotes);
    on<NotesUpdated>(_notesUpdated);
    on<NotesWatchFailed>(_notesWatchFailed);
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

  List<NoteModel> _filteredNotes(NotesFilter filter) {
    switch (filter) {
      case NotesFilter.important:
        return _allNotes.where((n) => n.isImportant).toList();
      case NotesFilter.todo:
        return _allNotes.where((n) => n.isTodo).toList();
      case NotesFilter.all:
        return List.from(_allNotes);
    }
  }

  NotesLoaded _buildLoaded({
    NotesFilter? filter,
    bool isSearching = false,
    String? searchQuery,
  }) {
    final activeFilter = filter ?? _currentFilter;
    return NotesLoaded(
      notes: _filteredNotes(activeFilter),
      currentFilter: activeFilter,
      totalCount: _allNotes.length,
      importantCount: _allNotes.where((n) => n.isImportant).length,
      todoCount: _allNotes.where((n) => n.isTodo).length,
      isSearching: isSearching,
      searchQuery: searchQuery,
    );
  }

  Future<void> _fetchNotes(
    FetchNotes event,
    Emitter<NotesState> emit,
  ) async {
    try {
      emit(NotesLoading());
      _currentFilter = event.filter;
      _allNotes = await notesRepository.getNotes(filter: NotesFilter.all);
      emit(_buildLoaded());
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
          .watchNotes(filter: NotesFilter.all)
          .listen(
        (notes) => add(NotesUpdated(notes)),
        onError: (Object error, StackTrace stackTrace) {
          add(NotesWatchFailed(error.toString()));
        },
      );
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
    if (_allNotes.isEmpty && state is! NotesLoaded) {
      add(WatchNotes(filter: event.filter));
      return;
    }
    emit(_buildLoaded());
  }

  Future<void> _notesUpdated(
    NotesUpdated event,
    Emitter<NotesState> emit,
  ) async {
    _allNotes = event.notes;
    emit(_buildLoaded());
  }

  Future<void> _notesWatchFailed(
    NotesWatchFailed event,
    Emitter<NotesState> emit,
  ) async {
    emit(NotesError(event.message));
  }

  Future<void> _addNote(
    AddNote event,
    Emitter<NotesState> emit,
  ) async {
    final previousState = state is NotesLoaded ? state as NotesLoaded : null;

    try {
      if (previousState != null) {
        emit(NoteActionLoading(previousState: previousState));
      }
      await notesRepository.addNote(event.note);

      // Optimistic local update so the list never blanks while waiting for stream.
      _allNotes = [
        event.note,
        ..._allNotes.where((n) => n.id != event.note.id),
      ];
      emit(_buildLoaded());
    } catch (e) {
      emit(NoteActionError(e.toString(), previousState: previousState));
      if (previousState != null) {
        emit(previousState);
      }
    }
  }

  Future<void> _updateNote(
    UpdateNote event,
    Emitter<NotesState> emit,
  ) async {
    final previousState = state is NotesLoaded ? state as NotesLoaded : null;

    try {
      if (previousState != null) {
        emit(NoteActionLoading(previousState: previousState));
      }
      await notesRepository.updateNote(event.note);

      _allNotes = _allNotes
          .map((n) => n.id == event.note.id ? event.note : n)
          .toList();
      // Keep newest-first order.
      _allNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      emit(_buildLoaded());
    } catch (e) {
      emit(NoteActionError(e.toString(), previousState: previousState));
      if (previousState != null) {
        emit(previousState);
      }
    }
  }

  Future<void> _deleteNote(
    DeleteNote event,
    Emitter<NotesState> emit,
  ) async {
    final previousState = state is NotesLoaded ? state as NotesLoaded : null;

    try {
      if (previousState != null) {
        emit(NoteActionLoading(previousState: previousState));
      }
      await notesRepository.deleteNote(event.noteId);

      _allNotes = _allNotes.where((n) => n.id != event.noteId).toList();
      emit(_buildLoaded());
    } catch (e) {
      emit(NoteActionError(e.toString(), previousState: previousState));
      if (previousState != null) {
        emit(previousState);
      }
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

    if (event.query.isEmpty) {
      add(const ClearSearch());
      return;
    }

    final lowerQuery = event.query.toLowerCase();
    final filteredNotes = _allNotes.where((note) {
      return note.title.toLowerCase().contains(lowerQuery) ||
          note.content.toLowerCase().contains(lowerQuery) ||
          note.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
    }).toList();

    emit(NotesLoaded(
      notes: filteredNotes,
      currentFilter: _currentFilter,
      totalCount: _allNotes.length,
      importantCount: _allNotes.where((n) => n.isImportant).length,
      todoCount: _allNotes.where((n) => n.isTodo).length,
      isSearching: true,
      searchQuery: event.query,
    ));
  }

  Future<void> _clearSearch(
    ClearSearch event,
    Emitter<NotesState> emit,
  ) async {
    emit(_buildLoaded());
  }
}

part of 'notes_bloc.dart';

sealed class NotesState extends Equatable {
  const NotesState();

  @override
  List<Object?> get props => [];
}

final class NotesInitial extends NotesState {}

final class NotesLoading extends NotesState {}

final class NotesLoaded extends NotesState {
  final List<NoteModel> notes;
  final NotesFilter currentFilter;
  final int totalCount;
  final int importantCount;
  final int todoCount;
  final bool isSearching;
  final String? searchQuery;

  const NotesLoaded({
    required this.notes,
    this.currentFilter = NotesFilter.all,
    this.totalCount = 0,
    this.importantCount = 0,
    this.todoCount = 0,
    this.isSearching = false,
    this.searchQuery,
  });

  NotesLoaded copyWith({
    List<NoteModel>? notes,
    NotesFilter? currentFilter,
    int? totalCount,
    int? importantCount,
    int? todoCount,
    bool? isSearching,
    String? searchQuery,
  }) {
    return NotesLoaded(
      notes: notes ?? this.notes,
      currentFilter: currentFilter ?? this.currentFilter,
      totalCount: totalCount ?? this.totalCount,
      importantCount: importantCount ?? this.importantCount,
      todoCount: todoCount ?? this.todoCount,
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
        notes,
        currentFilter,
        totalCount,
        importantCount,
        todoCount,
        isSearching,
        searchQuery,
      ];
}

final class NotesError extends NotesState {
  final String message;
  const NotesError(this.message);

  @override
  List<Object?> get props => [message];
}

final class NoteActionLoading extends NotesState {
  final NotesLoaded? previousState;
  const NoteActionLoading({this.previousState});

  @override
  List<Object?> get props => [previousState];
}

final class NoteActionSuccess extends NotesState {
  final String? message;
  const NoteActionSuccess({this.message});

  @override
  List<Object?> get props => [message];
}

final class NoteActionError extends NotesState {
  final String message;
  final NotesLoaded? previousState;
  const NoteActionError(this.message, {this.previousState});

  @override
  List<Object?> get props => [message, previousState];
}

part of 'notes_bloc.dart';

sealed class NotesEvent extends Equatable {
  const NotesEvent();

  @override
  List<Object?> get props => [];
}

final class FetchNotes extends NotesEvent {
  final NotesFilter filter;
  const FetchNotes({this.filter = NotesFilter.all});

  @override
  List<Object?> get props => [filter];
}

final class WatchNotes extends NotesEvent {
  final NotesFilter filter;
  const WatchNotes({this.filter = NotesFilter.all});

  @override
  List<Object?> get props => [filter];
}

final class StopWatchingNotes extends NotesEvent {
  const StopWatchingNotes();
}

final class FilterNotes extends NotesEvent {
  final NotesFilter filter;
  const FilterNotes(this.filter);

  @override
  List<Object?> get props => [filter];
}

final class NotesUpdated extends NotesEvent {
  final List<NoteModel> notes;
  const NotesUpdated(this.notes);

  @override
  List<Object?> get props => [notes];
}

final class AddNote extends NotesEvent {
  final NoteModel note;
  const AddNote(this.note);

  @override
  List<Object?> get props => [note];
}

final class UpdateNote extends NotesEvent {
  final NoteModel note;
  const UpdateNote(this.note);

  @override
  List<Object?> get props => [note];
}

final class DeleteNote extends NotesEvent {
  final String noteId;
  const DeleteNote(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

final class ToggleNoteImportant extends NotesEvent {
  final String noteId;
  final bool isImportant;
  const ToggleNoteImportant(this.noteId, this.isImportant);

  @override
  List<Object?> get props => [noteId, isImportant];
}

final class ToggleNoteTodo extends NotesEvent {
  final String noteId;
  final bool isTodo;
  const ToggleNoteTodo(this.noteId, this.isTodo);

  @override
  List<Object?> get props => [noteId, isTodo];
}

final class SearchNotes extends NotesEvent {
  final String query;
  const SearchNotes(this.query);

  @override
  List<Object?> get props => [query];
}

final class ClearSearch extends NotesEvent {
  const ClearSearch();
}

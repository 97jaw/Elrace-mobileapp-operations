import '../data/note_model.dart';

enum NotesFilter { all, important, todo }

abstract class INotesRepository {
  Future<List<NoteModel>> getNotes({NotesFilter filter = NotesFilter.all});

  Stream<List<NoteModel>> watchNotes({NotesFilter filter = NotesFilter.all});

  Future<NoteModel?> getNoteById(String noteId);

  Future<void> addNote(NoteModel note);

  Future<void> updateNote(NoteModel note);

  Future<void> deleteNote(String noteId);

  Future<int> getNotesCount({NotesFilter filter = NotesFilter.all});

  Future<void> toggleImportant(String noteId, bool isImportant);

  Future<void> toggleTodo(String noteId, bool isTodo);
}

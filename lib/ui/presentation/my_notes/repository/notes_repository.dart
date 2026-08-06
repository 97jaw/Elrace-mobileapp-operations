import '../data/note_model.dart';
import 'i_notes_repository.dart';

/// Deprecated: Use FirebaseNotesRepository instead.
/// This class is kept for backward compatibility and testing purposes only.
class NotesRepository implements INotesRepository {
  static final List<NoteModel> _dummyNotes = [
    NoteModel(
      id: '1',
      ownerId: 'demo-user',
      title: 'Meeting with Team',
      content: 'Discuss project requirements and timeline for the upcoming sprint.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    NoteModel(
      id: '2',
      ownerId: 'demo-user',
      title: 'Flutter Development Tips',
      content: 'Remember to use proper state management and follow clean architecture principles.',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    NoteModel(
      id: '3',
      ownerId: 'demo-user',
      title: 'Shopping List',
      content: 'Groceries: milk, bread, eggs, fruits, vegetables for the week.',
      isImportant: true,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    NoteModel(
      id: '4',
      ownerId: 'demo-user',
      title: 'Book Recommendations',
      content: 'Clean Code by Robert Martin, Effective Dart programming guidelines.',
      isTodo: true,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  @override
  Future<List<NoteModel>> getNotes({NotesFilter filter = NotesFilter.all}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    switch (filter) {
      case NotesFilter.important:
        return _dummyNotes.where((n) => n.isImportant).toList();
      case NotesFilter.todo:
        return _dummyNotes.where((n) => n.isTodo).toList();
      case NotesFilter.all:
        return List.from(_dummyNotes);
    }
  }

  @override
  Stream<List<NoteModel>> watchNotes({NotesFilter filter = NotesFilter.all}) {
    return Stream.fromFuture(getNotes(filter: filter));
  }

  @override
  Future<NoteModel?> getNoteById(String noteId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _dummyNotes.firstWhere((n) => n.id == noteId);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> addNote(NoteModel note) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _dummyNotes.insert(0, note);
  }

  @override
  Future<void> updateNote(NoteModel note) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _dummyNotes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _dummyNotes[index] = note;
    }
  }

  @override
  Future<void> deleteNote(String noteId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _dummyNotes.removeWhere((note) => note.id == noteId);
  }

  @override
  Future<int> getNotesCount({NotesFilter filter = NotesFilter.all}) async {
    final notes = await getNotes(filter: filter);
    return notes.length;
  }

  @override
  Future<void> toggleImportant(String noteId, bool isImportant) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _dummyNotes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      _dummyNotes[index] = _dummyNotes[index].copyWith(isImportant: isImportant);
    }
  }

  @override
  Future<void> toggleTodo(String noteId, bool isTodo) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _dummyNotes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      _dummyNotes[index] = _dummyNotes[index].copyWith(isTodo: isTodo);
    }
  }
}

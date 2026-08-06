import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/note_model.dart';
import 'i_notes_repository.dart';

class FirebaseNotesRepository implements INotesRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirebaseNotesRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _userId {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User not authenticated. Please sign in first.');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _notesCollection =>
      _firestore.collection('users').doc(_userId).collection('notes');

  Query<Map<String, dynamic>> _applyFilter(
    Query<Map<String, dynamic>> query,
    NotesFilter filter,
  ) {
    switch (filter) {
      case NotesFilter.important:
        return query.where('isImportant', isEqualTo: true);
      case NotesFilter.todo:
        return query.where('isTodo', isEqualTo: true);
      case NotesFilter.all:
      default:
        return query;
    }
  }

  @override
  Future<List<NoteModel>> getNotes({NotesFilter filter = NotesFilter.all}) async {
    try {
      Query<Map<String, dynamic>> query = _notesCollection
          .orderBy('updatedAt', descending: true);
      
      query = _applyFilter(query, filter);
      
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => NoteModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to fetch notes: $e');
    }
  }

  @override
  Stream<List<NoteModel>> watchNotes({NotesFilter filter = NotesFilter.all}) {
    try {
      Query<Map<String, dynamic>> query = _notesCollection
          .orderBy('updatedAt', descending: true);
      
      query = _applyFilter(query, filter);
      
      return query.snapshots().map((snapshot) =>
          snapshot.docs.map((doc) => NoteModel.fromFirestore(doc)).toList());
    } catch (e) {
      throw Exception('Failed to watch notes: $e');
    }
  }

  @override
  Future<NoteModel?> getNoteById(String noteId) async {
    try {
      final doc = await _notesCollection.doc(noteId).get();
      if (!doc.exists) return null;
      return NoteModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get note: $e');
    }
  }

  @override
  Future<void> addNote(NoteModel note) async {
    try {
      final noteWithOwner = note.copyWith(
        ownerId: _userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _notesCollection.doc(note.id).set(noteWithOwner.toFirestore());
    } catch (e) {
      throw Exception('Failed to add note: $e');
    }
  }

  @override
  Future<void> updateNote(NoteModel note) async {
    try {
      final updatedNote = note.copyWith(updatedAt: DateTime.now());
      await _notesCollection.doc(note.id).update(updatedNote.toFirestore());
    } catch (e) {
      throw Exception('Failed to update note: $e');
    }
  }

  @override
  Future<void> deleteNote(String noteId) async {
    try {
      await _notesCollection.doc(noteId).delete();
    } catch (e) {
      throw Exception('Failed to delete note: $e');
    }
  }

  @override
  Future<int> getNotesCount({NotesFilter filter = NotesFilter.all}) async {
    try {
      Query<Map<String, dynamic>> query = _notesCollection;
      query = _applyFilter(query, filter);
      
      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Failed to get notes count: $e');
    }
  }

  @override
  Future<void> toggleImportant(String noteId, bool isImportant) async {
    try {
      await _notesCollection.doc(noteId).update({
        'isImportant': isImportant,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to toggle important: $e');
    }
  }

  @override
  Future<void> toggleTodo(String noteId, bool isTodo) async {
    try {
      await _notesCollection.doc(noteId).update({
        'isTodo': isTodo,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to toggle todo: $e');
    }
  }

  Future<void> updateActionItem(
    String noteId,
    String actionItemId,
    bool isDone,
  ) async {
    try {
      final doc = await _notesCollection.doc(noteId).get();
      if (!doc.exists) throw Exception('Note not found');

      final note = NoteModel.fromFirestore(doc);
      final updatedActionItems = note.actionItems.map((item) {
        if (item.id == actionItemId) {
          return item.copyWith(isDone: isDone);
        }
        return item;
      }).toList();

      await _notesCollection.doc(noteId).update({
        'actionItems': updatedActionItems.map((e) => e.toJson()).toList(),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update action item: $e');
    }
  }

  Future<void> addTagToNote(String noteId, String tag) async {
    try {
      await _notesCollection.doc(noteId).update({
        'tags': FieldValue.arrayUnion([tag]),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to add tag: $e');
    }
  }

  Future<void> removeTagFromNote(String noteId, String tag) async {
    try {
      await _notesCollection.doc(noteId).update({
        'tags': FieldValue.arrayRemove([tag]),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to remove tag: $e');
    }
  }

  Future<List<NoteModel>> searchNotes(String query) async {
    try {
      final allNotes = await getNotes();
      final lowerQuery = query.toLowerCase();
      
      return allNotes.where((note) {
        return note.title.toLowerCase().contains(lowerQuery) ||
            note.content.toLowerCase().contains(lowerQuery) ||
            note.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));
      }).toList();
    } catch (e) {
      throw Exception('Failed to search notes: $e');
    }
  }
}

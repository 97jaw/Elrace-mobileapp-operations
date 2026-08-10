import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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

  /// Prefer live Firebase Auth UID; fall back to login payload firebase_uid.
  String? get _currentUid {
    final firebaseUid = _auth.currentUser?.uid;
    if (firebaseUid != null) return firebaseUid;
    return SharedPref.getLoginData().result?.data?.firebase_uid;
  }

  String get _userId {
    final uid = _currentUid;
    if (uid == null || uid.isEmpty) {
      throw Exception('User not authenticated. Please sign in first.');
    }
    return uid;
  }

  /// Same pattern as TodoFirebaseService — custom token may not be hydrated yet.
  Future<void> _ensureSignedIn() async {
    if (_auth.currentUser != null) return;

    final loginData = SharedPref.getLoginData();
    final customToken = loginData.result?.data?.firebase_custom_token;
    if (customToken != null &&
        customToken.isNotEmpty &&
        customToken != 'false') {
      try {
        await _auth.signInWithCustomToken(customToken);
        debugPrint('✅ FirebaseNotesRepository: Signed in with custom token');
      } catch (e) {
        debugPrint(
          '⚠️ FirebaseNotesRepository: Could not sign in with custom token: $e',
        );
      }
    }

    if (_auth.currentUser == null) {
      throw Exception(
        'Firebase Auth not signed in. Open Chat once after login, then retry Notes.',
      );
    }
  }

  CollectionReference<Map<String, dynamic>> get _notesCollection =>
      _firestore.collection('users').doc(_userId).collection('notes');

  /// Client-side filter so we avoid composite index requirements for R1.
  List<NoteModel> _applyClientFilter(
    List<NoteModel> notes,
    NotesFilter filter,
  ) {
    switch (filter) {
      case NotesFilter.important:
        return notes.where((n) => n.isImportant).toList();
      case NotesFilter.todo:
        return notes.where((n) => n.isTodo).toList();
      case NotesFilter.all:
        return notes;
    }
  }

  @override
  Future<List<NoteModel>> getNotes({
    NotesFilter filter = NotesFilter.all,
  }) async {
    try {
      await _ensureSignedIn();
      final snapshot = await _notesCollection
          .orderBy('updatedAt', descending: true)
          .get();
      final notes =
          snapshot.docs.map((doc) => NoteModel.fromFirestore(doc)).toList();
      return _applyClientFilter(notes, filter);
    } catch (e) {
      throw Exception('Failed to fetch notes: $e');
    }
  }

  @override
  Stream<List<NoteModel>> watchNotes({
    NotesFilter filter = NotesFilter.all,
  }) async* {
    await _ensureSignedIn();
    yield* _notesCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final notes =
          snapshot.docs.map((doc) => NoteModel.fromFirestore(doc)).toList();
      return _applyClientFilter(notes, filter);
    });
  }

  @override
  Future<NoteModel?> getNoteById(String noteId) async {
    try {
      await _ensureSignedIn();
      final doc = await _notesCollection.doc(noteId).get();
      if (!doc.exists) return null;
      return NoteModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get note: $e');
    }
  }

  @override
  Stream<NoteModel?> watchNoteById(String noteId) async* {
    await _ensureSignedIn();
    yield* _notesCollection.doc(noteId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return NoteModel.fromFirestore(doc);
    });
  }

  @override
  Future<void> addNote(NoteModel note) async {
    try {
      await _ensureSignedIn();
      final noteWithOwner = note.copyWith(
        ownerId: _userId,
        createdAt: note.createdAt,
        updatedAt: DateTime.now(),
      );
      debugPrint(
        '📝 FirebaseNotesRepository: saving note '
        'id=${noteWithOwner.id} uid=$_userId path=users/$_userId/notes',
      );
      await _notesCollection.doc(note.id).set(noteWithOwner.toFirestore());
      debugPrint('✅ FirebaseNotesRepository: note saved successfully');
    } catch (e) {
      debugPrint('❌ FirebaseNotesRepository: addNote failed: $e');
      throw Exception('Failed to add note: $e');
    }
  }

  @override
  Future<void> updateNote(NoteModel note) async {
    try {
      await _ensureSignedIn();
      final ref = _notesCollection.doc(note.id);
      final existingSnap = await ref.get();
      var toSave = note.copyWith(updatedAt: DateTime.now());

      // Don't let a stale client snapshot wipe Whisper transcript / AI results.
      if (existingSnap.exists) {
        final server = NoteModel.fromFirestore(existingSnap);
        toSave = _mergePreservingServerAi(client: toSave, server: server);
      }

      await ref.update(toSave.toFirestore());
    } catch (e) {
      debugPrint('❌ FirebaseNotesRepository: updateNote failed: $e');
      throw Exception('Failed to update note: $e');
    }
  }

  /// Prefer server recording transcript / AI outputs when the client is stale.
  NoteModel _mergePreservingServerAi({
    required NoteModel client,
    required NoteModel server,
  }) {
    var merged = client;

    final cRec = client.recording;
    final sRec = server.recording;
    if (cRec != null && sRec != null) {
      final clientTranscriptEmpty =
          cRec.transcript == null || cRec.transcript!.trim().isEmpty;
      final serverHasTranscript = sRec.transcript?.trim().isNotEmpty ?? false;
      final serverFurther =
          sRec.status == TranscriptionStatus.done ||
          sRec.status == TranscriptionStatus.processing ||
          serverHasTranscript;

      if (clientTranscriptEmpty && serverFurther) {
        merged = merged.copyWith(
          recording: sRec.copyWith(
            audioUrl:
                cRec.audioUrl.isNotEmpty ? cRec.audioUrl : sRec.audioUrl,
            storagePath: cRec.storagePath ?? sRec.storagePath,
            durationSeconds: cRec.durationSeconds > 0
                ? cRec.durationSeconds
                : sRec.durationSeconds,
          ),
        );
      }
    } else if (cRec == null && sRec != null) {
      merged = merged.copyWith(recording: sRec);
    }

    if ((client.aiSummary == null || client.aiSummary!.isEmpty) &&
        (server.aiSummary?.isNotEmpty ?? false)) {
      merged = merged.copyWith(aiSummary: server.aiSummary);
    }
    if ((client.aiBulletPoints == null || client.aiBulletPoints!.isEmpty) &&
        (server.aiBulletPoints?.isNotEmpty ?? false)) {
      merged = merged.copyWith(aiBulletPoints: server.aiBulletPoints);
    }
    if ((client.translatedText == null || client.translatedText!.isEmpty) &&
        (server.translatedText?.isNotEmpty ?? false)) {
      merged = merged.copyWith(
        translatedText: server.translatedText,
        translatedLanguage: server.translatedLanguage,
      );
    }
    if (client.actionItems.isEmpty && server.actionItems.isNotEmpty) {
      merged = merged.copyWith(actionItems: server.actionItems);
    }
    // Don't regress AI status done → pending from a stale client write.
    if (server.aiStatus == NoteAiStatus.done &&
        (client.aiStatus == NoteAiStatus.pending ||
            client.aiStatus == NoteAiStatus.none)) {
      merged = merged.copyWith(aiStatus: NoteAiStatus.done);
    }

    return merged;
  }

  @override
  Future<void> deleteNote(String noteId) async {
    try {
      await _ensureSignedIn();
      await _notesCollection.doc(noteId).delete();
    } catch (e) {
      throw Exception('Failed to delete note: $e');
    }
  }

  @override
  Future<int> getNotesCount({NotesFilter filter = NotesFilter.all}) async {
    try {
      final notes = await getNotes(filter: filter);
      return notes.length;
    } catch (e) {
      throw Exception('Failed to get notes count: $e');
    }
  }

  @override
  Future<void> toggleImportant(String noteId, bool isImportant) async {
    try {
      await _ensureSignedIn();
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
      await _ensureSignedIn();
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
      await _ensureSignedIn();
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
      await _ensureSignedIn();
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
      await _ensureSignedIn();
      await _notesCollection.doc(noteId).update({
        'tags': FieldValue.arrayRemove([tag]),
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to remove tag: $e');
    }
  }

  CollectionReference<Map<String, dynamic>> get _sharedRefsCollection =>
      _firestore.collection('users').doc(_userId).collection('shared_note_refs');

  Future<List<SharedNoteRef>> getSharedWithMe() async {
    await _ensureSignedIn();
    final snap = await _sharedRefsCollection
        .orderBy('sharedAt', descending: true)
        .get();
    return snap.docs.map(SharedNoteRef.fromFirestore).toList();
  }

  Stream<List<SharedNoteRef>> watchSharedWithMe() async* {
    await _ensureSignedIn();
    yield* _sharedRefsCollection
        .orderBy('sharedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(SharedNoteRef.fromFirestore).toList());
  }

  Future<NoteModel?> getSharedNote({
    required String ownerId,
    required String noteId,
  }) async {
    await _ensureSignedIn();
    final doc = await _firestore
        .collection('users')
        .doc(ownerId)
        .collection('notes')
        .doc(noteId)
        .get();
    if (!doc.exists) return null;
    return NoteModel.fromFirestore(doc);
  }

  Future<NoteModel> shareNoteWith({
    required String noteId,
    required NoteSharedMember member,
  }) async {
    await _ensureSignedIn();
    final doc = await _notesCollection.doc(noteId).get();
    if (!doc.exists) throw Exception('Note not found');
    final note = NoteModel.fromFirestore(doc);

    final uids = {...note.sharedWithUids, member.uid}.toList();
    final members = [
      ...note.sharedWith.where((m) => m.uid != member.uid),
      member,
    ];

    await _notesCollection.doc(noteId).update({
      'sharedWithUids': uids,
      'sharedWith': members.map((e) => e.toJson()).toList(),
      'updatedAt': Timestamp.now(),
    });

    await _firestore
        .collection('users')
        .doc(member.uid)
        .collection('shared_note_refs')
        .doc(noteId)
        .set(
          SharedNoteRef(
            noteId: noteId,
            ownerId: _userId,
            title: note.title,
            sharedAt: DateTime.now(),
          ).toFirestore(),
        );

    return note.copyWith(sharedWithUids: uids, sharedWith: members);
  }

  Future<NoteModel> unshareNoteWith({
    required String noteId,
    required String uid,
  }) async {
    await _ensureSignedIn();
    final doc = await _notesCollection.doc(noteId).get();
    if (!doc.exists) throw Exception('Note not found');
    final note = NoteModel.fromFirestore(doc);

    final uids = note.sharedWithUids.where((u) => u != uid).toList();
    final members = note.sharedWith.where((m) => m.uid != uid).toList();

    await _notesCollection.doc(noteId).update({
      'sharedWithUids': uids,
      'sharedWith': members.map((e) => e.toJson()).toList(),
      'updatedAt': Timestamp.now(),
    });

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('shared_note_refs')
        .doc(noteId)
        .delete();

    return note.copyWith(sharedWithUids: uids, sharedWith: members);
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

import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../data/note_model.dart';

class NotesCacheService {
  static const String _draftsBoxName = 'notes_drafts';
  static const String _syncQueueBoxName = 'notes_sync_queue';
  static const String _currentDraftKey = 'current_draft';

  static NotesCacheService? _instance;
  static NotesCacheService get instance => _instance ??= NotesCacheService._();

  NotesCacheService._();

  Box<String>? _draftsBox;
  Box<String>? _syncQueueBox;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _draftsBox = await Hive.openBox<String>(_draftsBoxName);
      _syncQueueBox = await Hive.openBox<String>(_syncQueueBoxName);
      _isInitialized = true;
    } catch (e) {
      print('NotesCacheService: Failed to initialize Hive boxes: $e');
    }
  }

  Future<void> saveDraft(NoteModel note) async {
    if (!_isInitialized) await initialize();
    if (_draftsBox == null) return;

    try {
      final json = jsonEncode(note.toJson());
      await _draftsBox!.put(note.id, json);
    } catch (e) {
      print('NotesCacheService: Failed to save draft: $e');
    }
  }

  Future<void> saveCurrentDraft({
    required String title,
    required String content,
  }) async {
    if (!_isInitialized) await initialize();
    if (_draftsBox == null) return;

    try {
      final draftData = {
        'title': title,
        'content': content,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await _draftsBox!.put(_currentDraftKey, jsonEncode(draftData));
    } catch (e) {
      print('NotesCacheService: Failed to save current draft: $e');
    }
  }

  Future<Map<String, dynamic>?> getCurrentDraft() async {
    if (!_isInitialized) await initialize();
    if (_draftsBox == null) return null;

    try {
      final json = _draftsBox!.get(_currentDraftKey);
      if (json == null) return null;
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      print('NotesCacheService: Failed to get current draft: $e');
      return null;
    }
  }

  Future<void> clearCurrentDraft() async {
    if (!_isInitialized) await initialize();
    if (_draftsBox == null) return;

    try {
      await _draftsBox!.delete(_currentDraftKey);
    } catch (e) {
      print('NotesCacheService: Failed to clear current draft: $e');
    }
  }

  Future<NoteModel?> getDraft(String noteId) async {
    if (!_isInitialized) await initialize();
    if (_draftsBox == null) return null;

    try {
      final json = _draftsBox!.get(noteId);
      if (json == null) return null;
      return NoteModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      print('NotesCacheService: Failed to get draft: $e');
      return null;
    }
  }

  Future<List<NoteModel>> getAllDrafts() async {
    if (!_isInitialized) await initialize();
    if (_draftsBox == null) return [];

    try {
      final drafts = <NoteModel>[];
      for (final key in _draftsBox!.keys) {
        if (key == _currentDraftKey) continue;
        final json = _draftsBox!.get(key);
        if (json != null) {
          drafts.add(NoteModel.fromJson(jsonDecode(json) as Map<String, dynamic>));
        }
      }
      return drafts;
    } catch (e) {
      print('NotesCacheService: Failed to get all drafts: $e');
      return [];
    }
  }

  Future<void> deleteDraft(String noteId) async {
    if (!_isInitialized) await initialize();
    if (_draftsBox == null) return;

    try {
      await _draftsBox!.delete(noteId);
    } catch (e) {
      print('NotesCacheService: Failed to delete draft: $e');
    }
  }

  Future<void> clearAllDrafts() async {
    if (!_isInitialized) await initialize();
    if (_draftsBox == null) return;

    try {
      await _draftsBox!.clear();
    } catch (e) {
      print('NotesCacheService: Failed to clear all drafts: $e');
    }
  }

  Future<void> addToSyncQueue(NoteModel note, SyncOperation operation) async {
    if (!_isInitialized) await initialize();
    if (_syncQueueBox == null) return;

    try {
      final queueItem = {
        'note': note.toJson(),
        'operation': operation.name,
        'queuedAt': DateTime.now().toIso8601String(),
      };
      await _syncQueueBox!.put(note.id, jsonEncode(queueItem));
    } catch (e) {
      print('NotesCacheService: Failed to add to sync queue: $e');
    }
  }

  Future<List<SyncQueueItem>> getSyncQueue() async {
    if (!_isInitialized) await initialize();
    if (_syncQueueBox == null) return [];

    try {
      final items = <SyncQueueItem>[];
      for (final key in _syncQueueBox!.keys) {
        final json = _syncQueueBox!.get(key);
        if (json != null) {
          final data = jsonDecode(json) as Map<String, dynamic>;
          items.add(SyncQueueItem(
            note: NoteModel.fromJson(data['note'] as Map<String, dynamic>),
            operation: SyncOperation.values.firstWhere(
              (e) => e.name == data['operation'],
              orElse: () => SyncOperation.create,
            ),
            queuedAt: DateTime.parse(data['queuedAt'] as String),
          ));
        }
      }
      items.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
      return items;
    } catch (e) {
      print('NotesCacheService: Failed to get sync queue: $e');
      return [];
    }
  }

  Future<void> removeFromSyncQueue(String noteId) async {
    if (!_isInitialized) await initialize();
    if (_syncQueueBox == null) return;

    try {
      await _syncQueueBox!.delete(noteId);
    } catch (e) {
      print('NotesCacheService: Failed to remove from sync queue: $e');
    }
  }

  Future<void> clearSyncQueue() async {
    if (!_isInitialized) await initialize();
    if (_syncQueueBox == null) return;

    try {
      await _syncQueueBox!.clear();
    } catch (e) {
      print('NotesCacheService: Failed to clear sync queue: $e');
    }
  }

  Future<bool> hasPendingSync() async {
    if (!_isInitialized) await initialize();
    if (_syncQueueBox == null) return false;
    return _syncQueueBox!.isNotEmpty;
  }

  Future<void> dispose() async {
    await _draftsBox?.close();
    await _syncQueueBox?.close();
    _isInitialized = false;
  }
}

enum SyncOperation { create, update, delete }

class SyncQueueItem {
  final NoteModel note;
  final SyncOperation operation;
  final DateTime queuedAt;

  const SyncQueueItem({
    required this.note,
    required this.operation,
    required this.queuedAt,
  });
}

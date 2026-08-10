import 'dart:io';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../data/note_model.dart';

class NotesImageService {
  NotesImageService({
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    ImagePicker? picker,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _picker = picker ?? ImagePicker();

  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final ImagePicker _picker;

  String get _uid {
    final u = _auth.currentUser?.uid;
    if (u != null && u.isNotEmpty) return u;
    final fromLogin = SharedPref.getLoginData().result?.data?.firebase_uid;
    if (fromLogin != null && fromLogin.isNotEmpty) return fromLogin;
    throw Exception('Not signed in');
  }

  Future<List<XFile>> pickImages({bool fromCamera = false}) async {
    if (fromCamera) {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      return shot == null ? [] : [shot];
    }
    return _picker.pickMultiImage(imageQuality: 85);
  }

  Future<ImageAttachment> uploadImage({
    required String noteId,
    required XFile file,
  }) async {
    final id = const Uuid().v4();
    final path = 'chat_media/notes/$_uid/$noteId/images/$id.jpg';
    final ref = _storage.ref(path);
    final bytes = await file.readAsBytes();
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await ref.getDownloadURL();
    debugPrint('✅ NotesImageService uploaded $path');
    return ImageAttachment(
      id: id,
      imageUrl: url,
      addedAt: DateTime.now(),
    );
  }

  Future<List<ImageAttachment>> uploadFiles({
    required String noteId,
    required List<XFile> files,
  }) async {
    final out = <ImageAttachment>[];
    for (final f in files) {
      out.add(await uploadImage(noteId: noteId, file: f));
    }
    return out;
  }

  /// Local file path helper when needed by callers.
  File? asFile(XFile x) => File(x.path);
}

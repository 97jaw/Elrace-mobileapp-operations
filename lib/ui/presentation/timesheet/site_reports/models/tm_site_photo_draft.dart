import 'dart:io';
import 'dart:typed_data';

import 'package:el_race/report_module/data/models/report_item_model.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Local or server photo in the composer / gallery edit flow.
class TmSitePhotoDraft {
  TmSitePhotoDraft.local({
    required File file,
    String? description,
    String? location,
  })  : localFile = file,
        serverItemId = null,
        networkImageUrl = null,
        descriptionController = TextEditingController(text: description ?? ''),
        locationController = TextEditingController(text: location ?? '');

  TmSitePhotoDraft.fromServer(ReportItemModel item)
      : localFile = null,
        serverItemId = item.id,
        networkImageUrl = item.image,
        descriptionController =
            TextEditingController(text: item.description),
        locationController = TextEditingController(text: item.location);

  /// Local capture / gallery / post-edit file. Mutable so annotate can replace it.
  File? localFile;
  final String? serverItemId;
  final String? networkImageUrl;

  /// Annotated PNG bytes from [ImageEditingScreen] (draw / text / shapes).
  Uint8List? editedBytes;

  final TextEditingController descriptionController;
  final TextEditingController locationController;

  bool pendingDelete = false;

  bool get isServer => serverItemId != null;
  bool get isNew => localFile != null && serverItemId == null;
  bool get hasEdited => editedBytes != null;

  bool get hasDescription => descriptionController.text.trim().isNotEmpty;

  /// File to upload: prefers annotated bytes written to a temp PNG.
  Future<File?> effectiveFileForUpload() async {
    if (editedBytes != null) {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/site_edited_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(editedBytes!);
      localFile = file;
      return file;
    }
    return localFile;
  }

  void dispose() {
    descriptionController.dispose();
    locationController.dispose();
  }
}

import 'dart:io';

import 'package:el_race/report_module/data/models/report_item_model.dart';
import 'package:flutter/material.dart';

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

  final File? localFile;
  final String? serverItemId;
  final String? networkImageUrl;

  final TextEditingController descriptionController;
  final TextEditingController locationController;

  bool pendingDelete = false;

  bool get isServer => serverItemId != null && localFile == null;
  bool get isNew => localFile != null && serverItemId == null;

  bool get hasDescription => descriptionController.text.trim().isNotEmpty;

  void dispose() {
    descriptionController.dispose();
    locationController.dispose();
  }
}

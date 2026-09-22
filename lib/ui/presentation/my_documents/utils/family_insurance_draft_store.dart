import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local draft for an in-progress family insurance document request.
///
/// Odoo has no draft state on `employee.document.request`; drafts live on-device
/// until [family_insurance/submit] succeeds.
class FamilyInsuranceDraft {
  const FamilyInsuranceDraft({
    required this.employeeKey,
    required this.familyMember,
    required this.medicalRequestCase,
    required this.memberName,
    this.dobIso,
    this.nationalityId,
    this.attachments = const {},
  });

  final String employeeKey;
  final String familyMember;
  final String medicalRequestCase;
  final String memberName;
  final String? dobIso;
  final int? nationalityId;

  /// field → attachment meta (copied under app documents).
  final Map<String, FamilyInsuranceDraftAttachment> attachments;

  Map<String, dynamic> toJson() => {
        'employeeKey': employeeKey,
        'familyMember': familyMember,
        'medicalRequestCase': medicalRequestCase,
        'memberName': memberName,
        'dobIso': dobIso,
        'nationalityId': nationalityId,
        'attachments': attachments.map(
          (k, v) => MapEntry(k, v.toJson()),
        ),
      };

  factory FamilyInsuranceDraft.fromJson(Map<String, dynamic> json) {
    final rawAtt = json['attachments'];
    final attachments = <String, FamilyInsuranceDraftAttachment>{};
    if (rawAtt is Map) {
      rawAtt.forEach((key, value) {
        if (value is Map) {
          attachments[key.toString()] = FamilyInsuranceDraftAttachment.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      });
    }
    return FamilyInsuranceDraft(
      employeeKey: (json['employeeKey'] ?? '').toString(),
      familyMember: (json['familyMember'] ?? '').toString(),
      medicalRequestCase: (json['medicalRequestCase'] ?? '').toString(),
      memberName: (json['memberName'] ?? '').toString(),
      dobIso: json['dobIso']?.toString(),
      nationalityId: int.tryParse((json['nationalityId'] ?? '').toString()),
      attachments: attachments,
    );
  }
}

class FamilyInsuranceDraftAttachment {
  const FamilyInsuranceDraftAttachment({
    required this.path,
    required this.filename,
    this.expiryIso,
  });

  final String path;
  final String filename;
  final String? expiryIso;

  Map<String, dynamic> toJson() => {
        'path': path,
        'filename': filename,
        'expiryIso': expiryIso,
      };

  factory FamilyInsuranceDraftAttachment.fromJson(Map<String, dynamic> json) {
    return FamilyInsuranceDraftAttachment(
      path: (json['path'] ?? '').toString(),
      filename: (json['filename'] ?? 'document').toString(),
      expiryIso: json['expiryIso']?.toString(),
    );
  }
}

abstract final class FamilyInsuranceDraftStore {
  /// Single active draft per install — avoids emp_id key mismatches on reload.
  static const _prefsKey = 'family_insurance_draft_v2_active';

  static Future<Directory> _draftDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/family_insurance_drafts/active');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<FamilyInsuranceDraft?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final draft = FamilyInsuranceDraft.fromJson(
        Map<String, dynamic>.from(map),
      );
      final kept = <String, FamilyInsuranceDraftAttachment>{};
      for (final entry in draft.attachments.entries) {
        final att = entry.value;
        if (att.path.isEmpty) continue;
        final file = File(att.path);
        if (await file.exists()) {
          kept[entry.key] = att;
        }
      }
      return FamilyInsuranceDraft(
        employeeKey: draft.employeeKey,
        familyMember: draft.familyMember,
        medicalRequestCase: draft.medicalRequestCase,
        memberName: draft.memberName,
        dobIso: draft.dobIso,
        nationalityId: draft.nationalityId,
        attachments: kept,
      );
    } catch (_) {
      return null;
    }
  }

  /// Persists draft and returns the stored copy (with durable file paths).
  static Future<FamilyInsuranceDraft> save(FamilyInsuranceDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    final dir = await _draftDir();

    final copied = <String, FamilyInsuranceDraftAttachment>{};
    for (final entry in draft.attachments.entries) {
      final field = entry.key;
      final att = entry.value;
      final src = File(att.path);
      if (!await src.exists()) continue;

      final safeName = att.filename.replaceAll(RegExp(r'[^\w.\-]+'), '_');
      final destPath = '${dir.path}/${field}_$safeName';
      String finalPath;
      if (att.path.startsWith(dir.path) && await File(att.path).exists()) {
        finalPath = att.path;
      } else {
        // Overwrite previous draft file for this field.
        final dest = File(destPath);
        if (await dest.exists()) {
          await dest.delete();
        }
        finalPath = (await src.copy(destPath)).path;
      }

      copied[field] = FamilyInsuranceDraftAttachment(
        path: finalPath,
        filename: att.filename,
        expiryIso: att.expiryIso,
      );
    }

    final toStore = FamilyInsuranceDraft(
      employeeKey: draft.employeeKey,
      familyMember: draft.familyMember,
      medicalRequestCase: draft.medicalRequestCase,
      memberName: draft.memberName,
      dobIso: draft.dobIso,
      nationalityId: draft.nationalityId,
      attachments: copied,
    );

    await prefs.setString(_prefsKey, jsonEncode(toStore.toJson()));
    return toStore;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    // Legacy key cleanup.
    final keys = prefs.getKeys().where((k) => k.startsWith('family_insurance_draft_'));
    for (final k in keys) {
      await prefs.remove(k);
    }
    try {
      final dir = await _draftDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}

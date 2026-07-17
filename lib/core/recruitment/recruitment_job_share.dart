import 'dart:io';

import 'package:el_race/core/recruitment/models/requisition.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _careersUrl = 'https://elrace.com/careers';

/// Share an open position externally (careers page + employee as reference).
Future<void> shareRecruitmentPosition(
  BuildContext context, {
  required Requisition requisition,
  Rect? sharePositionOrigin,
}) async {
  final login = SharedPref.getLoginData().result?.data;
  final referenceName =
      (login?.name ?? login?.emp_name ?? '').trim().isNotEmpty
          ? (login?.name ?? login?.emp_name ?? '').trim()
          : 'EL RACE Employee';

  final r = requisition;
  final buffer = StringBuffer()
    ..writeln('${r.jobTitle} — EL RACE')
    ..writeln()
    ..writeln('${r.department} · ${r.location}')
    ..writeln('Ref: ${r.referenceNumber}')
    ..writeln()
    ..writeln('Apply at: $_careersUrl')
    ..writeln()
    ..writeln('Reference Name: $referenceName');

  final origin = sharePositionOrigin ?? _defaultShareOrigin(context);

  try {
    final thumb = await _careersShareThumbnail();
    if (thumb != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [thumb],
          text: buffer.toString(),
          subject: '${r.jobTitle} at EL RACE',
          sharePositionOrigin: origin,
        ),
      );
    } else {
      await SharePlus.instance.share(
        ShareParams(
          text: buffer.toString(),
          subject: '${r.jobTitle} at EL RACE',
          sharePositionOrigin: origin,
        ),
      );
    }
  } catch (_) {
    await SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: '${r.jobTitle} at EL RACE',
        sharePositionOrigin: origin,
      ),
    );
  }
}

Rect _defaultShareOrigin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) {
    return const Rect.fromLTWH(0, 0, 1, 1);
  }
  final offset = box.localToGlobal(Offset.zero);
  return offset & box.size;
}

Future<XFile?> _careersShareThumbnail() async {
  const assetPath = 'assets/images/business_card/company_logo.png';
  try {
    final bytes = await rootBundle.load(assetPath);
    final dir = await getTemporaryDirectory();
    final file = '${dir.path}/elrace_careers_share.png';
    final out = await File(file).writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    return XFile(out.path, mimeType: 'image/png', name: 'rcc_careers.png');
  } catch (_) {
    return null;
  }
}

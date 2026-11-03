import 'dart:typed_data';
import 'dart:ui';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../chat/models/message.dart';

/// One approval cell under an "Approval and Acknowledgment" table.
class TimesheetAckCell {
  const TimesheetAckCell({
    required this.page,
    required this.tableIndex,
    required this.role,
    required this.zone,
  });

  final int page;
  final int tableIndex;

  /// `employee`, `supervisor`, `site_engineer`, or `projects_manager`.
  final String role;
  final SignZone zone;
}

/// Finds the four acknowledgment cells on every page of a printed timesheet.
///
/// Employee and Supervisor/Foreman are signer slot 0 (the foreman).
/// Site Engineer is slot 1. Projects Manager is slot 2.
List<TimesheetAckCell> findTimesheetAcknowledgmentCells(Uint8List pdfBytes) {
  final doc = PdfDocument(inputBytes: pdfBytes);
  final cells = <TimesheetAckCell>[];
  try {
    final extractor = PdfTextExtractor(doc);
    for (var page = 0; page < doc.pages.count; page++) {
      final size = doc.pages[page].getClientSize();
      final employees = _hits(extractor, page, 'Employee:');
      final supervisors = _hits(extractor, page, 'Supervisor/Foreman:');
      final supervisorFallback = supervisors.isNotEmpty
          ? supervisors
          : _hits(extractor, page, 'Foreman:');
      final sites = _hits(extractor, page, 'Site Engineer:');
      final siteFallback =
          sites.isNotEmpty ? sites : _hits(extractor, page, 'Engineer:');
      final managers = _hits(extractor, page, 'Projects Manager:');
      final managerFallback =
          managers.isNotEmpty ? managers : _hits(extractor, page, 'Manager:');

      var table = 0;
      for (final employee in employees) {
        final supervisor = _sameRowRight(employee, supervisorFallback);
        if (supervisor == null) continue;
        final site = _firstBelow(employee, siteFallback);
        if (site == null) continue;
        final manager = _sameRowRight(site, managerFallback);
        final added = _tableCells(
          page: page,
          tableIndex: table,
          pageSize: Size(size.width, size.height),
          employee: employee,
          supervisor: supervisor,
          site: site,
          manager: manager,
        );
        if (added.isEmpty) continue;
        cells.addAll(added);
        table++;
      }
    }
  } finally {
    doc.dispose();
  }
  return cells;
}

const double _pad = 6;
const double _rowSlop = 10;
const double _minWidth = 80;
const double _minHeight = 24;

class _Glyph {
  const _Glyph(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;
}

List<_Glyph> _hits(PdfTextExtractor extractor, int page, String phrase) {
  final found = extractor.findText(
    [phrase],
    startPageIndex: page,
    endPageIndex: page,
  );
  return [
    for (final item in found)
      if (item.pageIndex == page)
        _Glyph(
          item.bounds.left,
          item.bounds.top,
          item.bounds.right,
          item.bounds.bottom,
        ),
  ];
}

_Glyph? _sameRowRight(_Glyph anchor, List<_Glyph> candidates) {
  _Glyph? best;
  for (final candidate in candidates) {
    if (candidate.left <= anchor.left + 8) continue;
    if ((candidate.top - anchor.top).abs() > _rowSlop) continue;
    if (best == null || candidate.left < best.left) best = candidate;
  }
  return best;
}

_Glyph? _firstBelow(_Glyph anchor, List<_Glyph> candidates) {
  _Glyph? best;
  for (final candidate in candidates) {
    if (candidate.top <= anchor.bottom) continue;
    if ((candidate.left - anchor.left).abs() > 40) continue;
    if (best == null || candidate.top < best.top) best = candidate;
  }
  return best;
}

List<TimesheetAckCell> _tableCells({
  required int page,
  required int tableIndex,
  required Size pageSize,
  required _Glyph employee,
  required _Glyph supervisor,
  required _Glyph site,
  required _Glyph? manager,
}) {
  final rowPitch = site.top - employee.top;
  if (rowPitch <= _rowSlop) return const [];

  final colWidth = supervisor.left - employee.left;
  if (colWidth < _minWidth) return const [];

  final leftEdge = employee.left;
  final mid = supervisor.left - _pad;
  final rightEdge = (supervisor.left + colWidth - _pad)
      .clamp(_pad, pageSize.width - _pad)
      .toDouble();
  final topRowTop = employee.bottom + _pad;
  final topRowBottom = site.top - _pad;
  final bottomAnchor = manager ?? site;
  final bottomRowTop = bottomAnchor.bottom + _pad;
  final bottomRowBottom =
      (site.top + rowPitch - _pad).clamp(bottomRowTop, pageSize.height - _pad);

  TimesheetAckCell? cell(String role, double left, double top, double right,
      double bottom) {
    final width = right - left;
    final height = bottom - top;
    if (width < _minWidth || height < _minHeight) return null;
    final slot = switch (role) {
      'site_engineer' => 1,
      'projects_manager' => 2,
      _ => 0,
    };
    return TimesheetAckCell(
      page: page,
      tableIndex: tableIndex,
      role: role,
      zone: SignZone(
        page: page,
        x: (left / pageSize.width).clamp(0.0, 1.0),
        y: (top / pageSize.height).clamp(0.0, 1.0),
        width: (width / pageSize.width).clamp(0.0, 1.0),
        height: (height / pageSize.height).clamp(0.0, 1.0),
        signerSlot: slot,
        cellRole: role,
      ),
    );
  }

  return [
    cell('employee', leftEdge, topRowTop, mid, topRowBottom),
    cell('supervisor', supervisor.left, topRowTop, rightEdge, topRowBottom),
    cell('site_engineer', leftEdge, bottomRowTop, mid, bottomRowBottom),
    cell(
      'projects_manager',
      manager?.left ?? supervisor.left,
      bottomRowTop,
      rightEdge,
      bottomRowBottom,
    ),
  ].whereType<TimesheetAckCell>().toList();
}

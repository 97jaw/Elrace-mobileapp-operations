/// Canonical HR request type labels for filters (create picker catalog).
abstract final class HrRequestTypeCatalog {
  static const List<String> all = [
    'Sick',
    'Short',
    'Annual',
    'Job mission',
    'Temp. permission',
    'Temporary permission',
    'Effective date',
    'Car rent',
    'SIM',
    'Car allowance',
    'Leave Request',
    'Sick Leave',
    'Short Leave',
    'Annual Leave',
    'Job Mission',
  ];

  /// Union of catalog + any types already present in loaded records.
  static List<String> forFilter(Iterable<String> fromRecords) {
    final set = <String>{
      ...all.where((e) => e.trim().isNotEmpty),
      ...fromRecords.where((e) => e.trim().isNotEmpty),
    };
    final list = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}

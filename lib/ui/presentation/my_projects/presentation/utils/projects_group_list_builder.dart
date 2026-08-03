import 'package:el_race/ui/presentation/my_projects/data/models/project_manager_filter_item.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_model.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/odoo_field_parsers.dart';

/// Builds group-by rows from project records (PM fallback / enrichment path).
abstract final class ProjectsGroupListBuilder {
  static List<ProjectManagerFilterItem> fromProjects(
    List<ProjectModel> projects,
    ProjectsGroupByMode mode, {
    bool allowNameFallback = false,
  }) {
    return switch (mode) {
      ProjectsGroupByMode.projectManager => _byProjectManager(
          projects,
          allowNameFallback: allowNameFallback,
        ),
      ProjectsGroupByMode.client => _byClient(
          projects,
          allowNameFallback: allowNameFallback,
        ),
      ProjectsGroupByMode.city => _byCity(
          projects,
          allowNameFallback: allowNameFallback,
        ),
    };
  }

  static String _norm(String? value) =>
      (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static List<ProjectManagerFilterItem> _byProjectManager(
    List<ProjectModel> projects, {
    bool allowNameFallback = false,
  }) {
    final nameToId = <String, int>{};
    for (final p in projects) {
      final id = p.projectManagerId;
      final name = _norm(p.projectManagerName);
      if (id != null && id > 0 && name.isNotEmpty) {
        nameToId[name] = id;
      }
    }
    // Second pass: register names that only appear without id.
    for (final p in projects) {
      final name = _norm(p.projectManagerName);
      if (name.isEmpty || nameToId.containsKey(name)) continue;
      if (OdooFieldParsers.isNoManagerLabel(name)) continue;
      // Stable synthetic id per manager name until v2 returns employee id.
      nameToId[name] = -(name.hashCode.abs() + 1);
    }

    final buckets = <int, _Bucket>{};

    for (final p in projects) {
      var id = p.projectManagerId;
      var name = (p.projectManagerName ?? '').trim();

      if ((id == null || id <= 0) && name.isNotEmpty) {
        id = nameToId[_norm(name)];
      }

      if ((id == null || id <= 0) && allowNameFallback && name.isNotEmpty) {
        if (OdooFieldParsers.isNoManagerLabel(name)) continue;
        id = -(name.hashCode.abs() + 1);
      }

      if (id == null || id == 0) continue;

      final resolvedId = id;
      if (OdooFieldParsers.isNoManagerLabel(name)) {
        name = resolvedId > 0 ? 'Manager #$resolvedId' : name;
      }
      if (name.isEmpty) continue;

      final bucket = buckets.putIfAbsent(
        resolvedId,
        () => _Bucket(id: resolvedId, name: name, photoUrl: p.managerPhoto),
      );
      if (bucket.name.isEmpty || OdooFieldParsers.isNoManagerLabel(bucket.name)) {
        bucket.name = name;
      }
      if ((bucket.photoUrl == null || bucket.photoUrl!.isEmpty) &&
          p.managerPhoto != null &&
          p.managerPhoto!.isNotEmpty) {
        bucket.photoUrl = p.managerPhoto;
      }
      bucket.count++;
      bucket.touchDate(p.dateStart.isNotEmpty ? p.dateStart : p.date);
    }

    final list = buckets.values
        .map(
          (b) => ProjectManagerFilterItem(
            id: b.id,
            name: b.name,
            photoUrl: b.photoUrl,
            projectCount: b.count,
            lastUpdate: b.lastUpdate,
          ),
        )
        .toList()
      ..sort((a, b) => b.projectCount.compareTo(a.projectCount));

    return list;
  }

  static bool _isUsableClientName(String? name, int? id) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return false;
    if (id != null && n == id.toString()) return false;
    if (n.toLowerCase().startsWith('client #') &&
        id != null &&
        n == 'Client #$id') {
      return false;
    }
    return true;
  }

  static List<ProjectManagerFilterItem> _byClient(
    List<ProjectModel> projects, {
    bool allowNameFallback = false,
  }) {
    final nameToId = <String, int>{};
    for (final p in projects) {
      final id = OdooFieldParsers.parseId(p.partnerId);
      final name = _norm(p.partnerName);
      if (id != null &&
          id > 0 &&
          _isUsableClientName(p.partnerName, id) &&
          name.isNotEmpty) {
        nameToId[name] = id;
      }
    }
    for (final p in projects) {
      final name = _norm(p.partnerName);
      if (!_isUsableClientName(p.partnerName, OdooFieldParsers.parseId(p.partnerId))) {
        continue;
      }
      if (name.isEmpty || nameToId.containsKey(name)) continue;
      nameToId[name] = -(name.hashCode.abs() + 1);
    }

    final buckets = <int, _Bucket>{};

    for (final p in projects) {
      var id = OdooFieldParsers.parseId(p.partnerId);
      var name = (p.partnerName ?? '').trim();
      if (!_isUsableClientName(name, id)) {
        name = '';
      }
      if (name.isEmpty) {
        if (id == null || id <= 0) continue;
        name = 'Client #$id';
      }

      if ((id == null || id <= 0) && allowNameFallback) {
        id = nameToId[_norm(name)];
      }
      if (id == null || id == 0) continue;

      final resolvedId = id;
      final bucket = buckets.putIfAbsent(
        resolvedId,
        () => _Bucket(id: resolvedId, name: name, photoUrl: p.clientImageUrl),
      );
      if (!_isUsableClientName(bucket.name, resolvedId) &&
          _isUsableClientName(name, resolvedId)) {
        bucket.name = name;
      } else if (bucket.name.isEmpty && name.isNotEmpty) {
        bucket.name = name;
      }
      if ((bucket.photoUrl == null || bucket.photoUrl!.isEmpty) &&
          (p.clientImageUrl != null && p.clientImageUrl!.isNotEmpty)) {
        bucket.photoUrl = p.clientImageUrl;
      }
      bucket.count++;
      bucket.touchDate(p.dateStart.isNotEmpty ? p.dateStart : p.date);
    }

    return _sortedItems(buckets);
  }

  static List<ProjectManagerFilterItem> _byCity(
    List<ProjectModel> projects, {
    bool allowNameFallback = false,
  }) {
    final nameToId = <String, int>{};
    for (final p in projects) {
      final id = p.cityId;
      final name = _norm(p.cityName);
      if (id != null && id > 0 && name.isNotEmpty) {
        nameToId[name] = id;
      }
    }
    for (final p in projects) {
      final name = _norm(p.cityName);
      if (name.isEmpty || nameToId.containsKey(name)) continue;
      nameToId[name] = -(name.hashCode.abs() + 1);
    }

    final buckets = <int, _Bucket>{};

    for (final p in projects) {
      var id = p.cityId;
      var name = (p.cityName ?? '').trim();
      if (name.isEmpty) continue;

      if ((id == null || id <= 0) && allowNameFallback && name.isNotEmpty) {
        id = nameToId[_norm(name)];
      }
      if (id == null || id == 0) continue;

      final resolvedId = id;
      final bucket = buckets.putIfAbsent(
        resolvedId,
        () => _Bucket(id: resolvedId, name: name),
      );
      bucket.count++;
      bucket.touchDate(p.dateStart.isNotEmpty ? p.dateStart : p.date);
    }

    return _sortedItems(buckets);
  }

  static List<ProjectManagerFilterItem> _sortedItems(Map<int, _Bucket> buckets) {
    return buckets.values
        .map(
          (b) => ProjectManagerFilterItem(
            id: b.id,
            name: b.name,
            photoUrl: b.photoUrl,
            projectCount: b.count,
            lastUpdate: b.lastUpdate,
          ),
        )
        .toList()
      ..sort((a, b) => b.projectCount.compareTo(a.projectCount));
  }
}

class _Bucket {
  _Bucket({
    required this.id,
    required this.name,
    this.photoUrl,
  });

  final int id;
  String name;
  String? photoUrl;
  int count = 0;
  String? lastUpdate;

  void touchDate(String raw) {
    if (raw.isEmpty) return;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return;
    final iso = parsed.toIso8601String();
    if (lastUpdate == null || iso.compareTo(lastUpdate!) > 0) {
      lastUpdate = iso;
    }
  }
}

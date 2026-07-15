import 'package:el_race/ui/presentation/my_projects/data/models/user_project_model.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_aggregator.dart';

class ClientInProgressBarData {
  const ClientInProgressBarData({
    required this.clientKey,
    required this.clientName,
    required this.logoUrl,
    required this.projectCount,
    required this.projects,
  });

  final String clientKey;
  final String clientName;
  final String logoUrl;
  final int projectCount;
  final List<ProjectEntity> projects;
}

class ClientInProgressGrouper {
  static List<ClientInProgressBarData> group(
    List<ProjectEntity> projects, {
    List<UserProjectModel>? agreements,
  }) {
    final agreementToClient = _agreementClientLookup(agreements);

    final map = <String, List<ProjectEntity>>{};
    final names = <String, String>{};
    final logos = <String, String>{};

    for (final p in projects) {
      if (p.isGeneralWo) continue;

      final name = _clientName(p, agreementToClient: agreementToClient);
      final key = name.trim().isNotEmpty
          ? name.trim().toLowerCase()
          : p.partnerId.toString();
      map.putIfAbsent(key, () => []).add(p);
      names[key] = name;
      final logo = ProjectsDashboardAggregator.normalizePhotoUrl(
        p.clientImageUrl,
      );
      if (logo.isNotEmpty) logos[key] = logo;
    }

    final bars = map.entries.map((e) {
      return ClientInProgressBarData(
        clientKey: e.key,
        clientName: names[e.key] ?? e.key,
        logoUrl: logos[e.key] ?? '',
        projectCount: e.value.length,
        projects: e.value,
      );
    }).toList();

    bars.sort((a, b) => b.projectCount.compareTo(a.projectCount));
    return bars;
  }

  static Map<String, String> _agreementClientLookup(
    List<UserProjectModel>? agreements,
  ) {
    if (agreements == null || agreements.isEmpty) return const {};

    final out = <String, String>{};
    for (final a in agreements) {
      final client = a.projectName.trim();
      if (client.isEmpty) continue;

      for (final key in [
        a.agreementName,
        a.agreementNo,
        a.agreementId?.toString(),
      ]) {
        final norm = key?.trim().toLowerCase();
        if (norm != null && norm.isNotEmpty) out[norm] = client;
      }
    }
    return out;
  }

  static String _clientName(
    ProjectEntity p, {
    Map<String, String> agreementToClient = const {},
  }) {
    final partnerName = p.partnerName?.trim();
    if (partnerName != null &&
        partnerName.isNotEmpty &&
        int.tryParse(partnerName) == null) {
      return partnerName;
    }

    final partner = p.partnerId.trim();
    if (partner.isNotEmpty &&
        partner != 'false' &&
        partner != '0' &&
        int.tryParse(partner) == null) {
      return partner;
    }

    final agreementKey = p.agreementId.trim().toLowerCase();
    if (agreementKey.isNotEmpty && agreementToClient.containsKey(agreementKey)) {
      return agreementToClient[agreementKey]!;
    }

    return p.name;
  }
}

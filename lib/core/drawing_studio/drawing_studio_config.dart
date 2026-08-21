import 'package:el_race/core/drawing_studio/drawing_studio_project.dart';

/// `GET /studio/config` bundle — enums, templates, limits, costs.
class DrawingStudioConfig {
  const DrawingStudioConfig({
    required this.enums,
    required this.templates,
    required this.validationLimits,
    required this.costEstimates,
  });

  /// fieldKey → optionKey → { en, ar }
  final Map<String, Map<String, Map<String, String>>> enums;

  /// templateId → template map (includes rooms)
  final Map<String, Map<String, dynamic>> templates;

  final Map<String, Map<String, dynamic>> validationLimits;
  final Map<String, dynamic> costEstimates;

  factory DrawingStudioConfig.fromJson(Map<String, dynamic> json) {
    final enums = <String, Map<String, Map<String, String>>>{};
    final rawEnums = json['enums'];
    if (rawEnums is Map) {
      rawEnums.forEach((field, options) {
        if (options is! Map) return;
        final parsed = <String, Map<String, String>>{};
        options.forEach((optKey, labels) {
          if (labels is Map) {
            parsed[optKey.toString()] = {
              'en': labels['en']?.toString() ?? optKey.toString(),
              'ar': labels['ar']?.toString() ?? '',
            };
          } else if (labels != null) {
            parsed[optKey.toString()] = {
              'en': labels.toString(),
              'ar': '',
            };
          }
        });
        enums[field.toString()] = parsed;
      });
    }

    final templates = <String, Map<String, dynamic>>{};
    final rawTemplates = json['templates'];
    if (rawTemplates is Map) {
      rawTemplates.forEach((k, v) {
        if (v is Map) {
          templates[k.toString()] = Map<String, dynamic>.from(v);
        }
      });
    }

    final limits = <String, Map<String, dynamic>>{};
    final rawLimits = json['validation_limits'];
    if (rawLimits is Map) {
      rawLimits.forEach((k, v) {
        if (v is Map) {
          limits[k.toString()] = Map<String, dynamic>.from(v);
        }
      });
    }

    final costs = <String, dynamic>{};
    final rawCosts = json['cost_estimates'];
    if (rawCosts is Map) {
      costs.addAll(Map<String, dynamic>.from(rawCosts));
    }

    return DrawingStudioConfig(
      enums: enums,
      templates: templates,
      validationLimits: limits,
      costEstimates: costs,
    );
  }

  List<String> enumKeys(String field) {
    final map = enums[field];
    if (map == null) return const [];
    return map.keys.toList();
  }

  String enumLabel(String field, String key, {String lang = 'en'}) {
    final labels = enums[field]?[key];
    if (labels == null) return key;
    final preferred = labels[lang]?.trim();
    if (preferred != null && preferred.isNotEmpty) return preferred;
    return labels['en'] ?? key;
  }

  double? limitMin(String field) {
    final v = validationLimits[field]?['min'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  double? limitMax(String field) {
    final v = validationLimits[field]?['max'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  String? costHint(String outputKey) {
    final v = costEstimates[outputKey];
    if (v == null) return null;
    if (v is num) return '~${v.toString()} credits';
    return v.toString();
  }

  List<Map<String, dynamic>> templateRooms(String templateId) {
    final t = templates[templateId];
    if (t == null) return const [];
    final rooms = t['rooms'];
    if (rooms is! List) return const [];
    return rooms
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String templateName(String templateId) {
    final t = templates[templateId];
    if (t == null) return templateId;
    return (t['name'] ?? t['title'] ?? templateId).toString();
  }
}

class DrawingStudioFormIssue {
  const DrawingStudioFormIssue({
    required this.field,
    required this.message,
    this.rule,
    this.severity = 'error',
  });

  final String field;
  final String message;
  final String? rule;
  final String severity;

  factory DrawingStudioFormIssue.fromJson(Map<String, dynamic> json) {
    return DrawingStudioFormIssue(
      field: (json['field'] ?? '').toString(),
      message: (json['message'] ?? 'Invalid value').toString(),
      rule: json['rule']?.toString(),
      severity: (json['severity'] ?? 'error').toString(),
    );
  }
}

class DrawingStudioGenerateAccepted {
  const DrawingStudioGenerateAccepted({
    required this.projectId,
    required this.status,
    this.title,
    this.slug,
    this.progress,
  });

  final String projectId;
  final String status;
  final String? title;
  final String? slug;
  final DrawingStudioProgress? progress;

  factory DrawingStudioGenerateAccepted.fromJson(Map<String, dynamic> json) {
    return DrawingStudioGenerateAccepted(
      projectId: (json['project_id'] ?? json['projectId'] ?? '').toString(),
      status: (json['status'] ?? 'processing').toString(),
      title: json['title']?.toString(),
      slug: json['slug']?.toString(),
      progress: DrawingStudioProgress.tryParse(json['progress']),
    );
  }
}

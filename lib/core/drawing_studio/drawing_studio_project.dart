/// Image asset attached to a Drawing Studio project.
class DrawingStudioProjectImage {
  const DrawingStudioProjectImage({
    required this.title,
    required this.url,
    this.thumbnailUrl,
    this.kind,
  });

  final String title;
  final String url;
  final String? thumbnailUrl;

  /// e.g. elevation / section — `plan_base` is excluded from gallery.
  final String? kind;

  bool get isPlanBase =>
      (kind ?? '').trim().toLowerCase() == 'plan_base';

  factory DrawingStudioProjectImage.fromJson(Map<String, dynamic> json) {
    final url = (json['url'] ??
            json['image_url'] ??
            json['imageUrl'] ??
            json['src'] ??
            '')
        .toString();
    final title = (json['title'] ??
            json['name'] ??
            json['label'] ??
            'Image')
        .toString();
    final thumb =
        json['thumbnail_url'] ?? json['thumbnailUrl'] ?? json['thumb'] ?? url;
    final kind = json['kind']?.toString();
    return DrawingStudioProjectImage(
      title: title.trim().isEmpty ? 'Image' : title.trim(),
      url: url,
      thumbnailUrl: thumb?.toString(),
      kind: kind?.trim().isEmpty == true ? null : kind?.trim(),
    );
  }
}

/// One step in `progress.queue` / `progress.completed` / `progress.current`.
class DrawingStudioProgressStep {
  const DrawingStudioProgressStep({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  factory DrawingStudioProgressStep.fromJson(Map<String, dynamic> json) {
    return DrawingStudioProgressStep(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? json['id'] ?? '').toString(),
    );
  }
}

/// Server-reported generation progress — never invent client-side %.
class DrawingStudioProgress {
  const DrawingStudioProgress({
    required this.percent,
    this.stage,
    this.label,
    this.current,
    this.queue = const [],
    this.completed = const [],
  });

  final int percent;
  final String? stage;
  final String? label;
  final DrawingStudioProgressStep? current;
  final List<DrawingStudioProgressStep> queue;
  final List<DrawingStudioProgressStep> completed;

  String get nowBuildingLabel {
    final fromLabel = label?.trim();
    if (fromLabel != null && fromLabel.isNotEmpty) return fromLabel;
    final fromCurrent = current?.label.trim();
    if (fromCurrent != null && fromCurrent.isNotEmpty) return fromCurrent;
    return 'Working…';
  }

  factory DrawingStudioProgress.fromJson(Map<String, dynamic> json) {
    final percentRaw = json['percent'];
    int percent = 0;
    if (percentRaw is num) {
      percent = percentRaw.round().clamp(0, 100);
    } else {
      percent = (int.tryParse(percentRaw?.toString() ?? '') ?? 0).clamp(0, 100);
    }

    DrawingStudioProgressStep? current;
    final rawCurrent = json['current'];
    if (rawCurrent is Map) {
      current = DrawingStudioProgressStep.fromJson(
        Map<String, dynamic>.from(rawCurrent),
      );
    }

    return DrawingStudioProgress(
      percent: percent,
      stage: json['stage']?.toString(),
      label: json['label']?.toString(),
      current: current,
      queue: _parseSteps(json['queue']),
      completed: _parseSteps(json['completed']),
    );
  }

  static DrawingStudioProgress? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    return DrawingStudioProgress.fromJson(Map<String, dynamic>.from(raw));
  }

  static List<DrawingStudioProgressStep> _parseSteps(dynamic raw) {
    if (raw is! List) return const [];
    final out = <DrawingStudioProgressStep>[];
    for (final item in raw) {
      if (item is Map) {
        out.add(
          DrawingStudioProgressStep.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
    return out;
  }
}

/// Project row / detail from Drawing Studio APIs.
class DrawingStudioProject {
  const DrawingStudioProject({
    required this.projectId,
    required this.title,
    required this.status,
    this.createdAt,
    this.briefPreview,
    this.pdfUrl,
    this.pdfName,
    this.images = const [],
    this.progress,
  });

  final String projectId;
  final String title;
  final String status;
  final DateTime? createdAt;
  final String? briefPreview;
  final String? pdfUrl;
  final String? pdfName;
  final List<DrawingStudioProjectImage> images;
  final DrawingStudioProgress? progress;

  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isFailed => status.toLowerCase() == 'failed';
  bool get isProcessing {
    final s = status.toLowerCase();
    return s == 'processing' || s == 'pending' || s == 'in_progress';
  }

  factory DrawingStudioProject.fromJson(Map<String, dynamic> json) {
    final id = json['project_id'] ?? json['id'] ?? json['projectId'];
    final createdRaw = json['created_at'] ?? json['createdAt'];
    DateTime? createdAt;
    if (createdRaw is String && createdRaw.isNotEmpty) {
      createdAt = DateTime.tryParse(createdRaw);
    }

    final images = <DrawingStudioProjectImage>[];
    final rawImages = json['images'] ?? json['gallery'] ?? json['assets'];
    if (rawImages is List) {
      for (final item in rawImages) {
        if (item is Map) {
          final image = DrawingStudioProjectImage.fromJson(
            Map<String, dynamic>.from(item),
          );
          // Backend excludes plan_base; filter client-side as a safety net.
          if (image.url.isNotEmpty && !image.isPlanBase) {
            images.add(image);
          }
        }
      }
    }

    return DrawingStudioProject(
      projectId: id?.toString() ?? '',
      title: (json['title'] ?? json['name'] ?? 'Untitled').toString(),
      status: (json['status'] ?? 'unknown').toString(),
      createdAt: createdAt,
      briefPreview: _stringOrNull(
        json['brief_preview'] ??
            json['briefPreview'] ??
            json['subtitle'] ??
            json['summary'] ??
            json['context'],
      ),
      pdfUrl: _stringOrNull(json['pdf_url'] ?? json['pdfUrl']),
      pdfName: _stringOrNull(
        json['pdf_name'] ?? json['pdfName'] ?? json['pdf_filename'],
      ),
      images: images,
      progress: DrawingStudioProgress.tryParse(json['progress']),
    );
  }

  DrawingStudioProject copyWith({
    String? title,
    String? status,
    DateTime? createdAt,
    String? briefPreview,
    String? pdfUrl,
    String? pdfName,
    List<DrawingStudioProjectImage>? images,
    DrawingStudioProgress? progress,
  }) {
    return DrawingStudioProject(
      projectId: projectId,
      title: title ?? this.title,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      briefPreview: briefPreview ?? this.briefPreview,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      pdfName: pdfName ?? this.pdfName,
      images: images ?? this.images,
      progress: progress ?? this.progress,
    );
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

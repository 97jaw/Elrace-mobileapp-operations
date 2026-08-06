import 'package:cloud_firestore/cloud_firestore.dart';

enum NoteType { text, audio, image }

enum TranscriptionStatus { pending, processing, done, error }

class NoteModel {
  final String id;
  final String ownerId;
  final String title;
  final String content;
  final NoteType noteType;
  final List<String> tags;
  final bool isImportant;
  final bool isTodo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? aiSummary;
  final List<ActionItem> actionItems;
  final RecordingInfo? recording;
  final List<ImageAttachment> images;

  const NoteModel({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.content,
    this.noteType = NoteType.text,
    this.tags = const [],
    this.isImportant = false,
    this.isTodo = false,
    required this.createdAt,
    required this.updatedAt,
    this.aiSummary,
    this.actionItems = const [],
    this.recording,
    this.images = const [],
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] ?? '',
      ownerId: json['ownerId'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? json['description'] ?? '',
      noteType: NoteType.values.firstWhere(
        (e) => e.name == json['noteType'],
        orElse: () => NoteType.text,
      ),
      tags: List<String>.from(json['tags'] ?? []),
      isImportant: json['isImportant'] ?? false,
      isTodo: json['isTodo'] ?? false,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
      aiSummary: json['aiSummary'],
      actionItems: (json['actionItems'] as List<dynamic>?)
              ?.map((e) => ActionItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recording: json['recording'] != null
          ? RecordingInfo.fromJson(json['recording'] as Map<String, dynamic>)
          : null,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => ImageAttachment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory NoteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NoteModel.fromJson({
      'id': doc.id,
      ...data,
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'title': title,
      'content': content,
      'noteType': noteType.name,
      'tags': tags,
      'isImportant': isImportant,
      'isTodo': isTodo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (aiSummary != null) 'aiSummary': aiSummary,
      'actionItems': actionItems.map((e) => e.toJson()).toList(),
      if (recording != null) 'recording': recording!.toJson(),
      'images': images.map((e) => e.toJson()).toList(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'title': title,
      'content': content,
      'noteType': noteType.name,
      'tags': tags,
      'isImportant': isImportant,
      'isTodo': isTodo,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (aiSummary != null) 'aiSummary': aiSummary,
      'actionItems': actionItems.map((e) => e.toJson()).toList(),
      if (recording != null) 'recording': recording!.toJson(),
      'images': images.map((e) => e.toJson()).toList(),
    };
  }

  NoteModel copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? content,
    NoteType? noteType,
    List<String>? tags,
    bool? isImportant,
    bool? isTodo,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? aiSummary,
    List<ActionItem>? actionItems,
    RecordingInfo? recording,
    List<ImageAttachment>? images,
  }) {
    return NoteModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      content: content ?? this.content,
      noteType: noteType ?? this.noteType,
      tags: tags ?? this.tags,
      isImportant: isImportant ?? this.isImportant,
      isTodo: isTodo ?? this.isTodo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      aiSummary: aiSummary ?? this.aiSummary,
      actionItems: actionItems ?? this.actionItems,
      recording: recording ?? this.recording,
      images: images ?? this.images,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String get displayDate {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
  }

  String get subtitle {
    switch (noteType) {
      case NoteType.audio:
        final duration = recording?.durationSeconds ?? 0;
        final minutes = duration ~/ 60;
        final seconds = duration % 60;
        return '$displayDate · Audio ${minutes}m ${seconds}s';
      case NoteType.image:
        return '$displayDate · ${images.length} image${images.length != 1 ? 's' : ''}';
      case NoteType.text:
      default:
        return displayDate;
    }
  }
}

class ActionItem {
  final String id;
  final String description;
  final bool isDone;
  final DateTime? dueDate;

  const ActionItem({
    required this.id,
    required this.description,
    this.isDone = false,
    this.dueDate,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      id: json['id'] ?? '',
      description: json['description'] ?? '',
      isDone: json['isDone'] ?? false,
      dueDate: json['dueDate'] != null
          ? NoteModel._parseDateTime(json['dueDate'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'isDone': isDone,
      if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
    };
  }

  ActionItem copyWith({
    String? id,
    String? description,
    bool? isDone,
    DateTime? dueDate,
  }) {
    return ActionItem(
      id: id ?? this.id,
      description: description ?? this.description,
      isDone: isDone ?? this.isDone,
      dueDate: dueDate ?? this.dueDate,
    );
  }
}

class RecordingInfo {
  final String audioUrl;
  final int durationSeconds;
  final String language;
  final String? transcript;
  final TranscriptionStatus status;

  const RecordingInfo({
    required this.audioUrl,
    required this.durationSeconds,
    this.language = 'en',
    this.transcript,
    this.status = TranscriptionStatus.pending,
  });

  factory RecordingInfo.fromJson(Map<String, dynamic> json) {
    return RecordingInfo(
      audioUrl: json['audioUrl'] ?? '',
      durationSeconds: json['durationSeconds'] ?? 0,
      language: json['language'] ?? 'en',
      transcript: json['transcript'],
      status: TranscriptionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TranscriptionStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'audioUrl': audioUrl,
      'durationSeconds': durationSeconds,
      'language': language,
      if (transcript != null) 'transcript': transcript,
      'status': status.name,
    };
  }

  RecordingInfo copyWith({
    String? audioUrl,
    int? durationSeconds,
    String? language,
    String? transcript,
    TranscriptionStatus? status,
  }) {
    return RecordingInfo(
      audioUrl: audioUrl ?? this.audioUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      language: language ?? this.language,
      transcript: transcript ?? this.transcript,
      status: status ?? this.status,
    );
  }
}

class ImageAttachment {
  final String id;
  final String imageUrl;
  final String? thumbnailUrl;
  final String? caption;
  final DateTime addedAt;

  const ImageAttachment({
    required this.id,
    required this.imageUrl,
    this.thumbnailUrl,
    this.caption,
    required this.addedAt,
  });

  factory ImageAttachment.fromJson(Map<String, dynamic> json) {
    return ImageAttachment(
      id: json['id'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      thumbnailUrl: json['thumbnailUrl'],
      caption: json['caption'],
      addedAt: NoteModel._parseDateTime(json['addedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (caption != null) 'caption': caption,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  ImageAttachment copyWith({
    String? id,
    String? imageUrl,
    String? thumbnailUrl,
    String? caption,
    DateTime? addedAt,
  }) {
    return ImageAttachment(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      caption: caption ?? this.caption,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}

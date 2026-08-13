import 'package:cloud_firestore/cloud_firestore.dart';

enum NoteType { text, audio, image }

enum TranscriptionStatus { idle, pending, processing, done, error }

enum NoteAiMode { none, transcribe, summarize, bullets }

enum NoteAiStatus { none, pending, processing, done, error }

/// True when transcript should render RTL (forced AR or Arabic script).
bool noteTranscriptLooksArabic({String? language, String? transcript}) {
  if ((language ?? '').trim().toLowerCase() == 'ar') return true;
  final text = (transcript ?? '').trim();
  if (text.isEmpty) return false;
  return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
}

class NoteSharedMember {
  final String uid;
  final int? employeeId;
  final String name;
  final String? avatarUrl;

  const NoteSharedMember({
    required this.uid,
    this.employeeId,
    required this.name,
    this.avatarUrl,
  });

  factory NoteSharedMember.fromJson(Map<String, dynamic> json) {
    return NoteSharedMember(
      uid: json['uid']?.toString() ?? '',
      employeeId: json['employeeId'] is int
          ? json['employeeId'] as int
          : int.tryParse('${json['employeeId'] ?? ''}'),
      name: json['name']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      if (employeeId != null) 'employeeId': employeeId,
      'name': name,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };
  }
}

class SharedNoteRef {
  final String noteId;
  final String ownerId;
  final String title;
  final DateTime sharedAt;

  const SharedNoteRef({
    required this.noteId,
    required this.ownerId,
    required this.title,
    required this.sharedAt,
  });

  factory SharedNoteRef.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SharedNoteRef(
      noteId: data['noteId']?.toString() ?? doc.id,
      ownerId: data['ownerId']?.toString() ?? '',
      title: data['title']?.toString() ?? 'Shared note',
      sharedAt: NoteModel._parseDateTime(data['sharedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'noteId': noteId,
      'ownerId': ownerId,
      'title': title,
      'sharedAt': Timestamp.fromDate(sharedAt),
    };
  }
}

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
  final NoteAiMode aiMode;
  final String? aiContext;
  final NoteAiStatus aiStatus;
  final String? aiSummary;
  final String? aiBulletPoints;
  final String? translatedText;
  final String? translatedLanguage;
  final List<ActionItem> actionItems;
  final RecordingInfo? recording;
  final List<ImageAttachment> images;
  final List<String> sharedWithUids;
  final List<NoteSharedMember> sharedWith;

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
    this.aiMode = NoteAiMode.none,
    this.aiContext,
    this.aiStatus = NoteAiStatus.none,
    this.aiSummary,
    this.aiBulletPoints,
    this.translatedText,
    this.translatedLanguage,
    this.actionItems = const [],
    this.recording,
    this.images = const [],
    this.sharedWithUids = const [],
    this.sharedWith = const [],
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
      aiMode: NoteAiMode.values.firstWhere(
        (e) => e.name == json['aiMode'],
        orElse: () => NoteAiMode.none,
      ),
      aiContext: json['aiContext']?.toString(),
      aiStatus: NoteAiStatus.values.firstWhere(
        (e) => e.name == json['aiStatus'],
        orElse: () => NoteAiStatus.none,
      ),
      aiSummary: json['aiSummary']?.toString(),
      aiBulletPoints: json['aiBulletPoints']?.toString(),
      translatedText: json['translatedText']?.toString(),
      translatedLanguage: json['translatedLanguage']?.toString(),
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
      sharedWithUids: List<String>.from(json['sharedWithUids'] ?? []),
      sharedWith: (json['sharedWith'] as List<dynamic>?)
              ?.map((e) => NoteSharedMember.fromJson(e as Map<String, dynamic>))
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
      'aiMode': aiMode.name,
      if (aiContext != null) 'aiContext': aiContext,
      'aiStatus': aiStatus.name,
      if (aiSummary != null) 'aiSummary': aiSummary,
      if (aiBulletPoints != null) 'aiBulletPoints': aiBulletPoints,
      if (translatedText != null) 'translatedText': translatedText,
      if (translatedLanguage != null) 'translatedLanguage': translatedLanguage,
      'actionItems': actionItems.map((e) => e.toJson()).toList(),
      if (recording != null) 'recording': recording!.toJson(),
      'images': images.map((e) => e.toJson()).toList(),
      'sharedWithUids': sharedWithUids,
      'sharedWith': sharedWith.map((e) => e.toJson()).toList(),
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
      'aiMode': aiMode.name,
      if (aiContext != null) 'aiContext': aiContext,
      'aiStatus': aiStatus.name,
      if (aiSummary != null) 'aiSummary': aiSummary,
      if (aiBulletPoints != null) 'aiBulletPoints': aiBulletPoints,
      if (translatedText != null) 'translatedText': translatedText,
      if (translatedLanguage != null) 'translatedLanguage': translatedLanguage,
      'actionItems': actionItems.map((e) => e.toJson()).toList(),
      if (recording != null) 'recording': recording!.toJson(),
      'images': images.map((e) => e.toJson()).toList(),
      'sharedWithUids': sharedWithUids,
      'sharedWith': sharedWith.map((e) => e.toJson()).toList(),
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
    NoteAiMode? aiMode,
    String? aiContext,
    NoteAiStatus? aiStatus,
    String? aiSummary,
    String? aiBulletPoints,
    String? translatedText,
    String? translatedLanguage,
    List<ActionItem>? actionItems,
    RecordingInfo? recording,
    List<ImageAttachment>? images,
    List<String>? sharedWithUids,
    List<NoteSharedMember>? sharedWith,
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
      aiMode: aiMode ?? this.aiMode,
      aiContext: aiContext ?? this.aiContext,
      aiStatus: aiStatus ?? this.aiStatus,
      aiSummary: aiSummary ?? this.aiSummary,
      aiBulletPoints: aiBulletPoints ?? this.aiBulletPoints,
      translatedText: translatedText ?? this.translatedText,
      translatedLanguage: translatedLanguage ?? this.translatedLanguage,
      actionItems: actionItems ?? this.actionItems,
      recording: recording ?? this.recording,
      images: images ?? this.images,
      sharedWithUids: sharedWithUids ?? this.sharedWithUids,
      sharedWith: sharedWith ?? this.sharedWith,
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
        final hasAudio = recording?.audioUrl.isNotEmpty == true;
        if (!hasAudio) {
          return '$displayDate · Transcript saved';
        }
        final duration = recording?.durationSeconds ?? 0;
        final minutes = duration ~/ 60;
        final seconds = duration % 60;
        return '$displayDate · Audio ${minutes}m ${seconds}s';
      case NoteType.image:
        return '$displayDate · ${images.length} image${images.length != 1 ? 's' : ''}';
      case NoteType.text:
        return displayDate;
    }
  }

  bool get needsAiProcessing =>
      (aiMode == NoteAiMode.summarize || aiMode == NoteAiMode.bullets) &&
      (aiStatus == NoteAiStatus.pending || aiStatus == NoteAiStatus.none);
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
  final String? storagePath;

  const RecordingInfo({
    required this.audioUrl,
    required this.durationSeconds,
    this.language = 'en',
    this.transcript,
    this.status = TranscriptionStatus.idle,
    this.storagePath,
  });

  factory RecordingInfo.fromJson(Map<String, dynamic> json) {
    return RecordingInfo(
      audioUrl: json['audioUrl'] ?? '',
      durationSeconds: json['durationSeconds'] ?? 0,
      language: json['language'] ?? 'en',
      transcript: json['transcript'],
      status: TranscriptionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TranscriptionStatus.idle,
      ),
      storagePath: json['storagePath']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'audioUrl': audioUrl,
      'durationSeconds': durationSeconds,
      'language': language,
      if (transcript != null) 'transcript': transcript,
      'status': status.name,
      if (storagePath != null) 'storagePath': storagePath,
    };
  }

  RecordingInfo copyWith({
    String? audioUrl,
    int? durationSeconds,
    String? language,
    String? transcript,
    TranscriptionStatus? status,
    String? storagePath,
  }) {
    return RecordingInfo(
      audioUrl: audioUrl ?? this.audioUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      language: language ?? this.language,
      transcript: transcript ?? this.transcript,
      status: status ?? this.status,
      storagePath: storagePath ?? this.storagePath,
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

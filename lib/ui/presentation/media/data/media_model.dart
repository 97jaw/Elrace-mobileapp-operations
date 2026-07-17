enum MediaType { image, video }

// Helper function to encode URLs with spaces
String _encodeUrl(String url) {
  if (url.isEmpty) return url;

  // Split the URL to handle the path part separately
  Uri uri = Uri.parse(url);

  // Reconstruct the URL with properly encoded path segments
  List<String> encodedSegments = uri.pathSegments.map((segment) {
    return Uri.encodeComponent(segment);
  }).toList();

  String encodedPath = '/${encodedSegments.join('/')}';

  // Reconstruct the full URL
  String encodedUrl = '${uri.scheme}://${uri.host}$encodedPath';

  // Add query parameters if they exist
  if (uri.query.isNotEmpty) {
    encodedUrl += '?${uri.query}';
  }

  return encodedUrl;
}

class MediaModel {
  final String id;
  final String name;
  final String url;
  final String? xWebUrl;
  final MediaType type;
  final DateTime dateCreated;
  final int? duration;
  final double? size;
  final String? thumbnail;
  final String? client;
  final String? clientLogo;
  final String? description;
  final dynamic view360;
  /// From Odoo `ir.attachment.is_favorite` (via get_media `is_favorite`).
  final bool isFavorite;

  const MediaModel({
    required this.id,
    required this.name,
    required this.url,
    this.xWebUrl,
    required this.type,
    required this.dateCreated,
    this.duration,
    this.size,
    this.thumbnail,
    this.client,
    this.clientLogo,
    this.description,
    this.view360,
    this.isFavorite = false,
  });

  factory MediaModel.fromJson(Map<String, dynamic> json) {
    String fileName = json['name'] ?? '';
    String mainUrl = json['url'] ?? '';
    String s3Url = json['x_web_url'] ?? '';

    // Use S3 URL as preview if main URL is empty or use main URL
    String previewUrl = mainUrl.isNotEmpty ? mainUrl : s3Url;

    // Parse date from API or use current date as fallback
    DateTime parsedDate = DateTime.now();
    if (json['date'] != null && json['date'].toString().isNotEmpty) {
      try {
        parsedDate = DateTime.parse(json['date'].toString());
      } catch (e) {
        parsedDate = DateTime.now();
      }
    }

    return MediaModel(
      id: json['id']?.toString() ?? '',
      name: fileName,
      url: previewUrl,
      xWebUrl: s3Url,
      type: getMediaTypeFromExtension(fileName.split('.').last),
      dateCreated: parsedDate,
      duration: json['duration'],
      size: json['size']?.toDouble(),
      thumbnail: json['thumbnail']?.toString(),
      client: json['client']?.toString(),
      clientLogo: _parseClientLogo(json),
      description: json['description']?.toString(),
      view360: json['360_view'],
      isFavorite: _parseBool(json['is_favorite']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'x_web_url': xWebUrl,
      'thumbnail': thumbnail,
      'client': client,
      'client_logo': clientLogo,
      'description': description,
      '360_view': view360,
      'is_favorite': isFavorite,
      'type': type.name,
      'dateCreated': dateCreated.toIso8601String(),
      'duration': duration,
      'size': size,
    };
  }

  MediaModel copyWith({
    String? id,
    String? name,
    String? url,
    String? xWebUrl,
    MediaType? type,
    DateTime? dateCreated,
    int? duration,
    double? size,
    String? thumbnail,
    String? client,
    String? clientLogo,
    String? description,
    dynamic view360,
    bool? isFavorite,
  }) {
    return MediaModel(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      xWebUrl: xWebUrl ?? this.xWebUrl,
      type: type ?? this.type,
      dateCreated: dateCreated ?? this.dateCreated,
      duration: duration ?? this.duration,
      size: size ?? this.size,
      thumbnail: thumbnail ?? this.thumbnail,
      client: client ?? this.client,
      clientLogo: clientLogo ?? this.clientLogo,
      description: description ?? this.description,
      view360: view360 ?? this.view360,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  bool get isImage => type == MediaType.image;
  bool get isVideo => type == MediaType.video;

  // Remove file extension from name
  String get displayName {
    if (name.contains('.')) {
      return name.substring(0, name.lastIndexOf('.'));
    }
    return name;
  }

  // Use the URL for streaming/preview (prefer thumbnail if available)
  String get previewUrl {
    if (thumbnail != null && thumbnail!.isNotEmpty) {
      return _encodeUrl(thumbnail!);
    }
    if (url.isNotEmpty) return _encodeUrl(url);
    if (xWebUrl != null && xWebUrl!.isNotEmpty) return _encodeUrl(xWebUrl!);
    return url;
  }

  // For download, we can add query parameters to force download
  String get downloadUrl {
    if (xWebUrl != null && xWebUrl!.isNotEmpty) {
      String encodedUrl = _encodeUrl(xWebUrl!);
      // Add response-content-disposition parameter to force download
      if (encodedUrl.contains('s3.amazonaws.com')) {
        return '$encodedUrl?response-content-disposition=attachment';
      }
      return encodedUrl;
    }
    return _encodeUrl(url);
  }

  // For streaming, ensure we don't have download parameters and handle URL encoding
  String get streamingUrl {
    String cleanUrl = url;

    // Remove any download parameters
    if (cleanUrl.contains('?response-content-disposition')) {
      cleanUrl = cleanUrl.split('?')[0];
    }

    // Encode the URL to handle spaces and special characters
    cleanUrl = _encodeUrl(cleanUrl);

    // For S3 URLs, we can add streaming-friendly parameters
    if (cleanUrl.contains('s3.amazonaws.com') && isVideo) {
      // For HLS streams, don't add content-type parameter as it can interfere
      if (!cleanUrl.contains('.m3u8')) {
        cleanUrl += '?response-content-type=video/$fileExtension';
      }
    }

    return cleanUrl;
  }

  String get fileExtension {
    String fileName = url.split('/').last;
    if (fileName.contains('.')) {
      return fileName.split('.').last.toLowerCase();
    }
    return '';
  }

  static bool _parseBool(dynamic value) {
    if (value == true || value == 1) return true;
    if (value == false || value == 0 || value == null) return false;
    if (value is String) {
      final s = value.trim().toLowerCase();
      return s == 'true' || s == '1';
    }
    return false;
  }

  static String? _parseClientLogo(Map<String, dynamic> json) {
    for (final key in [
      'client_logo',
      'client_image',
      'client_image_url',
      'logo_url',
      'company_logo',
    ]) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static MediaType getMediaTypeFromExtension(String extension) {
    const imageExtensions = ['jpg', 'jpeg', 'png', 'bmp', 'webp'];
    const videoExtensions = [
      'mp4',
      'avi',
      'mov',
      'wmv',
      'flv',
      'webm',
      'mkv',
      'gif',
      'm3u8'
    ];

    if (imageExtensions.contains(extension.toLowerCase())) {
      return MediaType.image;
    } else if (videoExtensions.contains(extension.toLowerCase())) {
      return MediaType.video;
    }
    return MediaType.image;
  }
}

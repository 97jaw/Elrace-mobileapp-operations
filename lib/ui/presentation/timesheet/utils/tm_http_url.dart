import 'dart:io';

import 'package:flutter/foundation.dart';

/// Normalize + encode S3 / cloud http(s) URLs for download.
///
/// - Rewrites `bucket.s3.{region}.amazonaws.com` → `bucket.s3.amazonaws.com`
/// - Encodes path segments (spaces / unicode)
/// - Preserves query string (required for AWS **presigned** URLs)
Uri? tmEncodedHttpUri(String? raw) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty) return null;

  // Prefer full Uri.parse when already a well-formed encoded URI (presigned).
  final parsed = Uri.tryParse(trimmed);
  if (parsed != null &&
      parsed.hasScheme &&
      (parsed.isScheme('http') || parsed.isScheme('https')) &&
      !trimmed.contains(' ')) {
    // Presigned URLs are typically already encoded. Re-encoding path segments
    // can turn `%20` into `%2520` and invalidate AWS signatures.
    return parsed.replace(host: _normalizeS3Host(parsed.host));
  }

  final match = RegExp(
    r'^(https?):\/\/([^\/\?\s]+)(\/[^?]*)?(\?.*)?$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (match == null) {
    if (parsed == null || !parsed.hasScheme) return null;
    // Keep original encoding when URI is already parseable.
    return parsed.replace(host: _normalizeS3Host(parsed.host));
  }

  final scheme = match.group(1)!.toLowerCase();
  final host = _normalizeS3Host(match.group(2)!);
  final pathPart = match.group(3) ?? '';
  final queryPart = match.group(4);

  final segments = pathPart
      .split('/')
      .where((s) => s.isNotEmpty)
      .map(_encodePathSegment)
      .toList();

  return Uri(
    scheme: scheme,
    host: host,
    pathSegments: segments,
    query: queryPart == null || queryPart.isEmpty
        ? null
        : queryPart.startsWith('?')
            ? queryPart.substring(1)
            : queryPart,
  );
}

String? tmEncodedHttpUrlString(String? raw) {
  return tmEncodedHttpUri(raw)?.toString();
}

/// `bucket.s3.eu-north-1.amazonaws.com` → `bucket.s3.amazonaws.com`
String _normalizeS3Host(String host) {
  final m = RegExp(
    r'^(.+)\.s3\.[a-z0-9-]+\.amazonaws\.com$',
    caseSensitive: false,
  ).firstMatch(host);
  if (m != null) {
    return '${m.group(1)}.s3.amazonaws.com';
  }
  return host;
}

String _encodePathSegment(String segment) {
  try {
    return Uri.encodeComponent(Uri.decodeComponent(segment));
  } catch (_) {
    return Uri.encodeComponent(segment);
  }
}

/// Reliable byte fetch for S3 / cloud files (supports presigned query URLs).
Future<Uint8List> tmFetchUrlBytes(
  String rawUrl, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final uri = tmEncodedHttpUri(rawUrl);
  if (uri == null) {
    throw ArgumentError('Invalid URL: $rawUrl');
  }

  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(uri).timeout(timeout);
    request.followRedirects = true;
    request.maxRedirects = 5;
    final response = await request.close().timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw HttpException(
        'HTTP ${response.statusCode} for $uri',
        uri: uri,
      );
    }
    return await consolidateHttpClientResponseBytes(response);
  } finally {
    client.close(force: true);
  }
}

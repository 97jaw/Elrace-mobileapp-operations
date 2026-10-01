import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../data/content_model.dart';

/// Downloaded Photos-tab file; PDF pages are exposed as photos.
class MediaPdfDocument {
  MediaPdfDocument._({
    required this.file,
    required this.bytes,
    required this.isPdf,
    required this.pageSizes,
  });

  final File file;
  final Uint8List bytes;
  final bool isPdf;

  /// Page sizes in PDF points; a single entry for plain images.
  final List<Size> pageSizes;

  int get pageCount => pageSizes.length;

  final LinkedHashMap<String, Uint8List> _rendered = LinkedHashMap();
  final Map<String, Future<Uint8List>> _inFlight = {};
  Future<void> _queue = Future.value();
  int _renderedBytes = 0;

  static const int _maxRenderedBytes = 48 * 1024 * 1024;

  double aspectRatio(int page) {
    final size = pageSizes[page.clamp(0, pageCount - 1)];
    if (size.width <= 0 || size.height <= 0) return 3 / 4;
    return size.width / size.height;
  }

  /// PNG bytes for [page] rendered about [targetWidthPx] pixels wide.
  Future<Uint8List> page(int page, {required double targetWidthPx}) {
    if (!isPdf) return Future.value(bytes);
    final index = page.clamp(0, pageCount - 1);
    final widthPt = pageSizes[index].width > 0 ? pageSizes[index].width : 595;
    final dpi = (targetWidthPx / (widthPt / 72)).clamp(24.0, 300.0);
    final key = '$index@${dpi.round()}';

    final cached = _rendered.remove(key);
    if (cached != null) {
      _rendered[key] = cached;
      return Future.value(cached);
    }
    final pending = _inFlight[key];
    if (pending != null) return pending;

    // The platform rasteriser copes badly with parallel jobs; run one at a time.
    final job = _queue.then((_) async {
      final raster =
          await Printing.raster(bytes, pages: [index], dpi: dpi).first;
      final png = await raster.toPng();
      _rendered[key] = png;
      _renderedBytes += png.length;
      while (_renderedBytes > _maxRenderedBytes && _rendered.length > 1) {
        final evicted = _rendered.remove(_rendered.keys.first)!;
        _renderedBytes -= evicted.length;
      }
      return png;
    });
    _queue = job.then((_) {}, onError: (_) {});
    _inFlight[key] = job;
    job.whenComplete(() => _inFlight.remove(key));
    return job;
  }
}

/// Loads and caches Photos-tab files (PDF or image) for cards and the viewer.
abstract final class MediaPdfPages {
  static final Map<String, Future<MediaPdfDocument>> _documents = {};
  static final Map<String, Uint8List> _covers = {};

  static const double coverWidthPx = 720;

  static int _activeDownloads = 0;
  static final Queue<Completer<void>> _waiting = Queue();
  static const int _maxParallelDownloads = 2;

  /// Signed preview URLs change on every fetch, so cache by record instead.
  static String cacheKey(ContentModel content) {
    final stamp = content.dateCreated?.millisecondsSinceEpoch ?? 0;
    return 'media_photo_${content.id}_$stamp';
  }

  static bool canRender(ContentModel content) =>
      !content.is360View && content.previewUrl.trim().isNotEmpty;

  static Uint8List? cachedCover(ContentModel content) =>
      _covers[cacheKey(content)];

  /// Downloads (or reuses) the file; [onProgress] reports 0..1 when known.
  static Future<MediaPdfDocument> load(
    ContentModel content, {
    Map<String, String>? headers,
    ValueChanged<double?>? onProgress,
  }) {
    final key = cacheKey(content);
    final existing = _documents[key];
    if (existing != null) return existing;

    final future = _load(content, key, headers, onProgress);
    _documents[key] = future;
    future.then((_) {}, onError: (Object _) => _documents.remove(key));
    return future;
  }

  /// First page as a card image, kept in memory and on disk.
  static Future<Uint8List> cover(
    ContentModel content, {
    Map<String, String>? headers,
  }) async {
    final key = cacheKey(content);
    final inMemory = _covers[key];
    if (inMemory != null) return inMemory;

    final coverKey = '${key}_cover';
    final onDisk = await DefaultCacheManager().getFileFromCache(coverKey);
    if (onDisk != null) {
      final bytes = await onDisk.file.readAsBytes();
      _covers[key] = bytes;
      return bytes;
    }

    final doc = await load(content, headers: headers);
    final bytes = await doc.page(0, targetWidthPx: coverWidthPx);
    _covers[key] = bytes;
    if (doc.isPdf) {
      unawaited(DefaultCacheManager()
          .putFile(coverKey, bytes, key: coverKey, fileExtension: 'png'));
    }
    return bytes;
  }

  static Future<MediaPdfDocument> _load(
    ContentModel content,
    String key,
    Map<String, String>? headers,
    ValueChanged<double?>? onProgress,
  ) async {
    await _acquireSlot();
    try {
      final file =
          await _download(content.previewUrl.trim(), key, headers, onProgress);
      final bytes = await file.readAsBytes();
      final isPdf = _looksLikePdf(bytes);
      final sizes =
          isPdf ? await compute(_readPageSizes, bytes) : const [Size(3, 4)];
      if (sizes.isEmpty) {
        throw const FormatException('The document has no pages.');
      }
      return MediaPdfDocument._(
        file: file,
        bytes: bytes,
        isPdf: isPdf,
        pageSizes: sizes,
      );
    } finally {
      _releaseSlot();
    }
  }

  static Future<File> _download(
    String url,
    String key,
    Map<String, String>? headers,
    ValueChanged<double?>? onProgress,
  ) async {
    final stream = DefaultCacheManager().getFileStream(
      url,
      key: key,
      headers: headers,
      withProgress: onProgress != null,
    );
    await for (final event in stream) {
      if (event is DownloadProgress) {
        onProgress?.call(event.progress);
      } else if (event is FileInfo) {
        return event.file;
      }
    }
    throw const HttpException('Download finished without a file.');
  }

  static bool _looksLikePdf(Uint8List bytes) {
    final limit = bytes.length < 1024 ? bytes.length : 1024;
    for (var i = 0; i + 4 < limit; i++) {
      if (bytes[i] == 0x25 && // %
          bytes[i + 1] == 0x50 && // P
          bytes[i + 2] == 0x44 && // D
          bytes[i + 3] == 0x46) {
        // F
        return true;
      }
    }
    return false;
  }

  static Future<void> _acquireSlot() {
    if (_activeDownloads < _maxParallelDownloads) {
      _activeDownloads++;
      return Future.value();
    }
    final waiter = Completer<void>();
    _waiting.add(waiter);
    return waiter.future;
  }

  static void _releaseSlot() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _activeDownloads--;
    }
  }
}

List<Size> _readPageSizes(Uint8List bytes) {
  final document = PdfDocument(inputBytes: bytes);
  try {
    return [
      for (var i = 0; i < document.pages.count; i++)
        Size(document.pages[i].size.width, document.pages[i].size.height),
    ];
  } finally {
    document.dispose();
  }
}

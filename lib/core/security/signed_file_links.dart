import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Swaps legacy `/my/public/file/<id>` links, and signed links that are about
/// to expire, for fresh `/public/v2/file/<id>/<exp>/<sig>` links issued by
/// `/api/v2/file_url`.
///
/// Signing is best-effort: without a session, or while the server lacks the
/// v2 endpoint, the original link is returned unchanged.
abstract final class SignedFileLinks {
  static final Uri _api = Uri.parse('${UrlUtil.baseUrl}v2/file_url');
  static final String _host = Uri.parse(UrlUtil.baseUrl).host;
  static final RegExp _legacyPath = RegExp(r'^/my/public/file/(\d+)/?$');
  static final RegExp _signedPath =
      RegExp(r'^/public/v2/file/(\d+)/(\d+)/[0-9a-f]{64}/?$');
  static final RegExp _anyFileLink = RegExp(
    r'/(?:my/public|public/v2)/file/(\d+)(?:/|$|\?)',
    caseSensitive: false,
  );

  static const Duration _refreshMargin = Duration(minutes: 10);
  static const Duration _unavailableBackoff = Duration(minutes: 10);
  static const Duration _batchWindow = Duration(milliseconds: 25);
  static const Duration _timeout = Duration(seconds: 8);
  static const int _maxBatch = 200;

  static final Map<int, _SignedLink> _cache = {};
  static final Map<int, Completer<Uri?>> _queued = {};
  static final Map<int, Completer<Uri?>> _inFlight = {};
  static Timer? _batchTimer;
  static DateTime? _unavailableUntil;

  static int? legacyAttachmentId(Uri url) {
    if (url.host != _host) return null;
    final match = _legacyPath.firstMatch(url.path);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// Attachment id of a legacy or signed ERP file link (any host/format).
  static int? attachmentIdOf(String url) {
    final match = _anyFileLink.firstMatch(url);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// True for legacy and signed ERP file links (extension-less binaries).
  static bool isFileLink(String url) => attachmentIdOf(url) != null;

  /// Stable image/file cache key: signed URLs change, the attachment does not.
  static String? cacheKeyFor(String url) {
    final id = attachmentIdOf(url);
    return id == null ? null : 'erp_file_$id';
  }

  static Future<Uri> resolve(Uri url) async {
    final legacyId = legacyAttachmentId(url);
    if (legacyId != null) return await _signedFor(legacyId) ?? url;

    if (url.host != _host) return url;
    final signed = _signedPath.firstMatch(url.path);
    if (signed == null) return url;
    final exp = int.tryParse(signed.group(2)!);
    final expiresAt =
        exp == null ? null : DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    if (expiresAt != null &&
        DateTime.now().add(_refreshMargin).isBefore(expiresAt)) {
      return url;
    }
    return await _signedFor(int.parse(signed.group(1)!)) ?? url;
  }

  static Future<String> resolveString(String url) async {
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null) return url;
    final resolved = await resolve(parsed);
    return identical(resolved, parsed) ? url : resolved.toString();
  }

  static void clear() {
    _cache.clear();
    _unavailableUntil = null;
  }

  static Future<Uri?> _signedFor(int id) {
    final cached = _cache[id];
    if (cached != null && cached.isFresh(_refreshMargin)) {
      return Future.value(cached.url);
    }
    final unavailableUntil = _unavailableUntil;
    if (unavailableUntil != null && DateTime.now().isBefore(unavailableUntil)) {
      return Future.value(null);
    }
    if (_token.isEmpty) return Future.value(null);

    final pending = _queued[id] ?? _inFlight[id];
    if (pending != null) return pending.future;

    final completer = Completer<Uri?>();
    _queued[id] = completer;
    _batchTimer ??= Timer(_batchWindow, _flush);
    return completer.future;
  }

  static String get _token {
    try {
      return SharedPref.getLoginData().result?.token ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> _flush() async {
    _batchTimer = null;
    final batch = Map.of(_queued);
    _queued.clear();
    _inFlight.addAll(batch);

    final ids = batch.keys.toList();
    for (var i = 0; i < ids.length; i += _maxBatch) {
      final chunk = ids.sublist(i, math.min(i + _maxBatch, ids.length));
      var links = const <int, _SignedLink>{};
      try {
        links = await _request(chunk);
      } catch (e) {
        debugPrint('SignedFileLinks: signing failed ($e)');
      }
      for (final id in chunk) {
        final link = links[id];
        if (link != null) _cache[id] = link;
        _inFlight.remove(id)?.complete(link?.url);
      }
    }
  }

  static Future<Map<int, _SignedLink>> _request(List<int> ids) async {
    final response = await http
        .post(
          _api,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $_token',
          },
          body: jsonEncode({
            'jsonrpc': '2.0',
            'params': {'attachment_ids': ids},
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 404) {
      _unavailableUntil = DateTime.now().add(_unavailableBackoff);
      return const {};
    }
    if (response.statusCode != 200) return const {};

    final decoded = jsonDecode(response.body);
    final result = decoded is Map ? decoded['result'] : null;
    if (result is! Map || result['status'] != 'success') return const {};
    final data = result['data'];
    if (data is! Map) return const {};
    final urls = data['urls'];
    final expiresIn = data['expires_in'];
    if (urls is! Map || expiresIn is! num) return const {};

    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn.toInt()));
    final links = <int, _SignedLink>{};
    urls.forEach((key, value) {
      final id = int.tryParse('$key');
      final url = value is String ? Uri.tryParse(value) : null;
      if (id != null && url != null) links[id] = _SignedLink(url, expiresAt);
    });
    return links;
  }
}

class _SignedLink {
  const _SignedLink(this.url, this.expiresAt);

  final Uri url;
  final DateTime expiresAt;

  bool isFresh(Duration margin) =>
      DateTime.now().add(margin).isBefore(expiresAt);
}

/// Routes every `dart:io` client (http, Dio, image/PDF loaders, cache manager)
/// through [SignedFileLinks] for GET/HEAD requests to legacy file links.
class SignedFileHttpOverrides extends HttpOverrides {
  SignedFileHttpOverrides([this._previous]);

  final HttpOverrides? _previous;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final inner =
        _previous?.createHttpClient(context) ?? super.createHttpClient(context);
    return _SignedFileHttpClient(inner);
  }
}

class _SignedFileHttpClient implements HttpClient {
  _SignedFileHttpClient(this._inner);

  final HttpClient _inner;

  Future<HttpClientRequest> _send(String method, Uri url) async {
    final upper = method.toUpperCase();
    if (upper == 'GET' || upper == 'HEAD') {
      url = await SignedFileLinks.resolve(url);
    }
    return _inner.openUrl(method, url);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _send(method, url);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _send('GET', url);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => _send('HEAD', url);

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) =>
      _inner.open(method, host, port, path);

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      _inner.get(host, port, path);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      _inner.head(host, port, path);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      _inner.post(host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => _inner.postUrl(url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      _inner.put(host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => _inner.putUrl(url);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      _inner.delete(host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => _inner.deleteUrl(url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      _inner.patch(host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _inner.patchUrl(url);

  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;

  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) =>
      _inner.authenticate = f;

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) =>
      _inner.addCredentials(url, realm, credentials);

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    )? f,
  ) =>
      _inner.connectionFactory = f;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  set authenticateProxy(
    Future<bool> Function(String host, int port, String scheme, String? realm)?
        f,
  ) =>
      _inner.authenticateProxy = f;

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) =>
      _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) =>
      _inner.badCertificateCallback = callback;

  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;

  @override
  void close({bool force = false}) => _inner.close(force: force);
}

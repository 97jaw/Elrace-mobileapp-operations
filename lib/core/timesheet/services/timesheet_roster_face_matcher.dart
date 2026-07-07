import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Phase 1 — on-device match against HR profile / face reference images.
class TimesheetRosterFaceMatch {
  const TimesheetRosterFaceMatch({
    required this.employee,
    required this.score,
  });

  final TimesheetOdooEmployee employee;
  /// Lower is better (normalized MSE).
  final double score;
}

class TimesheetRosterFaceMatcher {
  static const int _size = 48;
  /// Normalized MSE ceiling (front camera vs HR headshot is noisy).
  static const double _maxMse = 7200;
  static const String _defaultApiBase = 'https://erp.elrace.com';

  final Map<int, List<double>> _refFeatures = {};
  final Dio _dio = Dio();

  /// Pre-download HR reference images (call after roster load).
  Future<void> warmReferences({
    required List<TimesheetOdooEmployee> roster,
    Map<String, String>? httpHeaders,
    String apiBase = _defaultApiBase,
  }) async {
    for (final member in roster) {
      if (!member.canUseFaceMatch) continue;
      final url = member.faceMatchImageUrl;
      if (url == null || url.isEmpty) continue;
      await _refFeaturesFor(
        member.employeeId,
        url,
        httpHeaders: httpHeaders,
        apiBase: apiBase,
      );
    }
  }

  Future<TimesheetRosterFaceMatch?> matchProbe({
    required Uint8List probeCropJpeg,
    required List<TimesheetOdooEmployee> roster,
    Map<String, String>? httpHeaders,
    String apiBase = _defaultApiBase,
  }) async {
    if (roster.isEmpty) return null;
    final probe = _featuresFromBytes(probeCropJpeg);
    if (probe == null) {
      debugPrint('TimesheetRosterFaceMatcher: probe feature extraction failed');
      return null;
    }

    TimesheetOdooEmployee? bestEmployee;
    double best = double.infinity;
    double secondBest = double.infinity;
    var refsLoaded = 0;

    for (final member in roster) {
      if (!member.canUseFaceMatch) continue;
      final url = member.faceMatchImageUrl;
      if (url == null || url.isEmpty) continue;

      try {
        final ref = await _refFeaturesFor(
          member.employeeId,
          url,
          httpHeaders: httpHeaders,
          apiBase: apiBase,
        );
        if (ref == null) continue;
        refsLoaded++;
        final mse = _mse(probe, ref);
        if (mse < best) {
          secondBest = best;
          best = mse;
          bestEmployee = member;
        } else if (mse < secondBest) {
          secondBest = mse;
        }
      } catch (e) {
        debugPrint('TimesheetRosterFaceMatcher: ${member.employeeId} $e');
      }
    }

    if (refsLoaded == 0) {
      debugPrint(
        'TimesheetRosterFaceMatcher: no reference photos loaded '
        '(${roster.length} roster, check image_url / auth)',
      );
      return null;
    }

    debugPrint(
      'TimesheetRosterFaceMatcher: best=$best second=$secondBest '
      'refs=$refsLoaded',
    );

    if (bestEmployee == null) return null;

    final gapOk = secondBest == double.infinity || best < secondBest * 0.82;
    final singleRef = refsLoaded == 1;
    final underCap = best <= _maxMse;
    final relaxedSingle = singleRef && best <= _maxMse * 1.35;

    if ((underCap && gapOk) || relaxedSingle) {
      return TimesheetRosterFaceMatch(employee: bestEmployee, score: best);
    }
    return null;
  }

  Future<List<double>?> _refFeaturesFor(
    int employeeId,
    String url, {
    Map<String, String>? httpHeaders,
    required String apiBase,
  }) async {
    final cached = _refFeatures[employeeId];
    if (cached != null) return cached;

    final bytes = await _loadImageBytes(url, httpHeaders: httpHeaders, apiBase: apiBase);
    if (bytes == null) return null;
    final features = _featuresFromBytes(bytes);
    if (features != null) {
      _refFeatures[employeeId] = features;
    }
    return features;
  }

  Future<Uint8List?> _loadImageBytes(
    String url, {
    Map<String, String>? httpHeaders,
    required String apiBase,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('data:')) {
      final comma = trimmed.indexOf(',');
      if (comma < 0) return null;
      try {
        return base64Decode(trimmed.substring(comma + 1).trim());
      } catch (e) {
        debugPrint('TimesheetRosterFaceMatcher: base64 decode $e');
        return null;
      }
    }

    final resolved = _resolveUrl(trimmed, apiBase);
    try {
      final response = await _dio.get<List<int>>(
        resolved,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept': 'image/*,*/*',
            if (httpHeaders != null) ...httpHeaders,
          },
          validateStatus: (code) => code != null && code < 500,
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data!);
      }
    } catch (e) {
      debugPrint('TimesheetRosterFaceMatcher: GET $resolved -> $e');
    }
    return null;
  }

  String _resolveUrl(String url, String apiBase) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = apiBase.endsWith('/') ? apiBase.substring(0, apiBase.length - 1) : apiBase;
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }

  List<double>? _featuresFromBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final resized = img.copyResize(
      decoded,
      width: _size,
      height: _size,
      interpolation: img.Interpolation.average,
    );
    final gray = img.grayscale(resized);
    final raw = List<double>.filled(_size * _size, 0);
    var i = 0;
    for (var y = 0; y < _size; y++) {
      for (var x = 0; x < _size; x++) {
        raw[i++] = gray.getPixel(x, y).r.toDouble();
      }
    }
    return _normalize(raw);
  }

  List<double> _normalize(List<double> values) {
    if (values.isEmpty) return values;
    final mean = values.reduce((a, b) => a + b) / values.length;
    var variance = 0.0;
    for (final v in values) {
      final d = v - mean;
      variance += d * d;
    }
    final std = math.sqrt(variance / values.length).clamp(1.0, double.infinity);
    return [for (final v in values) (v - mean) / std];
  }

  double _mse(List<double> a, List<double> b) {
    if (a.length != b.length) return double.infinity;
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      final d = a[i] - b[i];
      sum += d * d;
    }
    return sum / a.length;
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:el_race/core/services/splash_video_cache.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:el_race/utils/urll_utils.dart';

/// Global app configuration fetched from backend
class AppConfigService {
  AppConfigService._internal();
  static final AppConfigService instance = AppConfigService._internal();

  static const _cacheKeyIsTestMode = 'app_config_is_test_mode';
  static const _cacheKeySkipVpnCheck = 'app_config_skip_vpn_check';
  static const _cacheKeyFaceIdEnabled = 'app_config_face_id_enabled';
  static const _cacheKeyFaceMatchMinScore = 'app_config_face_match_min_score';
  static const _cacheKeyFaceMatchMinLead = 'app_config_face_match_min_lead';
  static const _cacheKeyFaceVerifyPrefix = 'app_config_';

  /// `/api/app/config` keys for [FaceVerifyTuning]; cached under
  /// `app_config_<key>`.
  static const faceVerifyKeyMinScore = 'face_verify_min_score';
  static const faceVerifyKeyMinLead = 'face_verify_min_lead';
  static const faceVerifyKeyMinScoreNoCohort =
      'face_verify_min_score_no_cohort';
  static const faceVerifyKeyMinCohort = 'face_verify_min_cohort';
  static const faceVerifyKeyMinFacePx = 'face_verify_min_face_px';
  static const faceVerifyKeys = [
    faceVerifyKeyMinScore,
    faceVerifyKeyMinLead,
    faceVerifyKeyMinScoreNoCohort,
    faceVerifyKeyMinCohort,
    faceVerifyKeyMinFacePx,
  ];

  /// `/api/app/config` key for continuous best-frame capture (1:1).
  static const faceBestFrameEnabledKey = 'face_best_frame_enabled';
  static const _cacheKeyFaceBestFrameEnabled =
      'app_config_face_best_frame_enabled';

  /// Min live+verified frames for best-frame accept (Odoo
  /// `elrace.face_best_frame_min_live_frames`). Default 3; valid 3–5.
  /// Values below 3 (e.g. remote `2`) are rejected so accept stays unrelaxed.
  static const faceBestFrameMinLiveFramesKey =
      'face_best_frame_min_live_frames';
  static const _cacheKeyFaceBestFrameMinLiveFrames =
      'app_config_face_best_frame_min_live_frames';
  static const int faceBestFrameMinLiveFramesDefault = 3;

  /// Code kill switch for best-frame pipeline. When false, the Odoo flag is
  /// ignored and today's fast/slow path is used.
  static const bool faceBestFrameCodeEnabled = true;

  bool _isTestMode = false;
  bool get isTestMode => _isTestMode;

  bool _skipVpnCheck = false;
  bool get skipVpnCheck => _skipVpnCheck;

  /// Skip VPN blocking only when backend explicitly sets `skipVpnCheck`.
  /// `isTestMode` alone must NOT disable VPN — that caused mid-session skips
  /// after AppConfig loaded (splash could still detect before config arrived).
  bool get shouldSkipVpnCheck => _skipVpnCheck;

  /// Whether face ID is enabled (default: true)
  /// Backend key: faceIdEnabled
  bool _faceIdEnabled = true;
  bool get faceIdEnabled => _faceIdEnabled;

  /// Whether face ID should be skipped (only when faceIdEnabled=false from backend)
  /// Note: Test mode no longer bypasses face ID for security
  bool get shouldSkipFaceId => !_faceIdEnabled;

  /// Cached remote value; null means "not set" (treat as enabled).
  bool? _faceBestFrameEnabledRemote;

  /// Best-frame continuous PAD+identity for 1:1 capture. Missing/null remote
  /// → true. Forced off when [faceBestFrameCodeEnabled] is false.
  bool get faceBestFrameEnabled =>
      faceBestFrameCodeEnabled && (_faceBestFrameEnabledRemote ?? true);

  /// Accept-rule minimum live+verified frames. Missing/invalid → 3.
  int _faceBestFrameMinLiveFrames = faceBestFrameMinLiveFramesDefault;
  int get faceBestFrameMinLiveFrames => _faceBestFrameMinLiveFrames;

  /// `/api/app/config` walk-up mode + bars (TASK 10).
  static const faceMatchModeKey = 'face_match_mode';
  static const faceWalkUpMinScoreKey = 'face_walkup_min_score';
  static const faceWalkUpMinLeadKey = 'face_walkup_min_lead';
  static const _cacheKeyFaceMatchMode = 'app_config_face_match_mode';
  static const _cacheKeyFaceWalkUpMinScore = 'app_config_face_walkup_min_score';
  static const _cacheKeyFaceWalkUpMinLead = 'app_config_face_walkup_min_lead';

  /// Minimum device gate for face attendance (null remote → defaults).
  static const faceMinDeviceCheckEnabledKey = 'face_min_device_check_enabled';
  static const faceMinEmbMsKey = 'face_min_emb_ms';
  static const faceMinPadMsKey = 'face_min_pad_ms';
  static const faceMinRamGbKey = 'face_min_ram_gb';
  static const faceDeviceCheckExemptUsersKey = 'face_device_check_exempt_users';
  static const _cacheKeyFaceMinDeviceCheckEnabled =
      'app_config_face_min_device_check_enabled';
  static const _cacheKeyFaceMinEmbMs = 'app_config_face_min_emb_ms';
  static const _cacheKeyFaceMinPadMs = 'app_config_face_min_pad_ms';
  static const _cacheKeyFaceMinRamGb = 'app_config_face_min_ram_gb';
  static const _cacheKeyFaceDeviceCheckExemptUsers =
      'app_config_face_device_check_exempt_users';

  static const int faceMinEmbMsDefault = 400;
  static const int faceMinPadMsDefault = 600;
  static const double faceMinRamGbDefault = 3.0;

  FaceMatchMode _faceMatchMode = FaceMatchMode.verify;
  FaceMatchMode get faceMatchMode => _faceMatchMode;
  bool get isWalkUpMode => _faceMatchMode == FaceMatchMode.walkup;

  bool _faceMinDeviceCheckEnabled = true;
  bool get faceMinDeviceCheckEnabled => _faceMinDeviceCheckEnabled;

  int _faceMinEmbMs = faceMinEmbMsDefault;
  int get faceMinEmbMs => _faceMinEmbMs;

  int _faceMinPadMs = faceMinPadMsDefault;
  int get faceMinPadMs => _faceMinPadMs;

  double _faceMinRamGb = faceMinRamGbDefault;
  double get faceMinRamGb => _faceMinRamGb;

  Set<int> _faceDeviceCheckExemptUserIds = {};
  Set<int> get faceDeviceCheckExemptUserIds => _faceDeviceCheckExemptUserIds;

  /// Load config from remote API and cache locally
  Future<void> load() async {
    // Try read cached values first
    try {
      final prefs = await SharedPreferences.getInstance();
      _isTestMode = prefs.getBool(_cacheKeyIsTestMode) ?? false;
      _skipVpnCheck = prefs.getBool(_cacheKeySkipVpnCheck) ?? false;
      _faceIdEnabled = prefs.getBool(_cacheKeyFaceIdEnabled) ?? true;
      if (prefs.containsKey(_cacheKeyFaceBestFrameEnabled)) {
        _faceBestFrameEnabledRemote =
            prefs.getBool(_cacheKeyFaceBestFrameEnabled);
      }
      _faceBestFrameMinLiveFrames = parseFaceBestFrameMinLiveFrames(
            prefs.get(_cacheKeyFaceBestFrameMinLiveFrames),
          ) ??
          faceBestFrameMinLiveFramesDefault;
      FaceMatchTuning.apply(
        minScore: prefs.getDouble(_cacheKeyFaceMatchMinScore),
        minLead: prefs.getDouble(_cacheKeyFaceMatchMinLead),
      );
      applyFaceVerifyConfig({
        for (final key in faceVerifyKeys)
          key: prefs.get('$_cacheKeyFaceVerifyPrefix$key'),
      });
      _faceMatchMode =
          parseFaceMatchMode(prefs.getString(_cacheKeyFaceMatchMode)) ??
              FaceMatchMode.verify;
      FaceWalkUpTuning.apply(
        minScore: prefs.getDouble(_cacheKeyFaceWalkUpMinScore),
        minLead: prefs.getDouble(_cacheKeyFaceWalkUpMinLead),
      );
      if (prefs.containsKey(_cacheKeyFaceMinDeviceCheckEnabled)) {
        _faceMinDeviceCheckEnabled =
            prefs.getBool(_cacheKeyFaceMinDeviceCheckEnabled) ?? true;
      }
      _faceMinEmbMs =
          prefs.getInt(_cacheKeyFaceMinEmbMs) ?? faceMinEmbMsDefault;
      _faceMinPadMs =
          prefs.getInt(_cacheKeyFaceMinPadMs) ?? faceMinPadMsDefault;
      _faceMinRamGb =
          prefs.getDouble(_cacheKeyFaceMinRamGb) ?? faceMinRamGbDefault;
      _faceDeviceCheckExemptUserIds = parseExemptUserIds(
        prefs.getString(_cacheKeyFaceDeviceCheckExemptUsers),
      );
    } catch (_) {}

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'Content-Type': 'application/json'},
      ));

      const String url = '${UrlUtil.baseUrl}app/config';
      final resp = await dio.get(
        url,
        data: {'jsonrpc': '2.0', 'params': {}},
      );

      // print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      // print('🔧 AppConfigService API Response:');
      // print('📡 URL: $url');
      // print('📊 Status Code: ${resp.statusCode}');
      // print('📦 Raw Response: ${resp.data}');
      // print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Response can be jsonrpc envelope: { jsonrpc, id, result: { success, isTestMode } }
      final data = resp.data;
      bool? remoteIsTest;
      bool? remoteSkipVpn;
      Map<String, dynamic>? payload;
      if (data is Map<String, dynamic>) {
        payload = data['result'] is Map<String, dynamic>
            ? data['result'] as Map<String, dynamic>
            : data;
      } else if (data is String) {
        try {
          final parsed = jsonDecode(data);
          if (parsed is Map<String, dynamic>) {
            payload = parsed['result'] is Map<String, dynamic>
                ? parsed['result'] as Map<String, dynamic>
                : parsed;
          }
        } catch (_) {}
      }

      if (payload != null) {
        remoteIsTest = payload['isTestMode'] as bool?;
        remoteSkipVpn = payload['skipVpnCheck'] as bool?;
        final remoteFaceId = payload['faceIdEnabled'] as bool?;
        if (remoteFaceId != null) _faceIdEnabled = remoteFaceId;
        if (payload.containsKey('splash_video_url')) {
          final raw = payload['splash_video_url'];
          SplashVideoCache.instance.onConfig(raw is String ? raw : '');
        } else {
          SplashVideoCache.instance.onConfigUnavailable();
        }
        if (payload.containsKey('face_match_min_score') ||
            payload.containsKey('face_match_min_lead')) {
          await _applyFaceMatchTuning(
            payload['face_match_min_score'],
            payload['face_match_min_lead'],
          );
        }
        if (faceVerifyKeys.any(payload.containsKey)) {
          await _applyAndCacheFaceVerify(payload);
        }
        if (payload.containsKey(faceBestFrameEnabledKey)) {
          await _applyAndCacheFaceBestFrame(payload[faceBestFrameEnabledKey]);
        }
        if (payload.containsKey(faceBestFrameMinLiveFramesKey)) {
          await _applyAndCacheFaceBestFrameMinLiveFrames(
            payload[faceBestFrameMinLiveFramesKey],
          );
        }
        if (payload.containsKey(faceMatchModeKey) ||
            payload.containsKey(faceWalkUpMinScoreKey) ||
            payload.containsKey(faceWalkUpMinLeadKey)) {
          await _applyAndCacheWalkUp(
            modeRaw: payload[faceMatchModeKey],
            scoreRaw: payload[faceWalkUpMinScoreKey],
            leadRaw: payload[faceWalkUpMinLeadKey],
          );
        }
        if (payload.containsKey(faceMinDeviceCheckEnabledKey) ||
            payload.containsKey(faceMinEmbMsKey) ||
            payload.containsKey(faceMinPadMsKey) ||
            payload.containsKey(faceMinRamGbKey) ||
            payload.containsKey(faceDeviceCheckExemptUsersKey)) {
          await _applyAndCacheFaceMinDevice(payload);
        }
      }

      if (remoteIsTest != null) {
        _isTestMode = remoteIsTest;
      }
      if (remoteSkipVpn != null) {
        _skipVpnCheck = remoteSkipVpn;
      }

      // print('✅ AppConfigService: isTestMode=$_isTestMode, skipVpnCheck=$_skipVpnCheck, faceIdEnabled=$_faceIdEnabled');

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_cacheKeyIsTestMode, _isTestMode);
        await prefs.setBool(_cacheKeySkipVpnCheck, _skipVpnCheck);
        await prefs.setBool(_cacheKeyFaceIdEnabled, _faceIdEnabled);
      } catch (_) {}

      if (kDebugMode) {
        // debugPrint('AppConfigService: isTestMode=$_isTestMode, skipVpnCheck=$_skipVpnCheck, faceIdEnabled=$_faceIdEnabled');
      }
    } catch (e) {
      if (kDebugMode) {
        // debugPrint('AppConfigService: failed to load config: $e');
      }
      SplashVideoCache.instance.onConfigUnavailable();
      // Keep cached value
    }
  }

  /// Null (parameter unset) restores the default match bar.
  Future<void> _applyFaceMatchTuning(Object? rawScore, Object? rawLead) async {
    double? toDouble(Object? v) => v is num ? v.toDouble() : null;
    FaceMatchTuning.apply(
      minScore: toDouble(rawScore),
      minLead: toDouble(rawLead),
    );
    debugPrint(
      'AppConfigService: face match bar score=${FaceMatchTuning.minScore} '
      'lead=${FaceMatchTuning.minLead}',
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(
          _cacheKeyFaceMatchMinScore, FaceMatchTuning.minScore);
      await prefs.setDouble(_cacheKeyFaceMatchMinLead, FaceMatchTuning.minLead);
    } catch (_) {}
  }

  /// Applies the `face_verify_*` values in [values] to [FaceVerifyTuning].
  /// Missing, null, wrong type or out-of-range values keep the defaults
  /// (older backends don't send the keys). Integers must be whole numbers.
  @visibleForTesting
  static void applyFaceVerifyConfig(Map<String, Object?> values) {
    double? toDouble(Object? v) => v is num ? v.toDouble() : null;
    int? toInt(Object? v) {
      if (v is int) return v;
      if (v is double && v.isFinite && v == v.roundToDouble()) {
        return v.toInt();
      }
      return null;
    }

    FaceVerifyTuning.apply(
      minScore: toDouble(values[faceVerifyKeyMinScore]),
      minLead: toDouble(values[faceVerifyKeyMinLead]),
      minScoreNoCohort: toDouble(values[faceVerifyKeyMinScoreNoCohort]),
      minCohort: toInt(values[faceVerifyKeyMinCohort]),
      minFacePx: toInt(values[faceVerifyKeyMinFacePx]),
    );
  }

  Future<void> _applyAndCacheFaceVerify(Map<String, dynamic> payload) async {
    applyFaceVerifyConfig(payload);
    debugPrint(
      'AppConfigService: face verify bars score=${FaceVerifyTuning.minScore} '
      'lead=${FaceVerifyTuning.minLead} '
      'noCohort=${FaceVerifyTuning.minScoreNoCohort} '
      'minCohort=${FaceVerifyTuning.minCohort} '
      'minFacePx=${FaceVerifyTuning.minFacePx}',
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('$_cacheKeyFaceVerifyPrefix$faceVerifyKeyMinScore',
          FaceVerifyTuning.minScore);
      await prefs.setDouble('$_cacheKeyFaceVerifyPrefix$faceVerifyKeyMinLead',
          FaceVerifyTuning.minLead);
      await prefs.setDouble(
          '$_cacheKeyFaceVerifyPrefix$faceVerifyKeyMinScoreNoCohort',
          FaceVerifyTuning.minScoreNoCohort);
      await prefs.setInt('$_cacheKeyFaceVerifyPrefix$faceVerifyKeyMinCohort',
          FaceVerifyTuning.minCohort);
      await prefs.setInt('$_cacheKeyFaceVerifyPrefix$faceVerifyKeyMinFacePx',
          FaceVerifyTuning.minFacePx);
    } catch (_) {}
  }

  /// Parses remote `face_best_frame_enabled`. Null / missing → keep prior
  /// cache (or default true via [faceBestFrameEnabled]). Explicit bool only.
  @visibleForTesting
  static bool? parseFaceBestFrameEnabled(Object? raw) {
    if (raw == null) return null;
    if (raw is bool) return raw;
    if (raw is num) {
      if (raw == 0) return false;
      if (raw == 1) return true;
      return null;
    }
    if (raw is String) {
      final s = raw.trim().toLowerCase();
      if (s == '0' || s == 'false') return false;
      if (s == '1' || s == 'true') return true;
    }
    return null;
  }

  Future<void> _applyAndCacheFaceBestFrame(Object? raw) async {
    final parsed = parseFaceBestFrameEnabled(raw);
    // Key present with null → reset to "missing" (app default true).
    _faceBestFrameEnabledRemote = parsed;
    debugPrint(
      'AppConfigService: face_best_frame_enabled='
      '${parsed == null ? 'null(default on)' : parsed} '
      'effective=$faceBestFrameEnabled',
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      if (parsed == null) {
        await prefs.remove(_cacheKeyFaceBestFrameEnabled);
      } else {
        await prefs.setBool(_cacheKeyFaceBestFrameEnabled, parsed);
      }
    } catch (_) {}
  }

  /// Parses `face_best_frame_min_live_frames`. Valid ints in 3–5 only;
  /// null / missing / invalid (including 2) → null (caller keeps default 3).
  @visibleForTesting
  static int? parseFaceBestFrameMinLiveFrames(Object? raw) {
    int? n;
    if (raw is int) {
      n = raw;
    } else if (raw is double && raw.isFinite && raw == raw.roundToDouble()) {
      n = raw.toInt();
    } else if (raw is String) {
      n = int.tryParse(raw.trim());
    }
    if (n == null) return null;
    if (n < 3 || n > 5) return null;
    return n;
  }

  Future<void> _applyAndCacheFaceBestFrameMinLiveFrames(Object? raw) async {
    final parsed = parseFaceBestFrameMinLiveFrames(raw);
    _faceBestFrameMinLiveFrames =
        parsed ?? faceBestFrameMinLiveFramesDefault;
    debugPrint(
      'AppConfigService: face_best_frame_min_live_frames='
      '${parsed == null ? 'null→$faceBestFrameMinLiveFramesDefault' : parsed} '
      'effective=$_faceBestFrameMinLiveFrames',
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      if (parsed == null) {
        await prefs.remove(_cacheKeyFaceBestFrameMinLiveFrames);
      } else {
        await prefs.setInt(_cacheKeyFaceBestFrameMinLiveFrames, parsed);
      }
    } catch (_) {}
  }

  /// `"verify"` / `"walkup"` only; unknown / null → null (caller keeps verify).
  @visibleForTesting
  static FaceMatchMode? parseFaceMatchMode(Object? raw) {
    if (raw is! String) return null;
    switch (raw.trim().toLowerCase()) {
      case 'verify':
        return FaceMatchMode.verify;
      case 'walkup':
        return FaceMatchMode.walkup;
      default:
        return null;
    }
  }

  Future<void> _applyAndCacheWalkUp({
    Object? modeRaw,
    Object? scoreRaw,
    Object? leadRaw,
  }) async {
    final mode = parseFaceMatchMode(modeRaw);
    _faceMatchMode = mode ?? FaceMatchMode.verify;
    double? toDouble(Object? v) => v is num ? v.toDouble() : null;
    FaceWalkUpTuning.apply(
      minScore: toDouble(scoreRaw),
      minLead: toDouble(leadRaw),
    );
    debugPrint(
      'AppConfigService: face_match_mode='
      '${mode == null ? 'null→verify' : mode.name} '
      'walkup_score=${FaceWalkUpTuning.minScore} '
      'walkup_lead=${FaceWalkUpTuning.minLead}',
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mode == null) {
        await prefs.remove(_cacheKeyFaceMatchMode);
      } else {
        await prefs.setString(_cacheKeyFaceMatchMode, mode.name);
      }
      await prefs.setDouble(
        _cacheKeyFaceWalkUpMinScore,
        FaceWalkUpTuning.minScore,
      );
      await prefs.setDouble(
        _cacheKeyFaceWalkUpMinLead,
        FaceWalkUpTuning.minLead,
      );
    } catch (_) {}
  }

  /// Comma-separated Odoo user ids; empty / null → empty set.
  @visibleForTesting
  static Set<int> parseExemptUserIds(Object? raw) {
    if (raw == null) return {};
    final text = raw is String ? raw : raw.toString();
    if (text.trim().isEmpty) return {};
    final out = <int>{};
    for (final part in text.split(',')) {
      final n = int.tryParse(part.trim());
      if (n != null && n > 0) out.add(n);
    }
    return out;
  }

  @visibleForTesting
  static bool? parseFaceMinDeviceCheckEnabled(Object? raw) {
    if (raw == null) return null;
    if (raw is bool) return raw;
    if (raw is num) {
      if (raw == 0) return false;
      if (raw == 1) return true;
      return null;
    }
    if (raw is String) {
      final s = raw.trim().toLowerCase();
      if (s == '0' || s == 'false') return false;
      if (s == '1' || s == 'true') return true;
    }
    return null;
  }

  Future<void> _applyAndCacheFaceMinDevice(Map<String, dynamic> payload) async {
    final enabled = parseFaceMinDeviceCheckEnabled(
      payload[faceMinDeviceCheckEnabledKey],
    );
    if (enabled != null) {
      _faceMinDeviceCheckEnabled = enabled;
    } else if (payload.containsKey(faceMinDeviceCheckEnabledKey)) {
      _faceMinDeviceCheckEnabled = true;
    }

    int? toInt(Object? v) {
      if (v is int) return v;
      if (v is double && v.isFinite && v == v.roundToDouble()) return v.toInt();
      if (v is String) return int.tryParse(v.trim());
      return null;
    }

    double? toDouble(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim());
      return null;
    }

    _faceMinEmbMs = toInt(payload[faceMinEmbMsKey]) ?? faceMinEmbMsDefault;
    _faceMinPadMs = toInt(payload[faceMinPadMsKey]) ?? faceMinPadMsDefault;
    _faceMinRamGb =
        toDouble(payload[faceMinRamGbKey]) ?? faceMinRamGbDefault;
    if (payload.containsKey(faceDeviceCheckExemptUsersKey)) {
      _faceDeviceCheckExemptUserIds =
          parseExemptUserIds(payload[faceDeviceCheckExemptUsersKey]);
    }

    debugPrint(
      'AppConfigService: face_min_device_check enabled=$_faceMinDeviceCheckEnabled '
      'emb_ms=$_faceMinEmbMs pad_ms=$_faceMinPadMs ram_gb=$_faceMinRamGb '
      'exempt=${_faceDeviceCheckExemptUserIds.join(",")}',
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        _cacheKeyFaceMinDeviceCheckEnabled,
        _faceMinDeviceCheckEnabled,
      );
      await prefs.setInt(_cacheKeyFaceMinEmbMs, _faceMinEmbMs);
      await prefs.setInt(_cacheKeyFaceMinPadMs, _faceMinPadMs);
      await prefs.setDouble(_cacheKeyFaceMinRamGb, _faceMinRamGb);
      await prefs.setString(
        _cacheKeyFaceDeviceCheckExemptUsers,
        _faceDeviceCheckExemptUserIds.join(','),
      );
    } catch (_) {}
  }
}

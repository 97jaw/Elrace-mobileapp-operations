import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:el_race/core/services/app_config_service.dart';
import 'package:el_race/core/site_management/face_recognition/android_face_capture_perf.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/minifasnet_fusion_engine.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_embedder.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of the face-attendance minimum device gate.
class FaceMinDeviceCheckResult {
  const FaceMinDeviceCheckResult({
    required this.passed,
    required this.reason,
    required this.model,
    required this.osLabel,
    required this.ramGb,
    required this.embMs,
    required this.padPairMs,
    required this.cached,
    this.cores,
  });

  final bool passed;
  final String reason;
  final String model;
  final String osLabel;
  final double? ramGb;
  final int? embMs;
  final int? padPairMs;
  final bool cached;
  final int? cores;

  String get supportLine {
    final ram = ramGb != null ? ramGb!.toStringAsFixed(1) : '?';
    final emb = embMs ?? -1;
    final pad = padPairMs ?? -1;
    return '$model · $osLabel · RAM $ram GB · emb $emb ms · pad $pad ms';
  }
}

/// Blocks face capture on devices that cannot run PAD + embedding reliably.
///
/// Self-test is cached once per app version + device; failed caches re-run.
abstract final class FaceMinDeviceCheck {
  static const _cacheKeyPrefix = 'face_min_device_check_v1_';

  static Future<FaceMinDeviceCheckResult>? _inFlight;

  /// Runs (or loads cache) and returns pass/fail. Does not show UI.
  static Future<FaceMinDeviceCheckResult> evaluate() async {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _evaluateBody();
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  static Future<FaceMinDeviceCheckResult> _evaluateBody() async {
    final cfg = AppConfigService.instance;
    final exemptId = _currentUserId();
    final skipBlock = !cfg.faceMinDeviceCheckEnabled ||
        (exemptId != null &&
            cfg.faceDeviceCheckExemptUserIds.contains(exemptId));
    final skipReason = !cfg.faceMinDeviceCheckEnabled
        ? 'check_disabled'
        : (exemptId != null ? 'exempt_user=$exemptId' : null);

    final probe = await _probeDeviceMeta();

    // OS floor (still applied when blocking is enabled).
    if (!skipBlock && Platform.isAndroid && (probe.androidSdk ?? 0) < 28) {
      final r = FaceMinDeviceCheckResult(
        passed: false,
        reason: 'android_api<28',
        model: probe.model,
        osLabel: probe.osLabel,
        ramGb: probe.ramGb,
        embMs: null,
        padPairMs: null,
        cached: false,
        cores: probe.cores,
      );
      _log(r);
      return r;
    }
    if (!skipBlock && Platform.isIOS) {
      final major = probe.iosMajor ?? 0;
      if (major < 15) {
        final r = FaceMinDeviceCheckResult(
          passed: false,
          reason: 'ios<15',
          model: probe.model,
          osLabel: probe.osLabel,
          ramGb: probe.ramGb,
          embMs: null,
          padPairMs: null,
          cached: false,
          cores: probe.cores,
        );
        _log(r);
        return r;
      }
    }

    // RAM floor (Android).
    if (!skipBlock &&
        Platform.isAndroid &&
        probe.ramGb != null &&
        probe.ramGb! > 0 &&
        probe.ramGb! < cfg.faceMinRamGb) {
      final r = FaceMinDeviceCheckResult(
        passed: false,
        reason: 'ram_gb<${cfg.faceMinRamGb}',
        model: probe.model,
        osLabel: probe.osLabel,
        ramGb: probe.ramGb,
        embMs: null,
        padPairMs: null,
        cached: false,
        cores: probe.cores,
      );
      _log(r);
      return r;
    }

    // Self-test: cache pass; re-run on fail / missing.
    final pkg = await PackageInfo.fromPlatform();
    final cacheKey =
        '$_cacheKeyPrefix${pkg.version}_${probe.cacheDeviceId}';
    final prefs = await SharedPreferences.getInstance();
    final cached = _readCache(prefs, cacheKey);
    if (cached != null && cached.passed) {
      final r = FaceMinDeviceCheckResult(
        passed: true,
        reason: 'cached_pass',
        model: probe.model,
        osLabel: probe.osLabel,
        ramGb: probe.ramGb,
        embMs: cached.embMs,
        padPairMs: cached.padPairMs,
        cached: true,
        cores: probe.cores,
      );
      _log(r);
      // Still apply low-end from cached timings on Android.
      if (Platform.isAndroid && cached.embMs != null && cached.padPairMs != null) {
        AndroidFaceCapturePerf.decideFromSelfTest(
          ramGb: probe.ramGb,
          embMs: cached.embMs!,
          padPairMs: cached.padPairMs!,
          model: probe.model,
          cores: probe.cores,
        );
      }
      return r;
    }

    final self = await _runSelfTestBestOfTwo();
    if (!self.ok) {
      if (!skipBlock) {
        await _writeCache(
          prefs,
          cacheKey,
          passed: false,
          embMs: self.embMs,
          padPairMs: self.padPairMs,
        );
      }
      final r = FaceMinDeviceCheckResult(
        passed: skipBlock,
        reason: skipReason ?? 'selftest_fail',
        model: probe.model,
        osLabel: probe.osLabel,
        ramGb: probe.ramGb,
        embMs: self.embMs,
        padPairMs: self.padPairMs,
        cached: false,
        cores: probe.cores,
      );
      _log(r);
      return r;
    }

    final embLimit = cfg.faceMinEmbMs;
    final padLimit = cfg.faceMinPadMs;
    final tooSlowEmb = self.embMs > embLimit;
    final tooSlowPad = self.padPairMs > padLimit;
    final timingPass = !tooSlowEmb && !tooSlowPad;
    final passed = skipBlock || timingPass;
    final reason = skipReason ??
        (!timingPass
            ? (tooSlowEmb
                ? 'selftest_emb_ms>$embLimit'
                : 'selftest_pad_pair_ms>$padLimit')
            : 'selftest_pass');

    // Cache only real timing pass/fail (not exempt skip) so limits still apply
    // after remote re-enable.
    if (!skipBlock) {
      await _writeCache(
        prefs,
        cacheKey,
        passed: timingPass,
        embMs: self.embMs,
        padPairMs: self.padPairMs,
      );
    } else if (timingPass) {
      await _writeCache(
        prefs,
        cacheKey,
        passed: true,
        embMs: self.embMs,
        padPairMs: self.padPairMs,
      );
    }

    if (Platform.isAndroid) {
      AndroidFaceCapturePerf.decideFromSelfTest(
        ramGb: probe.ramGb,
        embMs: self.embMs,
        padPairMs: self.padPairMs,
        model: probe.model,
        cores: probe.cores,
      );
    }

    final r = FaceMinDeviceCheckResult(
      passed: passed,
      reason: reason,
      model: probe.model,
      osLabel: probe.osLabel,
      ramGb: probe.ramGb,
      embMs: self.embMs,
      padPairMs: self.padPairMs,
      cached: false,
      cores: probe.cores,
    );
    _log(r);
    return r;
  }

  /// Blocking dialog; returns true when the device may open the camera.
  static Future<bool> ensureSupported(BuildContext context) async {
    final result = await evaluate();
    if (result.passed) return true;
    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Device not supported'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This phone does not meet the minimum requirements for face '
              'attendance. Please use a newer phone or contact your supervisor.',
            ),
            const SizedBox(height: 12),
            Text(
              result.supportLine,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }

  static void _log(FaceMinDeviceCheckResult r) {
    debugPrint(
      'DeviceCheck: result=${r.passed ? 'pass' : 'fail'} '
      'reason=${r.reason} model=${r.model} '
      'android=${r.osLabel} '
      'ram_gb=${r.ramGb != null ? r.ramGb!.toStringAsFixed(1) : '-'} '
      'emb_ms=${r.embMs ?? '-'} pad_ms=${r.padPairMs ?? '-'} '
      'cached=${r.cached}',
    );
  }

  static int? _currentUserId() {
    try {
      final data = SharedPref.getLoginDataOrNull()?.result?.data;
      return data?.odoo_user_id ?? data?.uid;
    } catch (_) {
      return null;
    }
  }

  static Future<
      ({
        String model,
        String osLabel,
        String cacheDeviceId,
        double? ramGb,
        int? cores,
        int? androidSdk,
        int? iosMajor,
      })> _probeDeviceMeta() async {
    final cores = Platform.numberOfProcessors;
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      final ramGb =
          info.physicalRamSize > 0 ? info.physicalRamSize / 1024.0 : null;
      final model = '${info.brand} ${info.model}'.trim();
      final ver = info.version.release;
      return (
        model: model,
        osLabel: 'Android $ver',
        cacheDeviceId: '${info.brand}_${info.model}_${info.id}',
        ramGb: ramGb,
        cores: cores,
        androidSdk: info.version.sdkInt,
        iosMajor: null,
      );
    }
    if (Platform.isIOS) {
      final info = await DeviceInfoPlugin().iosInfo;
      final ver = info.systemVersion;
      final major = int.tryParse(ver.split('.').first) ?? 0;
      return (
        model: info.utsname.machine,
        osLabel: 'iOS $ver',
        cacheDeviceId: '${info.utsname.machine}_$ver',
        ramGb: null,
        cores: cores,
        androidSdk: null,
        iosMajor: major,
      );
    }
    return (
      model: Platform.operatingSystem,
      osLabel: Platform.operatingSystemVersion,
      cacheDeviceId: Platform.operatingSystem,
      ramGb: null,
      cores: cores,
      androidSdk: null,
      iosMajor: null,
    );
  }

  /// First run warms interpreters; second run is usually the real figure.
  /// Returns the best (lowest) emb and pad-pair ms of the two.
  static Future<({bool ok, int embMs, int padPairMs})>
      _runSelfTestBestOfTwo() async {
    // Neutral threads before first load when undecided.
    if (Platform.isAndroid) {
      AndroidFaceCapturePerf.configure(lowEnd: false);
    }
    Future<({bool ok, int embMs, int padPairMs})> once() async {
      final emb = await FaceEmbedder.instance.runSelfTest();
      final pad = await MinifasnetFusionEngine.instance.runSelfTest();
      final padPair =
          (pad.v2Ms > 0 && pad.v1Ms > 0) ? pad.v2Ms + pad.v1Ms : 99999;
      return (
        ok: emb.ok && pad.ok,
        embMs: emb.ok ? emb.ms : 99999,
        padPairMs: pad.ok ? padPair : 99999,
      );
    }

    final warm = await once();
    final second = await once();
    final ok = warm.ok || second.ok;
    if (!ok) {
      return (
        ok: false,
        embMs: warm.embMs < second.embMs ? warm.embMs : second.embMs,
        padPairMs: warm.padPairMs < second.padPairMs
            ? warm.padPairMs
            : second.padPairMs,
      );
    }
    final embMs = [
      if (warm.ok) warm.embMs,
      if (second.ok) second.embMs,
    ].reduce((a, b) => a < b ? a : b);
    final padPairMs = [
      if (warm.ok) warm.padPairMs,
      if (second.ok) second.padPairMs,
    ].reduce((a, b) => a < b ? a : b);
    debugPrint(
      'DeviceCheck: selftest best-of-2 warm_emb=${warm.embMs} '
      'warm_pad=${warm.padPairMs} second_emb=${second.embMs} '
      'second_pad=${second.padPairMs} → emb=$embMs pad=$padPairMs',
    );
    return (ok: true, embMs: embMs, padPairMs: padPairMs);
  }

  static ({bool passed, int? embMs, int? padPairMs})? _readCache(
    SharedPreferences prefs,
    String key,
  ) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    // format: pass|fail;emb;pad
    final parts = raw.split(';');
    if (parts.length < 3) return null;
    final passed = parts[0] == 'pass';
    final emb = int.tryParse(parts[1]);
    final pad = int.tryParse(parts[2]);
    return (passed: passed, embMs: emb, padPairMs: pad);
  }

  static Future<void> _writeCache(
    SharedPreferences prefs,
    String key, {
    required bool passed,
    required int embMs,
    required int padPairMs,
  }) async {
    await prefs.setString(
      key,
      '${passed ? 'pass' : 'fail'};$embMs;$padPairMs',
    );
  }
}

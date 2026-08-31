import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:el_race/core/security/device_security_service.dart';
import 'package:el_race/core/security/vpn_block_guard.dart';
import 'package:el_race/core/services/app_config_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Live VPN watcher — local native probe + connectivity changes + resume delays.
/// Popup only (Retry / Close). No logout.
class VpnSecurityMonitor with WidgetsBindingObserver {
  VpnSecurityMonitor._();
  static final VpnSecurityMonitor instance = VpnSecurityMonitor._();

  static const EventChannel _vpnEvents =
      EventChannel('ae.elrace.mobile/vpn_detection_events');

  StreamSubscription<dynamic>? _eventSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _pollTimer;
  Timer? _initialPollTimer;
  final List<Timer> _delayedChecks = [];
  bool _running = false;
  bool _observingLifecycle = false;

  void start() {
    if (_running) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    _running = true;

    if (!_observingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    }

    _eventSubscription = _vpnEvents.receiveBroadcastStream().listen(
      _onNativeVpnEvent,
      onError: (Object e) {
        debugPrint('VPN event stream error: $e');
      },
    );

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((_) {
      _scheduleBurstChecks();
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      // ignore: unawaited_futures
      _pollVpnStatus();
    });

    _initialPollTimer = Timer(const Duration(seconds: 2), () {
      // ignore: unawaited_futures
      _pollVpnStatus();
    });
  }

  void stop() {
    _running = false;
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _initialPollTimer?.cancel();
    _initialPollTimer = null;
    _cancelDelayedChecks();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_running) return;
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive) {
      _scheduleBurstChecks();
    }
  }

  void _scheduleBurstChecks() {
    _cancelDelayedChecks();
    // ignore: unawaited_futures
    VpnBlockGuard.instance.checkOnForeground(force: true);
    for (final delay in const [
      Duration(milliseconds: 800),
      Duration(seconds: 2),
      Duration(seconds: 5),
    ]) {
      _delayedChecks.add(Timer(delay, () {
        // ignore: unawaited_futures
        VpnBlockGuard.instance.checkOnForeground(force: true);
      }));
    }
  }

  void _cancelDelayedChecks() {
    for (final t in _delayedChecks) {
      t.cancel();
    }
    _delayedChecks.clear();
  }

  void _onNativeVpnEvent(dynamic event) {
    if (event == true) {
      // ignore: unawaited_futures
      VpnBlockGuard.instance.checkOnForeground(force: true);
    }
  }

  Future<void> _pollVpnStatus() async {
    if (!_running) return;
    if (AppConfigService.instance.shouldSkipVpnCheck) return;

    try {
      final active = await DeviceSecurityService.instance.isVpnBlockingActive();
      if (active) {
        // ignore: unawaited_futures
        VpnBlockGuard.instance.checkOnForeground(force: true);
      }
    } catch (e) {
      debugPrint('VPN poll error: $e');
    }
  }
}

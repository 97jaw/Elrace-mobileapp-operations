import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:el_race/config/uaepass_config.dart';
import 'package:el_race/utils/uaepass_logger.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// UAE PASS web login in the system browser (Safari / Chrome).
///
/// Opens the authorization URL outside the app and waits for the backend
/// callback to return with `elrace://uaepass/success|error`. Completes with
/// that link, or `null` when the user comes back to Elrace without finishing.
class UaepassBrowserLogin with WidgetsBindingObserver {
  UaepassBrowserLogin._(this._config, this._onReturned);

  /// Time allowed after Elrace resumes for the return link to arrive.
  static const _returnGrace = Duration(milliseconds: 1500);

  static UaepassBrowserLogin? _active;

  /// True while a browser login is waiting; its return links are consumed
  /// here, not by the global deep-link handler.
  static bool get isActive => _active != null;

  final UaepassConfig _config;
  final VoidCallback? _onReturned;
  final _result = Completer<Uri?>();
  StreamSubscription<Uri>? _linkSub;
  Timer? _returnTimer;
  bool _leftApp = false;

  /// [onReturned] fires as soon as Elrace is back in the foreground.
  static Future<Uri?> run(
    UaepassConfig config,
    Uri url, {
    VoidCallback? onReturned,
  }) async {
    final login = UaepassBrowserLogin._(config, onReturned);
    _active = login;
    try {
      return await login._run(url);
    } finally {
      login._dispose();
      if (identical(_active, login)) _active = null;
    }
  }

  Future<Uri?> _run(Uri url) async {
    WidgetsBinding.instance.addObserver(this);
    _linkSub = AppLinks().uriLinkStream.listen(_onLink);
    UaepassLogger.logKV('Opening system browser', url.toString());
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched) {
      UaepassLogger.logError('Could not open the system browser');
      return null;
    }
    return _result.future;
  }

  void _onLink(Uri uri) {
    if (_config.isSuccessLink(uri) || _config.isErrorLink(uri)) {
      _complete(uri);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _leftApp = true;
      _returnTimer?.cancel();
      return;
    }
    if (state != AppLifecycleState.resumed || !_leftApp) return;
    _onReturned?.call();
    _returnTimer?.cancel();
    _returnTimer = Timer(_returnGrace, () {
      UaepassLogger.logWarning('Returned from browser without UAE PASS result');
      _complete(null);
    });
  }

  void _complete(Uri? uri) {
    if (!_result.isCompleted) _result.complete(uri);
  }

  void _dispose() {
    _returnTimer?.cancel();
    _linkSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}

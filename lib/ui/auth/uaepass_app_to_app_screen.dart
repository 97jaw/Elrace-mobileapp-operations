import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:el_race/config/uaepass_config.dart';
import 'package:el_race/utils/uaepass_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

/// UAE PASS app-to-app login, with nothing shown on screen.
///
/// Loads the authorization URL (`acr_values=...mobileondevice`) in an
/// invisible 1x1 WebView placed in the root overlay, so the sign-in screen
/// and its loading card stay in view. UAE PASS answers with a `uaepass://`
/// link carrying `successurl` / `failureurl`; those are swapped for Elrace
/// return links and the UAE PASS app ([UaepassConfig.appScheme]) is opened.
/// When the app returns to Elrace, the original `successurl` is loaded so
/// UAE PASS redirects to the backend callback, which ends at
/// `elrace://uaepass/success|error`.
class UaepassAppToAppRelay extends StatefulWidget {
  const UaepassAppToAppRelay._({
    required this.config,
    required this.authorizationUrl,
    required this.onDone,
    this.onReturned,
    this.onApproved,
  });

  final UaepassConfig config;
  final Uri authorizationUrl;
  final ValueChanged<Uri?> onDone;
  final VoidCallback? onReturned;
  final VoidCallback? onApproved;

  /// Completes with the final callback [Uri], or `null` when the login was
  /// not finished (UAE PASS app not opened, declined, or the user came back
  /// without approving). [onReturned] fires as soon as Elrace is back in the
  /// foreground; [onApproved] fires when the UAE PASS app returns approved,
  /// before the backend callback finishes.
  static Future<Uri?> run(
    BuildContext context, {
    required UaepassConfig config,
    required Uri authorizationUrl,
    VoidCallback? onReturned,
    VoidCallback? onApproved,
  }) {
    final result = Completer<Uri?>();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        width: 1,
        height: 1,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0,
            child: UaepassAppToAppRelay._(
              config: config,
              authorizationUrl: authorizationUrl,
              onReturned: onReturned,
              onApproved: onApproved,
              onDone: (uri) {
                if (!result.isCompleted) result.complete(uri);
              },
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    return result.future.whenComplete(entry.remove);
  }

  @override
  State<UaepassAppToAppRelay> createState() => _UaepassAppToAppRelayState();
}

class _UaepassAppToAppRelayState extends State<UaepassAppToAppRelay>
    with WidgetsBindingObserver {
  /// Time allowed for UAE PASS to hand off to its app.
  static const _handoffTimeout = Duration(seconds: 25);

  /// Time allowed after Elrace resumes for the UAE PASS return link.
  static const _returnGrace = Duration(milliseconds: 1500);

  /// Time allowed for the backend callback after the UAE PASS app returns.
  static const _callbackTimeout = Duration(seconds: 30);

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  InAppWebViewController? _controller;
  Timer? _timer;

  Uri? _pendingSuccessUrl;
  Uri? _pendingFailureUrl;
  String? _nonce;
  bool _leftApp = false;
  bool _finished = false;

  UaepassConfig get _config => widget.config;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _linkSub = _appLinks.uriLinkStream.listen(_onAppReturn);
    _startTimer(_handoffTimeout, 'UAE PASS app was not opened');
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }

  void _startTimer(Duration duration, String reason) {
    _timer?.cancel();
    _timer = Timer(duration, () {
      UaepassLogger.logWarning(reason);
      _finish(null);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _nonce != null) {
      _leftApp = true;
      _timer?.cancel();
      return;
    }
    if (state != AppLifecycleState.resumed || !_leftApp || _nonce == null) {
      return;
    }
    widget.onReturned?.call();
    _appLinks.getLatestLink().then((uri) {
      if (uri != null) _onAppReturn(uri);
    });
    _startTimer(_returnGrace, 'Returned from UAE PASS app without a result');
  }

  void _onAppReturn(Uri uri) {
    if (!_config.isAppReturnLink(uri)) return;
    if (_nonce == null || uri.queryParameters['r'] != _nonce) return;
    _nonce = null;

    final success = uri.path == UaepassConfig.appReturnSuccessPath;
    final target = success ? _pendingSuccessUrl : _pendingFailureUrl;
    _pendingSuccessUrl = null;
    _pendingFailureUrl = null;
    UaepassLogger.logKV(
        'UAE PASS app returned', success ? 'success' : 'failure');

    widget.onReturned?.call();
    if (!success || target == null) {
      _finish(null);
      return;
    }
    widget.onApproved?.call();
    _startTimer(_callbackTimeout, 'UAE PASS callback did not return');
    _controller?.loadUrl(urlRequest: URLRequest(url: WebUri.uri(target)));
  }

  Future<void> _openUaepassApp(Uri uaepassLink) async {
    final params = Map<String, String>.from(uaepassLink.queryParameters);
    _pendingSuccessUrl = Uri.tryParse(params['successurl'] ?? '');
    _pendingFailureUrl = Uri.tryParse(params['failureurl'] ?? '');
    final nonce = DateTime.now().microsecondsSinceEpoch.toString();
    _nonce = nonce;

    params['successurl'] =
        _config.appReturnUri(success: true, nonce: nonce).toString();
    params['failureurl'] =
        _config.appReturnUri(success: false, nonce: nonce).toString();
    final target = uaepassLink.replace(
      scheme: _config.appScheme,
      queryParameters: params,
    );
    UaepassLogger.logKV('Opening UAE PASS app', target.toString());

    final launched =
        await launchUrl(target, mode: LaunchMode.externalApplication);
    if (!launched) {
      UaepassLogger.logError('Could not open UAE PASS app');
      _finish(null);
    }
  }

  void _finish(Uri? result) {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    widget.onDone(result);
  }

  Future<NavigationActionPolicy> _onNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = action.request.url?.uriValue;
    if (uri == null) return NavigationActionPolicy.ALLOW;
    final scheme = uri.scheme.toLowerCase();

    if (scheme == 'uaepass' || scheme == _config.appScheme) {
      await _openUaepassApp(uri);
      return NavigationActionPolicy.CANCEL;
    }
    if (scheme == _config.deepLinkScheme) {
      if (_config.isSuccessLink(uri) || _config.isErrorLink(uri)) {
        _finish(uri);
      }
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri.uri(widget.authorizationUrl)),
      initialSettings: InAppWebViewSettings(
        useShouldOverrideUrlLoading: true,
        javaScriptEnabled: true,
        clearCache: true,
      ),
      onWebViewCreated: (controller) => _controller = controller,
      shouldOverrideUrlLoading: _onNavigation,
    );
  }
}

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:el_race/config/uaepass_config.dart';
import 'package:el_race/utils/uaepass_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

/// UAE PASS app-to-app login.
///
/// Loads the authorization URL (`acr_values=...mobileondevice`) in a WebView.
/// UAE PASS answers with a `uaepass://` link carrying `successurl` /
/// `failureurl`; those are swapped for Elrace return links and the UAE PASS
/// app ([UaepassConfig.appScheme]) is opened. When the app returns to Elrace,
/// the original `successurl` is loaded so UAE PASS redirects to the backend
/// callback, which ends at `elrace://uaepass/success|error`.
///
/// Pops with that final callback [Uri], or `null` when the user cancels.
class UaepassAppToAppScreen extends StatefulWidget {
  const UaepassAppToAppScreen({
    super.key,
    required this.config,
    required this.authorizationUrl,
  });

  final UaepassConfig config;
  final Uri authorizationUrl;

  @override
  State<UaepassAppToAppScreen> createState() => _UaepassAppToAppScreenState();
}

class _UaepassAppToAppScreenState extends State<UaepassAppToAppScreen>
    with WidgetsBindingObserver {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  InAppWebViewController? _controller;

  Uri? _pendingSuccessUrl;
  Uri? _pendingFailureUrl;
  String? _nonce;
  bool _loading = true;
  bool _finished = false;

  UaepassConfig get _config => widget.config;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _linkSub = _appLinks.uriLinkStream.listen(_onAppReturn);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _appLinks.getLatestLink().then((uri) {
      if (uri != null) _onAppReturn(uri);
    });
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

    if (target == null) {
      _finish(null);
      return;
    }
    setState(() => _loading = true);
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
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context).pop(result);
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(null);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black54),
            onPressed: () => _finish(null),
          ),
          title: const Text(
            'UAE PASS',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest:
                  URLRequest(url: WebUri.uri(widget.authorizationUrl)),
              initialSettings: InAppWebViewSettings(
                useShouldOverrideUrlLoading: true,
                javaScriptEnabled: true,
                clearCache: true,
              ),
              onWebViewCreated: (controller) => _controller = controller,
              shouldOverrideUrlLoading: _onNavigation,
              onLoadStop: (_, __) {
                if (mounted) setState(() => _loading = false);
              },
            ),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF00A3E0)),
              ),
          ],
        ),
      ),
    );
  }
}

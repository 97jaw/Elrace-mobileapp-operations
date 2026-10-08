import 'package:el_race/config/uaepass_config.dart';
import 'package:el_race/utils/uaepass_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// UAE PASS app-to-web login (UAE PASS app not installed).
///
/// Shows the UAE PASS web login full screen inside Elrace with no header,
/// as UAE PASS requires. The Android back button or the iOS edge swipe
/// closes it. Pops with the final `elrace://uaepass/success|error` link from
/// the backend callback, or `null` when the user leaves.
class UaepassWebLoginScreen extends StatefulWidget {
  const UaepassWebLoginScreen({
    super.key,
    required this.config,
    required this.authorizationUrl,
  });

  final UaepassConfig config;
  final Uri authorizationUrl;

  @override
  State<UaepassWebLoginScreen> createState() => _UaepassWebLoginScreenState();
}

class _UaepassWebLoginScreenState extends State<UaepassWebLoginScreen> {
  bool _firstPageLoaded = false;
  bool _finished = false;

  UaepassConfig get _config => widget.config;

  void _finish(Uri result) {
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

    if (scheme == _config.deepLinkScheme) {
      if (_config.isSuccessLink(uri) || _config.isErrorLink(uri)) {
        UaepassLogger.logKV('UAE PASS web login returned', uri.toString());
        _finish(uri);
      }
      return NavigationActionPolicy.CANCEL;
    }
    if (scheme != 'http' && scheme != 'https' && scheme != 'about') {
      UaepassLogger.logWarning('Blocked non-web link in UAE PASS login: $uri');
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest:
                  URLRequest(url: WebUri.uri(widget.authorizationUrl)),
              initialSettings: InAppWebViewSettings(
                useShouldOverrideUrlLoading: true,
                javaScriptEnabled: true,
                clearCache: true,
                allowsBackForwardNavigationGestures: false,
              ),
              shouldOverrideUrlLoading: _onNavigation,
              onLoadStop: (_, __) {
                if (!_firstPageLoaded && mounted) {
                  setState(() => _firstPageLoaded = true);
                }
              },
            ),
            if (!_firstPageLoaded)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF00A3E0)),
              ),
          ],
        ),
      ),
    );
  }
}

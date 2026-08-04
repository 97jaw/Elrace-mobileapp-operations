import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AndroidPlayUpdateService {
  AndroidPlayUpdateService._();
  static final AndroidPlayUpdateService instance = AndroidPlayUpdateService._();

  static const MethodChannel _channel =
      MethodChannel('ae.elrace.mobile/play_update');

  Future<bool> startImmediateUpdateIfAvailable() async {
    if (!Platform.isAndroid) return false;

    try {
      return await _channel.invokeMethod<bool>(
            'startImmediateUpdateIfAvailable',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('⚠️ Android Play update check failed (ignored): $e');
      return false;
    }
  }
}

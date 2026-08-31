import 'dart:async';
import 'dart:io';

import 'package:el_race/core/app_globals.dart';
import 'package:el_race/ui/chat/incoming_share_chat_picker_screen.dart';
import 'package:el_race/ui/share/incoming_share_sign_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum IncomingShareTarget { chat, sign }

class IncomingSharePayload {
  const IncomingSharePayload({
    required this.target,
    required this.path,
    required this.fileName,
    this.mimeType,
  });

  final IncomingShareTarget target;
  final String path;
  final String fileName;
  final String? mimeType;

  File get file => File(path);

  factory IncomingSharePayload.fromMap(Map<dynamic, dynamic> map) {
    final rawTarget = (map['target'] ?? 'chat').toString().toLowerCase();
    return IncomingSharePayload(
      target: rawTarget == 'sign'
          ? IncomingShareTarget.sign
          : IncomingShareTarget.chat,
      path: (map['path'] ?? '').toString(),
      fileName: (map['fileName'] ?? 'shared_file').toString(),
      mimeType: map['mimeType']?.toString(),
    );
  }
}

/// Receives Android share-sheet targets (Elrace Chat / Elrace Sign).
class IncomingShareService {
  IncomingShareService._();

  static final IncomingShareService instance = IncomingShareService._();

  static const _methodChannel = MethodChannel('ae.elrace.mobile/share_target');
  static const _eventChannel =
      EventChannel('ae.elrace.mobile/share_target/events');

  StreamSubscription<dynamic>? _sub;
  IncomingSharePayload? _pending;
  bool _homeReady = false;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _sub = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        _enqueue(IncomingSharePayload.fromMap(event));
      }
    }, onError: (_) {});
    // ignore: unawaited_futures
    _pullInitial();
  }

  Future<void> _pullInitial() async {
    try {
      final raw = await _methodChannel.invokeMethod<dynamic>('getInitialShare');
      if (raw is Map) {
        _enqueue(IncomingSharePayload.fromMap(raw));
      }
    } catch (_) {}
  }

  /// Call once Home is mounted (same timing as notification tap replay).
  void markHomeReady() {
    _homeReady = true;
    final pending = _pending;
    if (pending != null) {
      _pending = null;
      // ignore: unawaited_futures
      _open(pending);
    }
  }

  void _enqueue(IncomingSharePayload payload) {
    if (payload.path.trim().isEmpty) return;
    final file = payload.file;
    if (!file.existsSync()) return;

    if (!_homeReady) {
      _pending = payload;
      return;
    }
    // ignore: unawaited_futures
    _open(payload);
  }

  Future<void> _open(IncomingSharePayload payload) async {
    final nav = navKey.currentState;
    if (nav == null) {
      _pending = payload;
      return;
    }

    switch (payload.target) {
      case IncomingShareTarget.chat:
        await nav.push(
          MaterialPageRoute(
            builder: (_) => IncomingShareChatPickerScreen(
              file: payload.file,
              fileName: payload.fileName,
              mimeType: payload.mimeType,
            ),
          ),
        );
        break;
      case IncomingShareTarget.sign:
        await IncomingShareSignFlow.open(
          nav.context,
          file: payload.file,
          fileName: payload.fileName,
        );
        break;
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }
}

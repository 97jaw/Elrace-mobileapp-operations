import 'dart:async';
import 'dart:io';

import 'package:el_race/core/app_globals.dart';
import 'package:el_race/ui/chat/incoming_share_chat_picker_screen.dart';
import 'package:el_race/ui/share/incoming_share_sign_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

enum IncomingShareTarget { chat, sign, choose }

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
    final target = switch (rawTarget) {
      'sign' => IncomingShareTarget.sign,
      'choose' => IncomingShareTarget.choose,
      _ => IncomingShareTarget.chat,
    };
    return IncomingSharePayload(
      target: target,
      path: (map['path'] ?? '').toString(),
      fileName: (map['fileName'] ?? 'shared_file').toString(),
      mimeType: map['mimeType']?.toString(),
    );
  }
}

/// Receives Android share-sheet targets (Elrace Chat / Elrace Sign)
/// and iOS "Open in" file URLs (shows Chat vs Sign chooser).
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
    // Native share aliases + channels exist on Android only.
    // iOS uses Open-in / file:// via handleSharedFileUri (app_links).
    if (!Platform.isAndroid) return;
    _sub = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        _enqueue(IncomingSharePayload.fromMap(event));
      }
    }, onError: (_) {});
    // ignore: unawaited_futures
    _pullInitial();
  }

  Future<void> _pullInitial() async {
    if (!Platform.isAndroid) return;
    try {
      final raw = await _methodChannel.invokeMethod<dynamic>('getInitialShare');
      if (raw is Map) {
        _enqueue(IncomingSharePayload.fromMap(raw));
      }
    } catch (_) {}
  }

  /// iOS Open-in / share delivers `file://...` via app_links — not as Chat/Sign aliases.
  Future<void> handleSharedFileUri(Uri uri) async {
    final path = uri.scheme == 'file' ? (uri.toFilePath()) : uri.path;
    if (path.trim().isEmpty) return;
    final file = File(path);
    if (!await file.exists()) return;

    _enqueue(
      IncomingSharePayload(
        target: IncomingShareTarget.choose,
        path: path,
        fileName: p.basename(path),
        mimeType: _guessMime(path),
      ),
    );
  }

  String? _guessMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.md') || lower.endsWith('.txt')) return 'text/plain';
    return null;
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

    var target = payload.target;
    if (target == IncomingShareTarget.choose) {
      final picked = await showModalBottomSheet<IncomingShareTarget>(
        context: nav.context,
        backgroundColor: const Color(0xFF1A2438),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Open with Elrace',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    payload.fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline,
                        color: Colors.white),
                    title: const Text('Elrace Chat',
                        style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Send this file in a chat',
                        style: TextStyle(color: Colors.white70)),
                    onTap: () =>
                        Navigator.pop(ctx, IncomingShareTarget.chat),
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.draw_outlined, color: Colors.white),
                    title: const Text('Elrace Sign',
                        style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Upload for signature (PDF)',
                        style: TextStyle(color: Colors.white70)),
                    onTap: () =>
                        Navigator.pop(ctx, IncomingShareTarget.sign),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (picked == null) return;
      target = picked;
    }

    switch (target) {
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
      case IncomingShareTarget.choose:
        break;
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }
}

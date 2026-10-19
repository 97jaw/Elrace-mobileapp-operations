import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

/// Long-lived worker isolate that runs a pinned TFLite interpreter via the
/// ByteBuffer path (tensor.data = bytes → invoke).
///
/// Critical: [Interpreter.fromAddress] defaults `allocated: false`, which
/// overwrites the Dart `_allocated` flag after the constructor's
/// [Interpreter.allocateTensors] — so [Interpreter.invoke] throws
/// "Interpreter not allocated". Always pass `allocated: true` when the native
/// interpreter was already allocated on the creating isolate.
class TfliteByteBufferWorker {
  TfliteByteBufferWorker._({
    required this.debugName,
    required SendPort sendPort,
    required Isolate isolate,
    required ReceivePort receivePort,
    required StreamSubscription subscription,
  })  : _sendPort = sendPort,
        _isolate = isolate,
        _receivePort = receivePort,
        _subscription = subscription;

  final String debugName;
  final SendPort _sendPort;
  final Isolate _isolate;
  final ReceivePort _receivePort;
  final StreamSubscription _subscription;
  var _closed = false;
  Completer<Float32List>? _pending;

  static Future<TfliteByteBufferWorker> create({
    required int interpreterAddress,
    required int inputFloatCount,
    required int outputFloatCount,
    String debugName = 'TfliteByteBufferWorker',
  }) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      _workerMain,
      _WorkerInit(
        replyTo: receivePort.sendPort,
        address: interpreterAddress,
        inputFloatCount: inputFloatCount,
        outputFloatCount: outputFloatCount,
      ),
      debugName: debugName,
    );

    final ready = Completer<SendPort>();
    late final TfliteByteBufferWorker worker;

    final sub = receivePort.listen((msg) {
      if (msg is SendPort && !ready.isCompleted) {
        ready.complete(msg);
        return;
      }
      final pending = worker._pending;
      if (pending == null || pending.isCompleted) return;
      if (msg is Float32List) {
        pending.complete(msg);
        return;
      }
      if (msg is String) {
        pending.completeError(StateError(msg));
      }
    });

    final sendPort = await ready.future;
    worker = TfliteByteBufferWorker._(
      debugName: debugName,
      sendPort: sendPort,
      isolate: isolate,
      receivePort: receivePort,
      subscription: sub,
    );
    return worker;
  }

  Future<Float32List> run(Float32List input) async {
    if (_closed) {
      throw StateError('$debugName already closed');
    }
    while (_pending != null && !_pending!.isCompleted) {
      await _pending!.future;
    }
    final done = Completer<Float32List>();
    _pending = done;
    _sendPort.send(input);
    try {
      return await done.future;
    } finally {
      if (identical(_pending, done)) _pending = null;
    }
  }

  /// Closes only the worker isolate — never the shared [Interpreter] itself.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _sendPort.send(null);
    await _subscription.cancel();
    _receivePort.close();
    _isolate.kill(priority: Isolate.immediate);
  }

  static Future<void> _workerMain(_WorkerInit init) async {
    final port = ReceivePort();
    init.replyTo.send(port.sendPort);
    // Native tensors already allocated on the creating isolate; tell the Dart
    // wrapper so invoke() does not throw "Interpreter not allocated".
    final interpreter = Interpreter.fromAddress(
      init.address,
      allocated: true,
    );
    final outScratch = Float32List(init.outputFloatCount);

    await for (final msg in port) {
      if (msg == null) break;
      if (msg is! Float32List) {
        init.replyTo.send('expected Float32List');
        continue;
      }
      if (msg.length != init.inputFloatCount) {
        init.replyTo.send(
          'input length ${msg.length}, expected ${init.inputFloatCount}',
        );
        continue;
      }
      try {
        final inputBytes = msg.buffer.asUint8List(
          msg.offsetInBytes,
          msg.lengthInBytes,
        );
        interpreter.getInputTensor(0).data = inputBytes;
        interpreter.invoke();
        final outBytes = interpreter.getOutputTensor(0).data;
        final outFloats = outBytes.buffer.asFloat32List(
          outBytes.offsetInBytes,
          init.outputFloatCount,
        );
        outScratch.setAll(0, outFloats);
        init.replyTo.send(Float32List.fromList(outScratch));
      } catch (e) {
        init.replyTo.send(e.toString());
      }
    }
    port.close();
  }
}

class _WorkerInit {
  const _WorkerInit({
    required this.replyTo,
    required this.address,
    required this.inputFloatCount,
    required this.outputFloatCount,
  });

  final SendPort replyTo;
  final int address;
  final int inputFloatCount;
  final int outputFloatCount;
}

import 'dart:async';

/// Limits parallel ERP calls from the Projects module to reduce connection drops.
class ProjectsApiCoordinator {
  ProjectsApiCoordinator._();

  static final ProjectsApiCoordinator instance = ProjectsApiCoordinator._();

  static const int _maxConcurrent = 2;

  int _active = 0;
  final List<Completer<void>> _queue = [];

  Future<T> run<T>(Future<T> Function() action) async {
    await _acquire();
    try {
      return await action();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_active < _maxConcurrent) {
      _active++;
      return;
    }
    final waiter = Completer<void>();
    _queue.add(waiter);
    await waiter.future;
    _active++;
  }

  void _release() {
    _active--;
    if (_queue.isEmpty) return;
    _queue.removeAt(0).complete();
  }
}

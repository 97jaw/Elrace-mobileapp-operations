// HD-0149 SIMULATION - not a network test.
// Deterministic arithmetic model of the current resume/push/approve gates with
// assumed I/O durations. It performs no network I/O and calls no app code.
// Usage: dart run tool/hd0149_refresh_load_probe.dart
import 'dart:convert';

enum ProbeEventType { resume, approvalPush, approveReject }

class ProbeEvent {
  const ProbeEvent(this.atMs, this.type);

  final int atMs;
  final ProbeEventType type;
}

void main() {
  const refreshDurationMs = 1200;
  const approvalReloadDurationMs = 900;
  const pushThrottleMs = 30000;

  final events = <ProbeEvent>[
    for (var i = 0; i < 20; i++) ProbeEvent(i * 250, ProbeEventType.resume),
    for (var i = 0; i < 20; i++)
      ProbeEvent(100 + (i * 500), ProbeEventType.approvalPush),
    for (var i = 0; i < 10; i++)
      ProbeEvent(200 + (i * 1500), ProbeEventType.approveReject),
  ]..sort((a, b) => a.atMs.compareTo(b.atMs));

  var globalRefreshes = 0;
  var coalescedResumes = 0;
  var throttledPushes = 0;
  var approvalReconciliations = 0;
  var waitingApiCalls = 0;
  var notificationApiCalls = 0;
  var globalBusyUntil = -1;
  var listBusyUntil = -1;
  int? lastPushRefreshAt;

  for (final event in events) {
    switch (event.type) {
      case ProbeEventType.resume:
        if (event.atMs < globalBusyUntil) {
          coalescedResumes++;
          continue;
        }
        globalRefreshes++;
        globalBusyUntil = event.atMs + refreshDurationMs;
        waitingApiCalls += 4;
        notificationApiCalls++;
      case ProbeEventType.approvalPush:
        final last = lastPushRefreshAt;
        if (last != null && event.atMs - last < pushThrottleMs) {
          throttledPushes++;
          continue;
        }
        lastPushRefreshAt = event.atMs;
        if (event.atMs < globalBusyUntil) continue;
        globalRefreshes++;
        globalBusyUntil = event.atMs + refreshDurationMs;
        waitingApiCalls += 4;
        notificationApiCalls++;
      case ProbeEventType.approveReject:
        approvalReconciliations++;
        if (event.atMs >= listBusyUntil) {
          listBusyUntil = event.atMs + approvalReloadDurationMs;
        }
        waitingApiCalls += 4;
    }
  }

  print(const JsonEncoder.withIndent('  ').convert(<String, Object>{
    'probe': 'HD-0149 current refresh policy stress model',
    'input_events': <String, int>{
      'resume': 20,
      'approval_push': 20,
      'approve_reject': 10,
    },
    'assumed_io_ms': <String, int>{
      'global_refresh': refreshDurationMs,
      'approval_list_reload': approvalReloadDurationMs,
    },
    'observed_policy_result': <String, int>{
      'global_refreshes_started': globalRefreshes,
      'resume_events_coalesced': coalescedResumes,
      'approval_pushes_throttled': throttledPushes,
      'approval_reconciliations': approvalReconciliations,
      'waiting_endpoint_calls': waitingApiCalls,
      'notification_endpoint_calls': notificationApiCalls,
    },
    'note':
        'This deterministic probe exercises the current gates; device traces provide real network timings.',
  }));
}

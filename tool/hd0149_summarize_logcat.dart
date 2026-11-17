// HD-0149 evidence-analysis tool (read-only, diagnostic).
// Parses `[HD0149]` JSON trace lines from a logcat capture or a .jsonl extract and
// prints event counts and I/O timing statistics (n/min/median/avg/max/errors).
// Usage: dart run tool/hd0149_summarize_logcat.dart <file> [--timeline]
// It only reads the given file; it does not touch the app, device or any data.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final text = File(args.first).readAsStringSync();
  final events = <Map<String, dynamic>>[];
  for (final m in RegExp(r'\{"seq":\d+.*?\}(?=\s*$|\s*\r?\n)', multiLine: true)
      .allMatches(text)) {
    try {
      events.add(jsonDecode(m.group(0)!) as Map<String, dynamic>);
    } catch (_) {}
  }
  stdout.writeln('events parsed: ${events.length}');
  if (args.contains('--timeline')) {
    for (final e in events) {
      stdout.writeln(jsonEncode(e));
    }
    return;
  }
  final io = <String, List<int>>{};
  final ioErr = <String, int>{};
  final kinds = <String, int>{};
  for (final e in events) {
    final key = '${e['kind']} ${e['domain']}.${e['name']}';
    kinds[key] = (kinds[key] ?? 0) + 1;
    if (e['kind'] == 'io_end') {
      final k = '${e['domain']} ${e['name']}';
      (io[k] ??= []).add(e['duration_ms'] as int);
      if (e['status'] != 'success') ioErr[k] = (ioErr[k] ?? 0) + 1;
    }
  }
  stdout.writeln('\n== event counts ==');
  (kinds.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).forEach(
      (e) => stdout.writeln('${e.value.toString().padLeft(4)}  ${e.key}'));
  stdout.writeln('\n== io timings (ms) ==');
  io.forEach((k, v) {
    v.sort();
    final avg = v.reduce((a, b) => a + b) / v.length;
    stdout.writeln('$k  n=${v.length} min=${v.first} '
        'median=${v[v.length ~/ 2]} avg=${avg.round()} max=${v.last} '
        'errors=${ioErr[k] ?? 0}');
  });
}

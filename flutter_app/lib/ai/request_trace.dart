/// 请求追踪记录（对齐原生 RequestTraceAdapter）
class RequestTrace {
  RequestTrace({
    required this.url,
    required this.model,
    required this.statusCode,
    required this.durationMs,
    required this.success,
    required this.at,
    this.error,
  });

  final String url;
  final String model;
  final int statusCode;
  final int durationMs;
  final bool success;
  final DateTime at;
  final String? error;

  String get timeText {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    final s = at.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// 最近请求的内存记录（最多 100 条）
class RequestTraceStore {
  RequestTraceStore._();

  static final RequestTraceStore instance = RequestTraceStore._();
  static const int _maxEntries = 100;

  final List<RequestTrace> _entries = [];

  List<RequestTrace> get entries => List.unmodifiable(_entries.reversed);

  void add(RequestTrace trace) {
    _entries.add(trace);
    while (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
  }

  void clear() => _entries.clear();
}

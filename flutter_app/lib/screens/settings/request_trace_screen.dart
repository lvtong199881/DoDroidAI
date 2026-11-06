import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ai/request_trace.dart';

/// 请求追踪（对齐原生 RequestTraceAdapter）
class RequestTraceScreen extends StatefulWidget {
  const RequestTraceScreen({super.key});

  @override
  State<RequestTraceScreen> createState() => _RequestTraceScreenState();
}

class _RequestTraceScreenState extends State<RequestTraceScreen> {
  /// 导出全部请求记录到剪贴板
  Future<void> _export() async {
    final entries = RequestTraceStore.instance.entries;
    if (entries.isEmpty) return;
    final buffer = StringBuffer('# 请求追踪\n\n');
    for (final trace in entries) {
      buffer.writeln(
        '- ${trace.timeText} | ${trace.model} | ${trace.statusCode} | '
        '${trace.durationMs}ms | ${trace.url}',
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已导出到剪贴板')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = RequestTraceStore.instance.entries;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('请求追踪', style: TextStyle(fontSize: 20)),
        actions: [
          IconButton(
            tooltip: '导出',
            icon: const Icon(Icons.ios_share),
            onPressed: entries.isEmpty ? null : _export,
          ),
          TextButton(
            onPressed: entries.isEmpty
                ? null
                : () => setState(() => RequestTraceStore.instance.clear()),
            child: const Text('清空'),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Text(
                '暂无请求记录',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final trace = entries[index];
                final statusColor =
                    trace.success ? const Color(0xFF1E8E5A) : scheme.error;
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              trace.model,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${trace.statusCode} · ${trace.durationMs}ms',
                            style: TextStyle(
                              fontSize: 13,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trace.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trace.timeText,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

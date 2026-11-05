import 'package:flutter/material.dart';

import '../../data/tool_audit_database.dart';

class ToolAuditScreen extends StatefulWidget {
  const ToolAuditScreen({super.key});

  @override
  State<ToolAuditScreen> createState() => _ToolAuditScreenState();
}

class _ToolAuditScreenState extends State<ToolAuditScreen> {
  final ToolAuditRepository _repository = ToolAuditRepository.instance;
  List<ToolAuditEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _repository.list();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    await _repository.clear();
    await _load();
  }

  String _formatTime(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('工具审计', style: TextStyle(fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _entries.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text('暂无工具执行记录'))
              : ListView.separated(
                  itemCount: _entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return ListTile(
                      leading: Icon(
                        entry.success
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: entry.success
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                      title: Text(entry.toolName),
                      subtitle: Text(
                        '${_formatTime(entry.createdAt)} · ${entry.argsSummary.isEmpty ? '无参数' : entry.argsSummary}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
    );
  }
}

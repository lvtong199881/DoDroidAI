import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import '../../data/permission_policy_database.dart';
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
        title: Text(AppStrings.of(context).t('toolAudit'), style: const TextStyle(fontSize: 20)),
        actions: [
          IconButton(
            tooltip: '重置权限策略',
            icon: const Icon(Icons.lock_reset_outlined),
            onPressed: () async {
              await PermissionPolicyRepository.instance.clearAll();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已重置权限策略'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _entries.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(child: Text(AppStrings.of(context).t('emptyAudit')))
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

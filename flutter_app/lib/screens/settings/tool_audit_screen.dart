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
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).t('toolAudit'), style: const TextStyle(fontSize: 20)),
        actions: [
          TextButton(
            onPressed: _entries.isEmpty ? null : _clear,
            child: const Text('清空'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(child: Text(AppStrings.of(context).t('emptyAudit')))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _entries.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _entries.length) {
                      final scheme = Theme.of(context).colorScheme;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: TextButton(
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
                            child: Text(
                              '重置权限提示',
                              style: TextStyle(color: scheme.primary),
                            ),
                          ),
                        ),
                      );
                    }
                    final entry = _entries[index];
                    final scheme = Theme.of(context).colorScheme;
                    final statusColor =
                        entry.success ? const Color(0xFF1E8E5A) : scheme.error;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
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
                                    entry.toolName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ),
                                Text(
                                  entry.success ? '成功' : '失败',
                                  style: TextStyle(fontSize: 14, color: statusColor),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                entry.argsSummary.isEmpty ? '{}' : entry.argsSummary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _formatTime(entry.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

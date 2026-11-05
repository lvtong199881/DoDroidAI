import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/chat_database.dart';
import '../../../l10n/app_strings.dart';
import '../chat_provider.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({
    super.key,
    required this.onOpenSettings,
  });

  final VoidCallback onOpenSettings;

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  bool _searching = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _groupLabel(int updatedAt) {
    final date = DateTime.fromMillisecondsSinceEpoch(updatedAt);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return '今天';
    if (today.difference(day).inDays == 1) return '昨天';
    if (today.difference(day).inDays < 7) return '7天内';
    return '更早';
  }

  List<MapEntry<String, List<ChatSession>>> _grouped(List<ChatSession> sessions) {
    final map = <String, List<ChatSession>>{};
    for (final session in sessions) {
      final label = _groupLabel(session.updatedAt);
      map.putIfAbsent(label, () => []).add(session);
    }
    const order = ['今天', '昨天', '7天内', '更早'];
    final result = <MapEntry<String, List<ChatSession>>>[];
    for (final key in order) {
      if (map.containsKey(key)) {
        result.add(MapEntry(key, map[key]!));
      }
    }
    return result;
  }

  Future<void> _confirmDelete(ChatSession session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定删除「${session.name}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(chatProvider.notifier).deleteSession(session.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(chatProvider);
    final sessions = state.sessions.where((session) {
      if (_query.isEmpty) return true;
      return session.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();
    final groups = _grouped(sessions);
    final currentId = state.currentSessionId;

    return Drawer(
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            if (_searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '搜索对话',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            Expanded(
              child: groups.isEmpty
                  ? Center(
                      child: Text(
                        _query.isEmpty ? '暂无对话' : '没有匹配的对话',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        for (final group in groups) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              group.key,
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          for (final session in group.value)
                            _SessionTile(
                              session: session,
                              selected: session.id == currentId,
                              onTap: () {
                                ref
                                    .read(chatProvider.notifier)
                                    .loadSession(session.id);
                                Navigator.of(context).pop();
                              },
                              onLongPress: () => _confirmDelete(session),
                            ),
                        ],
                      ],
                    ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Text(
                    'DoDroidAI',
                    style: TextStyle(
                      fontSize: 20,
                      color: scheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '搜索',
                    icon: Icon(Icons.search, color: scheme.primary),
                    onPressed: () {
                      setState(() => _searching = !_searching);
                      if (!_searching) {
                        _searchController.clear();
                        _query = '';
                      }
                    },
                  ),
                  IconButton(
                    tooltip: AppStrings.of(context).settings,
                    icon: Icon(Icons.settings, color: scheme.primary),
                    onPressed: widget.onOpenSettings,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final ChatSession session;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          session.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            color: selected ? scheme.primary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

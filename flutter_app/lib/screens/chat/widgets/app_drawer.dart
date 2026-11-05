import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat_provider.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({
    super.key,
    required this.onNewChat,
    required this.onOpenSettings,
  });

  final VoidCallback onNewChat;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(chatProvider);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.smart_toy_outlined, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Text('DoDroidAI',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_comment_outlined),
              title: const Text('新对话'),
              onTap: () {
                Navigator.of(context).pop();
                onNewChat();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('设置'),
              onTap: () {
                debugPrint('drawer settings tapped');
                Navigator.of(context).pop();
                onOpenSettings();
              },
            ),
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('最近对话', style: TextStyle(fontSize: 12)),
            ),
            Expanded(
              child: state.sessions.isEmpty
                  ? const Center(
                      child: Text('暂无对话', style: TextStyle(fontSize: 12)),
                    )
                  : ListView.builder(
                      itemCount: state.sessions.length,
                      itemBuilder: (context, index) {
                        final session = state.sessions[index];
                        final selected = session.id == state.currentSessionId;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          title: Text(
                            session.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: selected ? scheme.primary : scheme.onSurface,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 18, color: scheme.outline),
                            onPressed: () => ref
                                .read(chatProvider.notifier)
                                .deleteSession(session.id),
                          ),
                          onTap: () {
                            Navigator.of(context).pop();
                            ref.read(chatProvider.notifier).loadSession(session.id);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.onNewChat});

  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                  const Text('DoDroidAI', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
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
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('最近对话', style: TextStyle(fontSize: 12)),
            ),
            ListTile(
              dense: true,
              title: const Text('hello'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              dense: true,
              title: const Text('what time is it'),
              onTap: () => Navigator.of(context).pop(),
            ),
            const Spacer(),
            const ListTile(
              leading: Icon(Icons.settings_outlined),
              title: Text('设置'),
            ),
          ],
        ),
      ),
    );
  }
}

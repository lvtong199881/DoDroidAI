import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/chat_provider.dart';

class ChatSettingsScreen extends ConsumerWidget {
  const ChatSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('对话', style: TextStyle(fontSize: 20)),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('自动朗读回复'),
            subtitle: const Text('每条助手回复生成后自动朗读'),
            value: state.autoRead,
            onChanged: (_) => ref.read(chatProvider.notifier).toggleAutoRead(),
          ),
        ],
      ),
    );
  }
}

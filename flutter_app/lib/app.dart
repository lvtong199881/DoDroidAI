import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/chat/chat_screen.dart';
import 'settings/app_settings.dart';
import 'theme/app_theme.dart';

class DoDroidApp extends ConsumerWidget {
  const DoDroidApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'DoDroidAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const ChatScreen(),
    );
  }
}

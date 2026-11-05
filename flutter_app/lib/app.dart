import 'package:flutter/material.dart';

import 'screens/chat/chat_screen.dart';
import 'theme/app_theme.dart';

class DoDroidApp extends StatelessWidget {
  const DoDroidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoDroidAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const ChatScreen(),
    );
  }
}

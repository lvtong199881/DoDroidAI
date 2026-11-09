import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_strings.dart';
import 'screens/chat/chat_screen.dart';
import 'settings/app_settings.dart';
import 'theme/app_theme.dart';

class DoDroidApp extends ConsumerWidget {
  const DoDroidApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      title: 'DoDroidAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      builder: (context, child) {
        // 系统状态栏 / 导航栏跟随应用主题，而非系统深色设置
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final barColor =
            isDark ? AppColors.dark['surface']! : AppColors.light['surface']!;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: barColor,
            systemNavigationBarDividerColor: barColor,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            // Android 10+ 会给导航栏加对比度蒙层，深色下表现为白色半透明
            systemNavigationBarContrastEnforced: false,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const ChatScreen(),
    );
  }
}

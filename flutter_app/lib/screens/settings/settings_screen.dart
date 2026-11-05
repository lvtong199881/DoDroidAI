import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_config.dart';
import '../../l10n/app_strings.dart';
import '../../settings/app_settings.dart';
import '../../theme/app_theme.dart';
import '../memory/memory_screen.dart';
import '../notes/note_list_screen.dart';
import '../tasks/scheduled_task_screen.dart';
import 'chat_settings_screen.dart';
import 'stt_settings_screen.dart';
import 'tts_settings_screen.dart';
import 'diagnostics_screen.dart';
import 'web_search_settings.dart';
import 'api_config_screen.dart';
import 'tool_audit_screen.dart';

final aiConfigProvider = FutureProvider<AiConfig?>((ref) async {
  return AiConfigStore().loadActive();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final localeValue = switch (locale?.languageCode) {
      'zh' => '简体中文',
      'en' => 'English',
      _ => '跟随系统',
    };
    final themeValue = switch (themeMode) {
      ThemeMode.light => strings.light,
      ThemeMode.dark => strings.dark,
      _ => strings.followSystem,
    };

    final brightness = Theme.of(context).brightness;
    final background = brightness == Brightness.dark
        ? AppColors.dark['background']!
        : AppColors.light['background']!;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(strings.settings, style: const TextStyle(fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SectionHeader(text: 'AI'),
          _SettingsCard(children: [
            _SettingsItem(
              title: strings.apiConfig,
              value: ref.watch(aiConfigProvider).when(
                    data: (config) =>
                        (config?.providerName.isNotEmpty ?? false)
                            ? config!.providerName
                            : '未配置',
                    loading: () => '…',
                    error: (_, __) => '未配置',
                  ),
              onTap: () async {
                final config = await ref.read(aiConfigProvider.future);
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ApiConfigScreen(config: config),
                  ),
                );
                ref.invalidate(aiConfigProvider);
              },
            ),
          ]),
          const SizedBox(height: 16),
          _SectionHeader(text: '应用'),
          _SettingsCard(children: [
            _SettingsItem(
              title: strings.language,
              value: localeValue,
              onTap: () => _pickLocale(context, ref),
            ),
            _SettingsItem(
              title: strings.appearance,
              value: themeValue,
              onTap: () => _pickTheme(context, ref),
            ),
            _SettingsItem(
              title: '联网搜索',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WebSearchSettingsScreen()),
              ),
            ),
            _SettingsItem(
              title: strings.notes,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NoteListScreen()),
              ),
            ),
            _SettingsItem(
              title: '工具审计',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ToolAuditScreen()),
              ),
            ),
            _SettingsItem(
              title: strings.memory,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MemoryScreen()),
              ),
            ),
            _SettingsItem(
              title: '定时任务',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScheduledTaskScreen()),
              ),
            ),
            _SettingsItem(
              title: '语音输入',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SttSettingsScreen()),
              ),
            ),
            _SettingsItem(
              title: '语音输出',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TtsSettingsScreen()),
              ),
            ),
            _SettingsItem(
              title: '诊断',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
              ),
            ),
            _SettingsItem(
              title: '对话',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChatSettingsScreen()),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _pickLocale(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('跟随系统'),
              trailing: ref.read(localeProvider) == null
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(null);
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              title: const Text('简体中文'),
              trailing: ref.read(localeProvider)?.languageCode == 'zh'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('zh'));
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              title: const Text('English'),
              trailing: ref.read(localeProvider)?.languageCode == 'en'
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('en'));
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in [
              (ThemeMode.system, '跟随系统'),
              (ThemeMode.light, '浅色'),
              (ThemeMode.dark, '深色'),
            ])
              ListTile(
                title: Text(option.$2),
                trailing: ref.watch(themeModeProvider) == option.$1
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).setMode(option.$1);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }


}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, indent: 16, color: scheme.outlineVariant),
          ],
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({required this.title, this.value, required this.onTap});

  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Text(title, style: TextStyle(fontSize: 16, color: scheme.onSurface)),
            const Spacer(),
            if (value != null)
              Text(
                value!,
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}

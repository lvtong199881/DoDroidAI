import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_strings.dart';
import '../../settings/app_settings.dart';
import '../../theme/app_theme.dart';
import '../memory/memory_screen.dart';
import '../notes/note_list_screen.dart';
import '../tasks/scheduled_task_screen.dart';
import 'api_config_screen.dart';
import 'tool_audit_screen.dart';

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
              value: '自定义',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ApiConfigScreen()),
              ),
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
              onTap: () => _showWebSearch(context),
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
              onTap: () => _showPlaceholder(context, '语音输入'),
            ),
            _SettingsItem(
              title: '语音输出',
              onTap: () => _showPlaceholder(context, '语音输出'),
            ),
            _SettingsItem(
              title: '诊断',
              onTap: () => _showPlaceholder(context, '诊断'),
            ),
            _SettingsItem(
              title: '对话',
              onTap: () => _showPlaceholder(context, '对话'),
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

  Future<void> _showWebSearch(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('联网搜索'),
        content: const Text('联网搜索由模型工具 web_search 提供，当前 Flutter 版尚未接入。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPlaceholder(BuildContext context, String title) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text('该设置项正在迁移中。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
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

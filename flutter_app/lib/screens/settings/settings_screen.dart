import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_config.dart';
import '../../l10n/app_strings.dart';
import '../../settings/app_settings.dart';
import '../memory/memory_screen.dart';
import '../notes/note_list_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  final _model = TextEditingController();
  bool _loading = true;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await AiConfigStore().load();
    if (!mounted) return;
    setState(() {
      _baseUrl.text = config.baseUrl;
      _apiKey.text = config.apiKey;
      _model.text = config.model;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await AiConfigStore().save(AiConfig(
      baseUrl: _baseUrl.text,
      apiKey: _apiKey.text,
      model: _model.text,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存'), duration: Duration(seconds: 1)),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.settings, style: const TextStyle(fontSize: 20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(strings.appearance,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(value: ThemeMode.system, label: Text(strings.followSystem)),
                    ButtonSegment(value: ThemeMode.light, label: Text(strings.light)),
                    ButtonSegment(value: ThemeMode.dark, label: Text(strings.dark)),
                  ],
                  selected: {ref.watch(themeModeProvider)},
                  onSelectionChanged: (selection) => ref
                      .read(themeModeProvider.notifier)
                      .setMode(selection.first),
                ),
                const SizedBox(height: 24),
                Text(strings.language,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'system', label: Text('跟随系统')),
                    ButtonSegment(value: 'zh', label: Text('中文')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {
                    ref.watch(localeProvider)?.languageCode ?? 'system'
                  },
                  onSelectionChanged: (selection) {
                    final value = selection.first;
                    ref.read(localeProvider.notifier).setLocale(
                          value == 'system' ? null : Locale(value),
                        );
                  },
                ),
                const SizedBox(height: 24),
                Text(strings.apiConfig,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  controller: _baseUrl,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: AiConfig.defaultBaseUrl,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKey,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _model,
                  decoration: const InputDecoration(
                    labelText: 'Model',
                    hintText: AiConfig.defaultModel,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _save,
                  child: Text(strings.save),
                ),
                const SizedBox(height: 32),
                Text(strings.features,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sticky_note_2_outlined),
                  title: Text(strings.notes),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NoteListScreen()),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.psychology_outlined),
                  title: Text(strings.memory),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MemoryScreen()),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    super.dispose();
  }
}

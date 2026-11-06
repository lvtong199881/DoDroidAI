import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/app_settings.dart';

/// 语言设置页（对齐原生 LanguageSettingFragment：三个单选）
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final current = locale == null
        ? null
        : (locale.languageCode == 'zh' && locale.countryCode == 'TW')
            ? 'zh_TW'
            : locale.languageCode;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('语言', style: TextStyle(fontSize: 20)),
      ),
      body: ListView(
        children: [
          RadioListTile<String?>(
            title: const Text('English'),
            value: 'en',
            groupValue: current,
            onChanged: (_) => _select(ref, const Locale('en')),
          ),
          RadioListTile<String?>(
            title: const Text('简体中文'),
            value: 'zh',
            groupValue: current,
            onChanged: (_) => _select(ref, const Locale('zh')),
          ),
          RadioListTile<String?>(
            title: const Text('繁體中文'),
            value: 'zh_TW',
            groupValue: current,
            onChanged: (_) => _select(ref, const Locale('zh', 'TW')),
          ),
        ],
      ),
    );
  }

  void _select(WidgetRef ref, Locale locale) {
    ref.read(localeProvider.notifier).setLocale(locale);
  }
}

import 'package:flutter/material.dart';

/// 简单中英文案表（后续可换 ARB/intl）
class AppStrings {
  AppStrings(this.locale);

  final Locale locale;

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ?? AppStrings(const Locale('zh'));
  }

  static const LocalizationsDelegate<AppStrings> delegate = _AppStringsDelegate();

  static const Map<String, Map<String, String>> _values = {
    'zh': {
      'appName': 'DoDroidAI',
      'newChat': '新对话',
      'recentChats': '最近对话',
      'settings': '设置',
      'emptyHint': '发送消息开始对话',
      'inputHint': '输入消息...',
      'deepThink': '深度思考',
      'webSearch': '智能搜索',
      'confirmTool': '确认执行工具',
      'execute': '执行',
      'cancel': '取消',
      'speechStarting': '语音输入正在迁移为纯 Flutter 实现',
      'appearance': '外观',
      'followSystem': '跟随系统',
      'light': '浅色',
      'dark': '深色',
      'apiConfig': 'API 配置',
      'save': '保存',
      'features': '功能',
      'notes': '笔记',
      'memory': '记忆',
      'language': '语言',
    },
    'en': {
      'appName': 'DoDroidAI',
      'newChat': 'New chat',
      'recentChats': 'Recent chats',
      'settings': 'Settings',
      'emptyHint': 'Send a message to start',
      'inputHint': 'Message...',
      'deepThink': 'Deep think',
      'webSearch': 'Web search',
      'confirmTool': 'Confirm tool execution',
      'execute': 'Run',
      'cancel': 'Cancel',
      'speechStarting': 'Voice input is being ported to pure Flutter',
      'appearance': 'Appearance',
      'followSystem': 'System',
      'light': 'Light',
      'dark': 'Dark',
      'apiConfig': 'API config',
      'save': 'Save',
      'features': 'Features',
      'notes': 'Notes',
      'memory': 'Memory',
      'language': 'Language',
    },
  };

  String t(String key) {
    final lang = locale.languageCode == 'en' ? 'en' : 'zh';
    return _values[lang]?[key] ?? _values['zh']?[key] ?? key;
  }

  // 常用快捷访问
  String get appName => t('appName');
  String get newChat => t('newChat');
  String get recentChats => t('recentChats');
  String get settings => t('settings');
  String get emptyHint => t('emptyHint');
  String get inputHint => t('inputHint');
  String get deepThink => t('deepThink');
  String get webSearch => t('webSearch');
  String get confirmTool => t('confirmTool');
  String get execute => t('execute');
  String get cancel => t('cancel');
  String get appearance => t('appearance');
  String get followSystem => t('followSystem');
  String get light => t('light');
  String get dark => t('dark');
  String get apiConfig => t('apiConfig');
  String get save => t('save');
  String get features => t('features');
  String get notes => t('notes');
  String get memory => t('memory');
  String get language => t('language');
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => ['zh', 'en'].contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

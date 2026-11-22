import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/l10n/app_strings.dart';

/// PRD 6.1 中文定稿（逐字，不得改写）。
const Map<String, String> _zhCopy = {
  'welcomeTitle': '欢迎使用 DoDroidAI',
  'welcomeIntro': '说一句话，让手机替你做事。',
  'welcomeFeat1Title': '按住说话就行',
  'welcomeFeat1Desc':
      '语音识别和朗读在手机本地完成；首次使用需联网下载语音模型（默认 Wi-Fi 下自动下载）。',
  'welcomeFeat2Title': '它会动手，不只是聊天',
  'welcomeFeat2Desc': '发短信、记笔记前会先请你确认；闹钟、日历等操作直接执行。',
  'welcomeFeat3Title': '会话和笔记留在本机',
  'welcomeFeat3Desc': '保存在本机，会话可随时导出；使用 AI 时内容会发送给你配置的服务商。',
  'welcomeStart': '开始使用',
};

/// PRD 6.2 English 定稿（逐字，不得改写）。
const Map<String, String> _enCopy = {
  'welcomeTitle': 'Welcome to DoDroidAI',
  'welcomeIntro': 'Say it, and let your phone do it.',
  'welcomeFeat1Title': 'Just hold to talk',
  'welcomeFeat1Desc':
      'Speech recognition and read-aloud run on your phone; voice models download once over the network (automatic on Wi-Fi).',
  'welcomeFeat2Title': 'It acts, not just chats',
  'welcomeFeat2Desc':
      'Sending texts and saving notes ask for your confirmation first; alarms and calendar events run directly.',
  'welcomeFeat3Title': 'Chats and notes stay on this phone',
  'welcomeFeat3Desc':
      'Stored locally; chats can be exported anytime. AI requests go to the provider you configure.',
  'welcomeStart': 'Get started',
};

void main() {
  test('中文 9 条欢迎文案与 PRD 6.1 逐字一致', () {
    final strings = AppStrings(const Locale('zh'));
    _zhCopy.forEach((key, value) {
      expect(strings.t(key), value, reason: key);
    });
  });

  test('英文 9 条欢迎文案与 PRD 6.2 逐字一致', () {
    final strings = AppStrings(const Locale('en'));
    _enCopy.forEach((key, value) {
      expect(strings.t(key), value, reason: key);
    });
  });

  test('英文文案不含中日韩字符', () {
    final cjk = RegExp(r'[\u3400-\u9fff]');
    _enCopy.forEach((key, value) {
      expect(cjk.hasMatch(value), isFalse, reason: key);
    });
  });

  test('中文文案不混入英文句子（品牌与技术词除外）', () {
    const allowed = ['DoDroidAI', 'Wi-Fi', 'AI'];
    _zhCopy.forEach((key, value) {
      var text = value;
      for (final word in allowed) {
        text = text.replaceAll(word, '');
      }
      expect(RegExp(r'[A-Za-z]').hasMatch(text), isFalse, reason: key);
    });
  });

  test('非中英语言回退中文', () {
    final strings = AppStrings(const Locale('fr'));
    expect(strings.t('welcomeTitle'), _zhCopy['welcomeTitle']);
    expect(strings.t('welcomeStart'), _zhCopy['welcomeStart']);
  });

  test('每个欢迎 key 在中英两边都有值', () {
    final zh = AppStrings(const Locale('zh'));
    final en = AppStrings(const Locale('en'));
    for (final key in _zhCopy.keys) {
      expect(zh.t(key), isNot(key));
      expect(en.t(key), isNot(key));
    }
  });
}

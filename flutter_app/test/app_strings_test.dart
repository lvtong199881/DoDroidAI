import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/l10n/app_strings.dart';

void main() {
  test('zh strings', () {
    final zh = AppStrings(const Locale('zh'));
    expect(zh.newChat, '新对话');
    expect(zh.t('notes'), '笔记');
    expect(zh.emptyHint, '发送消息开始对话');
  });

  test('en strings', () {
    final en = AppStrings(const Locale('en'));
    expect(en.newChat, 'New chat');
    expect(en.t('notes'), 'Notes');
  });

  test('unknown locale falls back to zh', () {
    final unknown = AppStrings(const Locale('fr'));
    expect(unknown.newChat, '新对话');
  });

  test('welcomeConfigureAi：中英定稿，其他语言回退中文', () {
    expect(AppStrings(const Locale('zh')).t('welcomeConfigureAi'), '去配置AI');
    expect(AppStrings(const Locale('en')).t('welcomeConfigureAi'), 'Set up AI');
    expect(AppStrings(const Locale('fr')).t('welcomeConfigureAi'), '去配置AI');
  });

  test('welcomeClose：中英定稿，其他语言回退中文', () {
    expect(AppStrings(const Locale('zh')).t('welcomeClose'), '关闭');
    expect(AppStrings(const Locale('en')).t('welcomeClose'), 'Close');
    expect(AppStrings(const Locale('fr')).t('welcomeClose'), '关闭');
  });
}

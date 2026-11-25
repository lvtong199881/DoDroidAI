import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/ai/ai_config.dart';
import 'package:dodroidai/settings/welcome_ai_gate.dart';

AiConfig buildConfig({
  String baseUrl = 'https://api.deepseek.com/anthropic',
  String apiKey = 'sk-placeholder-not-real',
  String mainModel = 'DeepSeek-V4-Flash',
}) {
  return AiConfig(
    id: 'probe',
    provider: AiProvider.deepseek,
    apiFormat: ApiFormat.anthropicMessages,
    providerName: 'DeepSeek',
    baseUrl: baseUrl,
    apiKey: apiKey,
    mainModel: mainModel,
  );
}

void main() {
  test('无激活配置：显示「去配置AI」', () async {
    final gate = WelcomeAiGate(loadActive: () async => null);
    expect(await gate.shouldShowConfigureAi(), isTrue);
  });

  test('三字段任一为空：显示「去配置AI」', () async {
    final cases = {
      'baseUrl': buildConfig(baseUrl: ''),
      'apiKey': buildConfig(apiKey: ''),
      'mainModel': buildConfig(mainModel: ''),
    };
    for (final entry in cases.entries) {
      final gate = WelcomeAiGate(loadActive: () async => entry.value);
      expect(
        await gate.shouldShowConfigureAi(),
        isTrue,
        reason: '缺 ${entry.key} 时应视为未配置',
      );
    }
  });

  test('全空白字段等价为空：显示「去配置AI」', () async {
    final blanks = ['   ', '\n\t', ' \r\n '];
    for (final blank in blanks) {
      for (final config in [
        buildConfig(baseUrl: blank),
        buildConfig(apiKey: blank),
        buildConfig(mainModel: blank),
      ]) {
        final gate = WelcomeAiGate(loadActive: () async => config);
        expect(await gate.shouldShowConfigureAi(), isTrue, reason: '$config');
      }
    }
  });

  test('三字段完整（含首尾空格）：不显示「去配置AI」', () async {
    final gate = WelcomeAiGate(
      loadActive: () async => buildConfig(
        baseUrl: '  https://api.deepseek.com/anthropic  ',
        apiKey: ' sk-placeholder-not-real ',
        mainModel: ' DeepSeek-V4-Flash ',
      ),
    );
    expect(await gate.shouldShowConfigureAi(), isFalse);
  });

  test('读取异常：按未配置处理且不向调用方抛', () async {
    for (final error in <Object>[
      StateError('json 损坏'),
      const FileSystemException('存储不可用'),
      Exception('unknown'),
    ]) {
      final gate = WelcomeAiGate(loadActive: () async => throw error);
      expect(
        await gate.shouldShowConfigureAi(),
        isTrue,
        reason: error.runtimeType.toString(),
      );
    }
  });

  test('每次判定只读取一次激活配置', () async {
    var calls = 0;
    final gate = WelcomeAiGate(loadActive: () async {
      calls++;
      return null;
    });

    expect(await gate.shouldShowConfigureAi(), isTrue);
    expect(calls, 1);
  });

  test('AiConfig.hasCompleteFields 按 trim 判定，且不改 isConfigured', () {
    final blankKey = buildConfig(apiKey: '   ');
    expect(blankKey.hasCompleteFields, isFalse);
    // 既有聊天发送口径不受影响
    expect(blankKey.isConfigured, isTrue);

    final complete = buildConfig();
    expect(complete.hasCompleteFields, isTrue);
    expect(complete.isConfigured, isTrue);
  });
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum AiProvider { openai, deepseek, minimax, opencode, custom }

enum ApiFormat { anthropicMessages, openAiChatCompletions }

class AiConfig {
  AiConfig({
    required this.id,
    required this.provider,
    required this.apiFormat,
    required this.providerName,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String id;
  final AiProvider provider;
  final ApiFormat apiFormat;
  final String providerName;
  final String baseUrl;
  final String apiKey;
  final String model;

  bool get isConfigured =>
      baseUrl.isNotEmpty && apiKey.isNotEmpty && model.isNotEmpty;

  AiConfig copyWith({
    String? providerName,
    String? baseUrl,
    String? apiKey,
    String? model,
    AiProvider? provider,
    ApiFormat? apiFormat,
  }) {
    return AiConfig(
      id: id,
      provider: provider ?? this.provider,
      apiFormat: apiFormat ?? this.apiFormat,
      providerName: providerName ?? this.providerName,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider.name,
        'apiFormat': apiFormat == ApiFormat.anthropicMessages
            ? 'ANTHROPIC_MESSAGES'
            : 'OPENAI_CHAT_COMPLETIONS',
        'providerName': providerName,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
      };

  factory AiConfig.fromJson(Map<String, dynamic> json) {
    final format = (json['apiFormat'] as String?) ?? 'OPENAI_CHAT_COMPLETIONS';
    return AiConfig(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      provider: switch (json['provider'] as String?) {
        'OPENAI' || 'openai' => AiProvider.openai,
        'DEEPSEEK' || 'deepseek' => AiProvider.deepseek,
        'MINIMAX' || 'minimax' => AiProvider.minimax,
        'OPENCODE' || 'opencode' => AiProvider.opencode,
        _ => AiProvider.custom,
      },
      apiFormat: format == 'ANTHROPIC_MESSAGES'
          ? ApiFormat.anthropicMessages
          : ApiFormat.openAiChatCompletions,
      providerName: json['providerName'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? '',
    );
  }

  static AiConfig defaultFor(AiProvider provider) {
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    switch (provider) {
      case AiProvider.openai:
        return AiConfig(
          id: now,
          provider: provider,
          apiFormat: ApiFormat.openAiChatCompletions,
          providerName: 'OpenAI',
          baseUrl: 'https://api.openai.com',
          apiKey: '',
          model: 'gpt-4o',
        );
      case AiProvider.deepseek:
        return AiConfig(
          id: now,
          provider: provider,
          apiFormat: ApiFormat.anthropicMessages,
          providerName: 'DeepSeek',
          baseUrl: 'https://api.deepseek.com/anthropic',
          apiKey: '',
          model: 'DeepSeek-V4-Flash',
        );
      case AiProvider.minimax:
        return AiConfig(
          id: now,
          provider: provider,
          apiFormat: ApiFormat.anthropicMessages,
          providerName: 'MiniMax',
          baseUrl: 'https://api.minimaxi.com/anthropic',
          apiKey: '',
          model: 'MiniMax-M2.7',
        );
      case AiProvider.opencode:
        return AiConfig(
          id: now,
          provider: provider,
          apiFormat: ApiFormat.openAiChatCompletions,
          providerName: 'OpenCode',
          baseUrl: 'https://opencode.ai/zen/go/v1',
          apiKey: 'public',
          model: 'deepseek-v4.1-flash',
        );
      case AiProvider.custom:
        return AiConfig(
          id: now,
          provider: provider,
          apiFormat: ApiFormat.anthropicMessages,
          providerName: '',
          baseUrl: '',
          apiKey: '',
          model: '',
        );
    }
  }
}

/// 多配置持久化：configs(JSON 数组) + activeConfigId
class AiConfigStore {
  static const _kConfigs = 'ai_configs';
  static const _kActiveId = 'ai_active_config_id';
  // 旧单配置键
  static const _kBaseUrl = 'ai_base_url';
  static const _kApiKey = 'ai_api_key';
  static const _kModel = 'ai_model';

  Future<List<AiConfig>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kConfigs);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map((m) => AiConfig.fromJson(m))
              .toList();
        }
      } catch (_) {
        // ignore corrupt json
      }
    }
    // 迁移旧单配置
    final legacyBase = prefs.getString(_kBaseUrl) ?? '';
    final legacyKey = prefs.getString(_kApiKey) ?? '';
    final legacyModel = prefs.getString(_kModel) ?? '';
    if (legacyBase.isNotEmpty || legacyKey.isNotEmpty || legacyModel.isNotEmpty) {
      final migrated = AiConfig(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        provider: AiProvider.custom,
        apiFormat: ApiFormat.openAiChatCompletions,
        providerName: '自定义',
        baseUrl: legacyBase,
        apiKey: legacyKey,
        model: legacyModel,
      );
      await _saveAll([migrated]);
      await prefs.setString(_kActiveId, migrated.id);
      return [migrated];
    }
    return const [];
  }

  Future<AiConfig?> loadActive() async {
    final prefs = await SharedPreferences.getInstance();
    final configs = await loadAll();
    if (configs.isEmpty) return null;
    final activeId = prefs.getString(_kActiveId);
    if (activeId == null) return configs.first;
    return configs.firstWhere(
      (c) => c.id == activeId,
      orElse: () => configs.first,
    );
  }

  Future<void> saveActive(AiConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final configs = await loadAll();
    final index = configs.indexWhere((c) => c.id == config.id);
    if (index >= 0) {
      configs[index] = config;
    } else {
      configs.add(config);
    }
    await _saveAll(configs);
    await prefs.setString(_kActiveId, config.id);
  }

  Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final configs = await loadAll();
    configs.removeWhere((c) => c.id == id);
    await _saveAll(configs);
    final activeId = prefs.getString(_kActiveId);
    if (activeId == id) {
      if (configs.isNotEmpty) {
        await prefs.setString(_kActiveId, configs.first.id);
      } else {
        await prefs.remove(_kActiveId);
      }
    }
  }

  Future<void> setActive(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveId, id);
  }

  Future<void> _saveAll(List<AiConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kConfigs,
      jsonEncode(configs.map((c) => c.toJson()).toList()),
    );
  }
}

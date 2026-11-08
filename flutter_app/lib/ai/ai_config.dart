import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum AiProvider { openai, deepseek, minimax, opencode, custom }

enum ApiFormat { anthropicMessages, openAiChatCompletions }

/// AI 配置（字段对齐原生 AIConfig.kt）
class AiConfig {
  AiConfig({
    required this.id,
    required this.provider,
    required this.apiFormat,
    required this.providerName,
    this.description = '',
    this.officialUrl = '',
    required this.baseUrl,
    required this.apiKey,
    required this.mainModel,
    this.haikuModel = '',
    this.sonnetModel = '',
    this.opusModel = '',
    this.supportsVision = true,
    this.contextWindow = 200000,
  });

  final String id;
  final AiProvider provider;
  final ApiFormat apiFormat;
  final String providerName;
  final String description;
  final String officialUrl;
  final String baseUrl;
  final String apiKey;
  final String mainModel;
  final String haikuModel;
  final String sonnetModel;
  final String opusModel;
  final bool supportsVision;

  /// 模型上下文窗口（token），用于判断何时压缩历史
  final int contextWindow;

  /// 请求实际使用的模型
  String get model => mainModel;

  bool get isConfigured =>
      baseUrl.isNotEmpty && apiKey.isNotEmpty && mainModel.isNotEmpty;

  /// 原生 AIConfig.isValid：只需 key 与模型
  bool get isValid => apiKey.isNotBlankSafe() && mainModel.isNotBlankSafe();

  AiConfig copyWith({
    String? providerName,
    String? description,
    String? officialUrl,
    String? baseUrl,
    String? apiKey,
    String? mainModel,
    String? haikuModel,
    String? sonnetModel,
    String? opusModel,
    AiProvider? provider,
    ApiFormat? apiFormat,
    bool? supportsVision,
    int? contextWindow,
  }) {
    return AiConfig(
      id: id,
      provider: provider ?? this.provider,
      apiFormat: apiFormat ?? this.apiFormat,
      providerName: providerName ?? this.providerName,
      description: description ?? this.description,
      officialUrl: officialUrl ?? this.officialUrl,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      mainModel: mainModel ?? this.mainModel,
      haikuModel: haikuModel ?? this.haikuModel,
      sonnetModel: sonnetModel ?? this.sonnetModel,
      opusModel: opusModel ?? this.opusModel,
      supportsVision: supportsVision ?? this.supportsVision,
      contextWindow: contextWindow ?? this.contextWindow,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider': provider.name,
        'apiFormat': apiFormat == ApiFormat.anthropicMessages
            ? 'ANTHROPIC_MESSAGES'
            : 'OPENAI_CHAT_COMPLETIONS',
        'providerName': providerName,
        'description': description,
        'officialUrl': officialUrl,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'mainModel': mainModel,
        'haikuModel': haikuModel,
        'sonnetModel': sonnetModel,
        'opusModel': opusModel,
        'supportsVision': supportsVision,
        'contextWindow': contextWindow,
      };

  factory AiConfig.fromJson(Map<String, dynamic> json) {
    final format = (json['apiFormat'] as String?) ?? 'OPENAI_CHAT_COMPLETIONS';
    return AiConfig(
      id: json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
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
      description: json['description'] as String? ?? '',
      officialUrl: json['officialUrl'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      mainModel:
          (json['mainModel'] as String?) ?? (json['model'] as String?) ?? '',
      haikuModel: json['haikuModel'] as String? ?? '',
      sonnetModel: json['sonnetModel'] as String? ?? '',
      opusModel: json['opusModel'] as String? ?? '',
      supportsVision: (json['supportsVision'] as bool?) ?? true,
      contextWindow: (json['contextWindow'] as num?)?.toInt() ?? 200000,
    );
  }

  /// 与原生 AIConfig.default(provider) 一致
  static AiConfig defaultFor(AiProvider provider) {
    final now = DateTime.now().microsecondsSinceEpoch.toString();
    switch (provider) {
      case AiProvider.openai:
        return AiConfig(
          id: now,
          provider: provider,
          apiFormat: ApiFormat.openAiChatCompletions,
          providerName: 'OpenAI',
          officialUrl: 'https://openai.com',
          baseUrl: 'https://api.openai.com',
          apiKey: '',
          mainModel: 'gpt-4o',
          haikuModel: 'gpt-4o',
          sonnetModel: 'gpt-4o',
          opusModel: 'gpt-4o',
        );
      case AiProvider.deepseek:
        return AiConfig(
          id: now,
          provider: provider,
          apiFormat: ApiFormat.anthropicMessages,
          providerName: 'DeepSeek',
          officialUrl: 'https://platform.deepseek.com',
          baseUrl: 'https://api.deepseek.com/anthropic',
          apiKey: '',
          mainModel: 'DeepSeek-V4-Flash',
          haikuModel: 'DeepSeek-V4-Flash',
          sonnetModel: 'DeepSeek-V4-Flash',
          opusModel: 'DeepSeek-V4-Flash',
        );
      case AiProvider.minimax:
        return AiConfig(
          id: now,
          provider: provider,
          apiFormat: ApiFormat.anthropicMessages,
          providerName: 'MiniMax',
          officialUrl: 'https://platform.minimaxi.com',
          baseUrl: 'https://api.minimaxi.com/anthropic',
          apiKey: '',
          mainModel: 'MiniMax-M2.7',
          haikuModel: 'MiniMax-M2.7',
          sonnetModel: 'MiniMax-M2.7',
          opusModel: 'MiniMax-M2.7',
        );
      case AiProvider.opencode:
        return AiConfig(
          id: now,
          provider: provider,
          apiFormat: ApiFormat.openAiChatCompletions,
          providerName: 'OpenCode Go',
          officialUrl: 'https://opencode.ai',
          baseUrl: 'https://opencode.ai/zen/go/v1',
          apiKey: '',
          mainModel: 'deepseek-v4.1-flash',
          haikuModel: 'deepseek-v4.1-flash',
          sonnetModel: 'deepseek-v4.1-flash',
          opusModel: 'deepseek-v4.1-flash',
        );
      case AiProvider.custom:
        return AiConfig(
          id: now,
          provider: provider,
          apiFormat: ApiFormat.anthropicMessages,
          providerName: '',
          baseUrl: '',
          apiKey: '',
          mainModel: '',
        );
    }
  }
}

extension on String {
  bool isNotBlankSafe() => trim().isNotEmpty;
}

/// 多配置持久化：configs(JSON 数组) + activeConfigId
class AiConfigStore {
  static const _kConfigs = 'ai_configs';
  static const _kActiveId = 'ai_active_config_id';
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
        mainModel: legacyModel,
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

  Future<void> setActive(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveId, id);
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

  Future<void> _saveAll(List<AiConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kConfigs,
      jsonEncode(configs.map((c) => c.toJson()).toList()),
    );
  }
}

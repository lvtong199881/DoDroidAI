import 'package:shared_preferences/shared_preferences.dart';

class AiConfig {
  AiConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  final String baseUrl;
  final String apiKey;
  final String model;

  static const String defaultBaseUrl = 'https://api.openai.com/v1';
  static const String defaultModel = 'gpt-4o-mini';

  bool get isConfigured => baseUrl.isNotEmpty && apiKey.isNotEmpty && model.isNotEmpty;
}

class AiConfigStore {
  static const _kBaseUrl = 'ai_base_url';
  static const _kApiKey = 'ai_api_key';
  static const _kModel = 'ai_model';

  Future<AiConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AiConfig(
      baseUrl: prefs.getString(_kBaseUrl) ?? '',
      apiKey: prefs.getString(_kApiKey) ?? '',
      model: prefs.getString(_kModel) ?? '',
    );
  }

  Future<void> save(AiConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, config.baseUrl.trim());
    await prefs.setString(_kApiKey, config.apiKey.trim());
    await prefs.setString(_kModel, config.model.trim());
  }
}

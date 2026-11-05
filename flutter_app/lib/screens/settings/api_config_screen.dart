import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_config.dart';
import '../../l10n/app_strings.dart';
import '../../widgets/app_toast.dart';
import '../chat/chat_provider.dart';

class ApiConfigScreen extends ConsumerStatefulWidget {
  const ApiConfigScreen({super.key, this.config});

  final AiConfig? config;

  @override
  ConsumerState<ApiConfigScreen> createState() => _ApiConfigScreenState();
}

class _ApiConfigScreenState extends ConsumerState<ApiConfigScreen> {
  late final TextEditingController _providerNameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  AiProvider _provider = AiProvider.custom;
  ApiFormat _apiFormat = ApiFormat.anthropicMessages;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final config = widget.config;
    _provider = config?.provider ?? AiProvider.custom;
    _apiFormat = config?.apiFormat ?? ApiFormat.anthropicMessages;
    _providerNameController = TextEditingController(text: config?.providerName ?? '');
    _baseUrlController = TextEditingController(text: config?.baseUrl ?? '');
    _apiKeyController = TextEditingController(text: config?.apiKey ?? '');
    _modelController = TextEditingController(text: config?.model ?? '');
  }

  @override
  void dispose() {
    _providerNameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _applyPreset(AiProvider provider) {
    final preset = AiConfig.defaultFor(provider);
    setState(() {
      _provider = provider;
      _apiFormat = preset.apiFormat;
      _providerNameController.text = preset.providerName;
      _baseUrlController.text = preset.baseUrl;
      _modelController.text = preset.model;
      if (widget.config == null) {
        _apiKeyController.clear();
      }
    });
  }

  Future<void> _save() async {
    final strings = AppStrings.of(context);
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    final model = _modelController.text.trim();
    if (baseUrl.isEmpty || apiKey.isEmpty || model.isEmpty) {
      showToast(context, '请填写 Base URL、API Key 和 Model');
      return;
    }
    final config = (widget.config ?? AiConfig.defaultFor(_provider)).copyWith(
      provider: _provider,
      apiFormat: _apiFormat,
      providerName: _providerNameController.text.trim(),
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
    );
    await AiConfigStore().saveActive(config);
    ref.read(chatProvider.notifier).reloadConfig();
    if (!mounted) return;
    showToast(context, strings.save);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(strings.apiConfig, style: const TextStyle(fontSize: 20)),
        actions: [
          TextButton(onPressed: _save, child: Text(strings.save)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('服务商', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in const [
                (AiProvider.openai, 'OpenAI'),
                (AiProvider.deepseek, 'DeepSeek'),
                (AiProvider.minimax, 'MiniMax'),
                (AiProvider.custom, '自定义'),
              ])
                ChoiceChip(
                  label: Text(entry.$2),
                  selected: _provider == entry.$1,
                  onSelected: (_) => _applyPreset(entry.$1),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _providerNameController,
            decoration: const InputDecoration(labelText: '配置名称'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ApiFormat>(
            value: _apiFormat,
            decoration: const InputDecoration(labelText: 'API 格式'),
            items: const [
              DropdownMenuItem(
                value: ApiFormat.anthropicMessages,
                child: Text('Anthropic Messages'),
              ),
              DropdownMenuItem(
                value: ApiFormat.openAiChatCompletions,
                child: Text('OpenAI Chat Completions'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _apiFormat = value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'https://api.example.com',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: 'API Key',
              suffixIcon: IconButton(
                icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(labelText: 'Model'),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(strings.save)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_config.dart';
import '../../ai/chat_api.dart';
import '../../l10n/app_strings.dart';
import '../../widgets/app_toast.dart';
import '../chat/chat_provider.dart';

/// API 配置页（对齐原生 fragment_ai_config.xml）
class ApiConfigScreen extends ConsumerStatefulWidget {
  const ApiConfigScreen({super.key, this.config});

  final AiConfig? config;

  @override
  ConsumerState<ApiConfigScreen> createState() => _ApiConfigScreenState();
}

class _ApiConfigScreenState extends ConsumerState<ApiConfigScreen> {
  late final TextEditingController _providerNameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _officialUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _mainModelController;
  List<String> _availableModels = const [];
  bool _loadingModels = false;
  String? _modelError;
  late final TextEditingController _haikuModelController;
  late final TextEditingController _sonnetModelController;
  late final TextEditingController _opusModelController;

  AiProvider _provider = AiProvider.custom;
  ApiFormat _apiFormat = ApiFormat.anthropicMessages;
  bool _supportsVision = true;
  bool _obscureKey = true;

  bool get _isEditing => widget.config != null;

  @override
  void initState() {
    super.initState();
    final config = widget.config;
    _provider = config?.provider ?? AiProvider.custom;
    _apiFormat = config?.apiFormat ?? ApiFormat.anthropicMessages;
    _supportsVision = config?.supportsVision ?? true;
    _providerNameController =
        TextEditingController(text: config?.providerName ?? '');
    _descriptionController =
        TextEditingController(text: config?.description ?? '');
    _officialUrlController =
        TextEditingController(text: config?.officialUrl ?? '');
    _apiKeyController = TextEditingController(text: config?.apiKey ?? '');
    _baseUrlController = TextEditingController(text: config?.baseUrl ?? '');
    _mainModelController = TextEditingController(text: config?.mainModel ?? '');
    _haikuModelController =
        TextEditingController(text: config?.haikuModel ?? '');
    _sonnetModelController =
        TextEditingController(text: config?.sonnetModel ?? '');
    _opusModelController = TextEditingController(text: config?.opusModel ?? '');
  }

  @override
  void dispose() {
    _providerNameController.dispose();
    _descriptionController.dispose();
    _officialUrlController.dispose();
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _mainModelController.dispose();
    _haikuModelController.dispose();
    _sonnetModelController.dispose();
    _opusModelController.dispose();
    super.dispose();
  }

  /// 对齐原生 applyDefaultConfig：清空后套用预设
  void _applyPreset(AiProvider provider) {
    final preset = AiConfig.defaultFor(provider);
    setState(() {
      _provider = provider;
      _apiFormat = preset.apiFormat;
      _supportsVision = preset.supportsVision;
      _providerNameController.text = preset.providerName;
      _descriptionController.text = preset.description;
      _officialUrlController.text = preset.officialUrl;
      _apiKeyController.text = preset.apiKey;
      _baseUrlController.text = preset.baseUrl;
      _mainModelController.text = preset.mainModel;
      _haikuModelController.text = preset.haikuModel;
      _sonnetModelController.text = preset.sonnetModel;
      _opusModelController.text = preset.opusModel;
    });
  }

  /// 调用 {base}/v1/models 拉取可用模型
  Future<void> _fetchModels() async {
    debugPrint('FETCH_MODELS tapped');
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    if (baseUrl.isEmpty || apiKey.isEmpty) {
      setState(() => _modelError = '请先填写 Base URL 和 API Key');
      return;
    }
    setState(() {
      _loadingModels = true;
      _modelError = null;
    });
    try {
      final probe = AiConfig(
        id: widget.config?.id ?? 'probe',
        provider: _provider,
        apiFormat: _apiFormat,
        providerName: _providerNameController.text,
        description: '',
        officialUrl: '',
        baseUrl: baseUrl,
        apiKey: apiKey,
        mainModel: '',
        haikuModel: '',
        sonnetModel: '',
        opusModel: '',
        supportsVision: false,
      );
      final models = await ChatApi().fetchModels(probe);
      if (!mounted) return;
      setState(() {
        _availableModels = models;
        _modelError = models.isEmpty ? '接口未返回模型' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _modelError = '获取失败：${e.toString().split('\n').first}');
    } finally {
      if (mounted) setState(() => _loadingModels = false);
    }
  }

  Future<void> _save() async {
    final strings = AppStrings.of(context);
    final mainModel = _mainModelController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    if (mainModel.isEmpty || apiKey.isEmpty) {
      showToast(context, '请填写 API 密钥与主模型');
      return;
    }
    final config = (widget.config ?? AiConfig.defaultFor(_provider)).copyWith(
      provider: _provider,
      apiFormat: _apiFormat,
      providerName: _providerNameController.text.trim(),
      description: _descriptionController.text.trim(),
      officialUrl: _officialUrlController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      apiKey: apiKey,
      mainModel: mainModel,
      haikuModel: _haikuModelController.text.trim(),
      sonnetModel: _sonnetModelController.text.trim(),
      opusModel: _opusModelController.text.trim(),
      supportsVision: _supportsVision,
    );
    await AiConfigStore().saveActive(config);
    ref.read(chatProvider.notifier).reloadConfig();
    if (!mounted) return;
    showToast(context, strings.save);
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final config = widget.config;
    if (config == null) return;
    await AiConfigStore().remove(config.id);
    ref.read(chatProvider.notifier).reloadConfig();
    if (!mounted) return;
    showToast(context, '已删除');
    Navigator.of(context).pop(true);
  }

  Future<void> _setActive() async {
    final config = widget.config;
    if (config == null) return;
    await AiConfigStore().setActive(config.id);
    ref.read(chatProvider.notifier).reloadConfig();
    if (!mounted) return;
    showToast(context, '已设为激活');
  }

  Widget _groupTitle(String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 32, top: 24, right: 16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: scheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    int maxLines = 1,
    bool withPasswordToggle = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        maxLines: obscure ? 1 : maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
          suffixIcon: withPasswordToggle
              ? IconButton(
                  icon: Icon(
                    _obscureKey ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                )
              : null,
        ),
      ),
    );
  }

  /// 快捷供应商卡片（原生 cardOpenAI/cardDeepSeek/cardMiniMax 同款：等宽、圆角 12、描边）
  Widget _providerCard(String label, AiProvider provider) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _provider == provider;
    return Expanded(
      child: GestureDetector(
        onTap: () => _applyPreset(provider),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outline,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEditing ? '编辑配置' : '新建配置',
          style: const TextStyle(fontSize: 20),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              children: [
                // 快捷供应商
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _providerCard('OpenAI', AiProvider.openai),
                      const SizedBox(width: 8),
                      _providerCard('DeepSeek', AiProvider.deepseek),
                      const SizedBox(width: 8),
                      _providerCard('MiniMax', AiProvider.minimax),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _providerCard('OpenCode', AiProvider.opencode),
                      const SizedBox(width: 8),
                      _providerCard('自定义', AiProvider.custom),
                      const SizedBox(width: 8),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                ),

                // 基本信息
                _groupTitle('基本信息'),
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                  child: TextField(
                    controller: _providerNameController,
                    decoration: const InputDecoration(
                      hintText: '供应商名称',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                _field(
                  controller: _descriptionController,
                  hint: '备注（选填）',
                  maxLines: 3,
                ),
                _field(
                  controller: _officialUrlController,
                  hint: '官网链接（选填）',
                  keyboardType: TextInputType.url,
                ),

                // API 配置
                _groupTitle('API 配置'),
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                  child: TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      hintText: 'API 密钥',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureKey ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),
                ),
                _field(
                  controller: _baseUrlController,
                  hint: '接口地址',
                  keyboardType: TextInputType.url,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
                  child: DropdownButtonFormField<ApiFormat>(
                    key: ValueKey(_apiFormat),
                    initialValue: _apiFormat,
                    decoration: const InputDecoration(
                      hintText: 'API 格式',
                      border: OutlineInputBorder(),
                    ),
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
                ),

                // 模型配置
                _groupTitle('模型配置'),
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownMenu<String>(
                          controller: _mainModelController,
                          hintText: '主模型',
                          width: double.infinity,
                          requestFocusOnTap: true,
                          menuHeight: 320,
                          enableFilter: true,
                          inputDecorationTheme: const InputDecorationTheme(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          dropdownMenuEntries: _availableModels
                              .map((m) => DropdownMenuEntry(value: m, label: m))
                              .toList(),
                          onSelected: (value) {
                            if (value != null) {
                              _mainModelController.text = value;
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: IconButton.filledTonal(
                          tooltip: '获取模型列表',
                          onPressed: _loadingModels ? null : _fetchModels,
                          icon: _loadingModels
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_modelError != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 6),
                    child: Text(
                      _modelError!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                _field(controller: _haikuModelController, hint: 'Haiku 默认模型'),
                _field(controller: _sonnetModelController, hint: 'Sonnet 默认模型'),
                _field(controller: _opusModelController, hint: 'Opus 默认模型'),
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 16, top: 16),
                  child: SwitchListTile(
                    value: _supportsVision,
                    onChanged: (v) => setState(() => _supportsVision = v),
                    title: const Text('支持图片输入'),
                  ),
                ),
              ],
            ),
          ),

          // 底部固定按钮栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                if (_isEditing)
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _delete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error),
                      ),
                      child: const Text('删除'),
                    ),
                  ),
                if (_isEditing) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: FilledButton.tonal(
                      onPressed: _setActive,
                      child: const Text('设为激活'),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  flex: _isEditing ? 1 : 2,
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(strings.save),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

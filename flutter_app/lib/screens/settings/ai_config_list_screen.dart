import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_config.dart';
import '../../widgets/app_toast.dart';
import '../chat/chat_provider.dart';
import 'api_config_screen.dart';

/// AI 配置列表（对齐原生 AIConfigListFragment：多配置、激活、克隆、删除）
class AiConfigListScreen extends ConsumerStatefulWidget {
  const AiConfigListScreen({super.key});

  @override
  ConsumerState<AiConfigListScreen> createState() => _AiConfigListScreenState();
}

class _AiConfigListScreenState extends ConsumerState<AiConfigListScreen> {
  List<AiConfig> _configs = const [];
  String? _activeId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final configs = await AiConfigStore().loadAll();
    final active = await AiConfigStore().loadActive();
    if (!mounted) return;
    setState(() {
      _configs = configs;
      _activeId = active?.id;
      _loading = false;
    });
  }

  Future<void> _openEditor([AiConfig? config]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ApiConfigScreen(config: config)),
    );
    ref.read(chatProvider.notifier).reloadConfig();
    await _load();
  }

  Future<void> _setActive(AiConfig config) async {
    await AiConfigStore().setActive(config.id);
    ref.read(chatProvider.notifier).reloadConfig();
    await _load();
    if (mounted) showToast(context, '已设为激活');
  }

  Future<void> _clone(AiConfig config) async {
    final copy = AiConfig(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      provider: config.provider,
      apiFormat: config.apiFormat,
      providerName: '${config.providerName} 副本',
      description: config.description,
      officialUrl: config.officialUrl,
      baseUrl: config.baseUrl,
      apiKey: config.apiKey,
      mainModel: config.mainModel,
      haikuModel: config.haikuModel,
      sonnetModel: config.sonnetModel,
      opusModel: config.opusModel,
      supportsVision: config.supportsVision,
    );
    await AiConfigStore().saveActive(copy);
    await _load();
    if (mounted) showToast(context, '已复制配置');
  }

  Future<void> _delete(AiConfig config) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除配置'),
        content: Text('确定删除「${config.providerName}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await AiConfigStore().remove(config.id);
    await _load();
    if (mounted) showToast(context, '已删除');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('AI 配置', style: TextStyle(fontSize: 20)),
        actions: [
          IconButton(
            tooltip: '新建配置',
            icon: const Icon(Icons.add),
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _configs.isEmpty
              ? Center(
                  child: Text(
                    '暂无配置，点右上角 + 新建',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _configs.length,
                  itemBuilder: (context, index) {
                    final config = _configs[index];
                    final active = config.id == _activeId;
                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  config.providerName.isEmpty
                                      ? '未命名配置'
                                      : config.providerName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (active)
                                Text(
                                  '激活',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: scheme.primary,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${config.mainModel.isEmpty ? '未设置模型' : config.mainModel} · ${config.baseUrl}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _clone(config),
                                child: const Text('复制'),
                              ),
                              TextButton(
                                onPressed: () => _delete(config),
                                child: Text(
                                  '删除',
                                  style: TextStyle(color: scheme.error),
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (!active)
                                FilledButton.tonal(
                                  onPressed: () => _setActive(config),
                                  child: const Text('使用'),
                                ),
                              if (active)
                                FilledButton.tonal(
                                  onPressed: () => _openEditor(config),
                                  child: const Text('编辑'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ai/ai_config.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  AiConfig? _config;
  bool _ttsModel = false;
  bool _asrModel = false;
  String _braveKey = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await AiConfigStore().loadActive();
    final dir = await getApplicationSupportDirectory();
    final tts = File('${dir.path}/tts_models/vits_melo_tts_zh_en/model.int8.onnx').existsSync();
    final asr = File('${dir.path}/stt_models/sense_voice_2025_09_09/model.int8.onnx').existsSync();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _config = config;
      _ttsModel = tts;
      _asrModel = asr;
      _braveKey = prefs.getString('brave_search_api_key') ?? '';
      _loading = false;
    });
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Color(0xFF5B6270)))),
          Expanded(child: Text(value, style: TextStyle(color: color))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final okColor = const Color(0xFF1E8E5A);
    final badColor = scheme.error;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('诊断', style: TextStyle(fontSize: 20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('API 配置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                _row('服务商', _config?.providerName.isNotEmpty == true ? _config!.providerName : '未配置'),
                _row('协议', _config?.apiFormat == ApiFormat.anthropicMessages ? 'Anthropic Messages' : 'OpenAI Chat Completions'),
                _row('Base URL', _config?.baseUrl.isNotEmpty == true ? _config!.baseUrl : '未配置'),
                _row('模型', _config?.model.isNotEmpty == true ? _config!.model : '未配置', color: _config?.model.isNotEmpty == true ? okColor : badColor),
                _row('API Key', (_config?.apiKey.isNotEmpty ?? false) ? '已配置' : '未配置', color: (_config?.apiKey.isNotEmpty ?? false) ? okColor : badColor),
                const SizedBox(height: 16),
                const Text('本地模型', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                _row('语音输出模型', _ttsModel ? '已下载' : '未下载', color: _ttsModel ? okColor : badColor),
                _row('语音输入模型', _asrModel ? '已下载' : '未下载', color: _asrModel ? okColor : badColor),
                const SizedBox(height: 16),
                const Text('工具', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                _row('联网搜索 Key', _braveKey.isNotEmpty ? '已配置' : '未配置', color: _braveKey.isNotEmpty ? okColor : badColor),
              ],
            ),
    );
  }
}

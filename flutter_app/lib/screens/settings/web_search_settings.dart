import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/app_toast.dart';

class WebSearchSettingsScreen extends StatefulWidget {
  const WebSearchSettingsScreen({super.key});

  @override
  State<WebSearchSettingsScreen> createState() =>
      _WebSearchSettingsScreenState();
}

class _WebSearchSettingsScreenState extends State<WebSearchSettingsScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _controller.text = prefs.getString('brave_search_api_key') ?? '');
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('brave_search_api_key', _controller.text.trim());
    if (!mounted) return;
    showToast(context, '已保存');
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('联网搜索', style: TextStyle(fontSize: 20)),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '使用 Brave Search API，可在 brave.com/search/api 申请 Key。',
            style: TextStyle(fontSize: 13, color: Color(0xFF5B6270)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Brave Search API Key',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

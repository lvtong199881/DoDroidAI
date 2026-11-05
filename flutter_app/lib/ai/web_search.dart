import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Brave Search API（与原生 WebSearchTool 一致）
class WebSearch {
  static const String _keyName = 'brave_search_api_key';

  static Future<String> search(String query, {int count = 5}) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(_keyName) ?? '';
    if (apiKey.trim().isEmpty) {
      return '请先在设置 → 联网搜索中配置 Brave Search API Key';
    }
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ));
      final response = await dio.get<Map<String, dynamic>>(
        'https://api.search.brave.com/res/v1/web/search',
        queryParameters: {'q': query, 'count': count},
        options: Options(headers: {
          'X-Subscription-Token': apiKey.trim(),
          'Accept': 'application/json',
        }),
      );
      final data = response.data;
      if (data == null) return '搜索无结果';
      final results = data['web']?['results'];
      if (results is! List || results.isEmpty) return '搜索无结果';
      final buffer = StringBuffer();
      for (final item in results.take(count)) {
        final title = item['title'] ?? '';
        final url = item['url'] ?? '';
        final description = item['description'] ?? '';
        buffer.writeln('$title\n$url\n$description\n');
      }
      return buffer.toString().trim();
    } catch (e) {
      return '搜索失败: $e';
    }
  }
}

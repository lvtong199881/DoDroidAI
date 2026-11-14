import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 单条搜索结果
class SearchHit {
  const SearchHit({
    required this.title,
    required this.url,
    required this.snippet,
  });

  final String title;
  final String url;
  final String snippet;
}

/// 单个查询的结果：失败时 [hits] 为空、[error] 非空
class QuerySearchResult {
  const QuerySearchResult({
    required this.query,
    this.hits = const [],
    this.error,
  });

  final String query;
  final List<SearchHit> hits;
  final String? error;
}

/// Brave Search API（与原生 WebSearchTool 一致）
///
/// 支持一次提交多个查询：串行请求（免费版约 1 QPS）、URL 去重、
/// 单个查询失败不影响其他查询。
class WebSearch {
  static const String _keyName = 'brave_search_api_key';
  static const int _maxQueries = 4;
  static const int _maxTotalHits = 20;

  /// 兼容旧调用：单查询
  static Future<String> search(String query, {int count = 5}) =>
      searchMany([query], count: count);

  /// 多查询检索并合并结果
  static Future<String> searchMany(
    List<String> queries, {
    int count = 5,
  }) async {
    final cleaned = <String>[];
    for (final query in queries) {
      final text = query.trim();
      if (text.isEmpty || cleaned.contains(text)) continue;
      cleaned.add(text);
      if (cleaned.length >= _maxQueries) break;
    }
    if (cleaned.isEmpty) return '参数不合法：queries 至少需要一个非空关键词';

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(_keyName) ?? '';
    if (apiKey.trim().isEmpty) {
      return '请先在设置 → 联网搜索中配置 Brave Search API Key';
    }

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ));
    final results = <QuerySearchResult>[];
    for (var i = 0; i < cleaned.length; i++) {
      if (i > 0) {
        // Brave 免费版约 1 QPS，串行之间留间隔，避免 429
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      results.add(await _searchOne(dio, apiKey.trim(), cleaned[i], count));
    }
    return formatResults(results);
  }

  static Future<QuerySearchResult> _searchOne(
    Dio dio,
    String apiKey,
    String query,
    int count,
  ) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        'https://api.search.brave.com/res/v1/web/search',
        queryParameters: {'q': query, 'count': count.clamp(1, 10)},
        options: Options(headers: {
          'X-Subscription-Token': apiKey,
          'Accept': 'application/json',
        }),
      );
      final raw = response.data?['web']?['results'];
      if (raw is! List) {
        return QuerySearchResult(query: query);
      }
      final hits = <SearchHit>[];
      for (final item in raw.take(count)) {
        final url = item['url']?.toString() ?? '';
        if (url.isEmpty) continue;
        hits.add(SearchHit(
          title: item['title']?.toString() ?? '',
          url: url,
          snippet: item['description']?.toString() ?? '',
        ));
      }
      return QuerySearchResult(query: query, hits: hits);
    } catch (e) {
      return QuerySearchResult(query: query, error: _shortError(e));
    }
  }

  /// 纯函数：合并去重并格式化（单查询保持旧格式，多查询按节输出）
  static String formatResults(List<QuerySearchResult> results) {
    if (results.isEmpty) return '搜索无结果';
    if (results.every((r) => r.error == null && r.hits.isEmpty)) {
      return '搜索无结果';
    }

    final seen = <String>{};
    final sections = <String>[];
    var total = 0;
    for (final result in results) {
      if (result.error != null) {
        sections.add('## 查询：${result.query}（查询失败：${result.error}）');
        continue;
      }
      final lines = <String>[];
      for (final hit in result.hits) {
        if (total >= _maxTotalHits) break;
        if (!seen.add(hit.url)) continue;
        total++;
        final meta = hit.snippet.isEmpty ? '' : '\n${hit.snippet}';
        lines.add('${hit.title}\n${hit.url}$meta');
      }
      if (lines.isEmpty) {
        sections.add('## 查询：${result.query}（无结果）');
      } else if (results.length == 1) {
        sections.add(lines.join('\n\n'));
      } else {
        sections.add('## 查询：${result.query}\n${lines.join('\n\n')}');
      }
    }
    return sections.join('\n\n');
  }

  static String _shortError(Object error) {
    final text = error.toString();
    return text.length <= 120 ? text : '${text.substring(0, 120)}…';
  }
}

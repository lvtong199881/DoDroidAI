import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/ai/web_search.dart';

void main() {
  group('WebSearch.formatResults', () {
    test('单查询保持旧格式，不带分节标题', () {
      final text = WebSearch.formatResults(const [
        QuerySearchResult(query: '咖啡机', hits: [
          SearchHit(title: 'A', url: 'https://a.com', snippet: 'sa'),
        ]),
      ]);
      expect(text, contains('A'));
      expect(text, contains('https://a.com'));
      expect(text, contains('sa'));
      expect(text, isNot(contains('## 查询')));
    });

    test('多查询按 query 分节', () {
      final text = WebSearch.formatResults(const [
        QuerySearchResult(query: '甲', hits: [
          SearchHit(title: 'A', url: 'https://a.com', snippet: ''),
        ]),
        QuerySearchResult(query: '乙', hits: [
          SearchHit(title: 'B', url: 'https://b.com', snippet: ''),
        ]),
      ]);
      expect(text, contains('## 查询：甲'));
      expect(text, contains('## 查询：乙'));
      expect(text, contains('https://a.com'));
      expect(text, contains('https://b.com'));
    });

    test('跨查询 URL 去重', () {
      final text = WebSearch.formatResults(const [
        QuerySearchResult(query: '甲', hits: [
          SearchHit(title: 'A', url: 'https://same.com', snippet: ''),
        ]),
        QuerySearchResult(query: '乙', hits: [
          SearchHit(title: 'A2', url: 'https://same.com', snippet: ''),
        ]),
      ]);
      expect('https://same.com'.allMatches(text).length, 1);
    });

    test('单个查询失败只标注，不影响其他查询', () {
      final text = WebSearch.formatResults(const [
        QuerySearchResult(query: '甲', error: 'timeout'),
        QuerySearchResult(query: '乙', hits: [
          SearchHit(title: 'B', url: 'https://b.com', snippet: ''),
        ]),
      ]);
      expect(text, contains('查询失败：timeout'));
      expect(text, contains('https://b.com'));
    });

    test('全部无结果返回搜索无结果', () {
      final text = WebSearch.formatResults(const [
        QuerySearchResult(query: '甲'),
        QuerySearchResult(query: '乙'),
      ]);
      expect(text, '搜索无结果');
    });

    test('总条数上限 20', () {
      final first = List.generate(
        15,
        (i) => SearchHit(title: 'T$i', url: 'https://n$i.com', snippet: ''),
      );
      final second = List.generate(
        15,
        (i) => SearchHit(title: 'U$i', url: 'https://u$i.com', snippet: ''),
      );
      final text = WebSearch.formatResults([
        QuerySearchResult(query: '甲', hits: first),
        QuerySearchResult(query: '乙', hits: second),
      ]);
      expect(text, contains('https://n14.com'));
      expect(text, contains('https://u4.com'));
      expect(text, isNot(contains('https://u5.com')));
    });
  });
}

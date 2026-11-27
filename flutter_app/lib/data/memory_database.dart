import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../ai/text_embedding.dart';

class MemoryFact {
  MemoryFact({
    required this.id,
    required this.content,
    required this.createdAt,
    this.embedding,
  });

  final int id;
  final String content;
  final int createdAt;

  /// 语义向量（懒计算：旧数据在首次检索时补算并回写）
  final List<double>? embedding;

  double score = 0;
}

class MemoryRepository {
  static final MemoryRepository instance = MemoryRepository._();

  MemoryRepository._();

  /// 相似度超过该阈值视为重复记忆，不再新增
  static const double duplicateThreshold = 0.88;

  Database? _db;

  /// 测试钩子：暴露已打开的数据库（仅测试用）
  @visibleForTesting
  Database? get debugDb => _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'memory.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE memory_facts (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'content TEXT, created_at INTEGER, embedding TEXT)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE memory_facts ADD COLUMN embedding TEXT',
          );
        }
      },
    );
    return _db!;
  }

  MemoryFact _fromRow(Map<String, Object?> r) {
    return MemoryFact(
      id: r['id'] as int,
      content: r['content'] as String? ?? '',
      createdAt: r['created_at'] as int? ?? 0,
      embedding: _decodeEmbedding(r['embedding'] as String?),
    );
  }

  static List<double>? _decodeEmbedding(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<num>().map((n) => n.toDouble()).toList();
      }
    } catch (_) {
      // ignore invalid json
    }
    return null;
  }

  static String _encodeEmbedding(List<double> embedding) =>
      jsonEncode(embedding);

  Future<List<MemoryFact>> list() async {
    final db = await _open();
    final rows = await db.query('memory_facts', orderBy: 'created_at DESC');
    return rows.map(_fromRow).toList();
  }

  /// 新增记忆：带语义向量；与现有记忆过于相似时跳过（去重），
  /// 返回实际落库或命中的重复条目。
  Future<MemoryFact> insert(String content) async {
    final db = await _open();
    final embedding = TextEmbedder.instance.encode(content);
    final duplicate = await _findDuplicate(db, embedding);
    if (duplicate != null) return duplicate;
    final id = await db.insert('memory_facts', {
      'content': content,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'embedding': _encodeEmbedding(embedding),
    });
    return MemoryFact(
      id: id,
      content: content,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      embedding: embedding,
    );
  }

  Future<MemoryFact?> _findDuplicate(Database db, List<double> embedding) async {
    final rows = await db.query('memory_facts');
    MemoryFact? best;
    var bestScore = 0.0;
    for (final r in rows) {
      final fact = _fromRow(r);
      var factEmbedding = fact.embedding;
      if (factEmbedding == null) {
        // 旧数据懒回填
        factEmbedding = TextEmbedder.instance.encode(fact.content);
        await db.update(
          'memory_facts',
          {'embedding': _encodeEmbedding(factEmbedding)},
          where: 'id = ?',
          whereArgs: [fact.id],
        );
      }
      final score = TextEmbedder.cosine(embedding, factEmbedding);
      if (score > bestScore) {
        bestScore = score;
        best = fact;
      }
    }
    if (best != null && bestScore >= duplicateThreshold) {
      return MemoryFact(
        id: best.id,
        content: best.content,
        createdAt: best.createdAt,
        embedding: best.embedding,
      )..score = bestScore;
    }
    return null;
  }

  Future<void> delete(int id) async {
    final db = await _open();
    await db.delete('memory_facts', where: 'id = ?', whereArgs: [id]);
  }

  /// 相关性检索：语义相似（余弦）为主、词面重叠兜底，返回按分数降序的
  /// 前 limit 条。旧数据缺向量时在查询里懒回填。
  Future<List<MemoryFact>> searchRelevant(
    String query, {
    int limit = 8,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final db = await _open();
    final rows = await db.query('memory_facts', orderBy: 'created_at DESC');
    final queryEmbedding = TextEmbedder.instance.encode(trimmed);
    final queryFeatures = TextEmbedder.featureCounts(trimmed);
    final results = <MemoryFact>[];
    for (final r in rows) {
      final fact = _fromRow(r);
      var factEmbedding = fact.embedding;
      if (factEmbedding == null) {
        factEmbedding = TextEmbedder.instance.encode(fact.content);
        await db.update(
          'memory_facts',
          {'embedding': _encodeEmbedding(factEmbedding)},
          where: 'id = ?',
          whereArgs: [fact.id],
        );
      }
      final semantic = TextEmbedder.cosine(queryEmbedding, factEmbedding);
      final lexical = _featureOverlap(queryFeatures, fact.content);
      final factWithScore = MemoryFact(
        id: fact.id,
        content: fact.content,
        createdAt: fact.createdAt,
        embedding: factEmbedding,
      )..score = 0.65 * semantic + 0.35 * lexical;
      results.add(factWithScore);
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(limit).toList();
  }

  /// 词面重叠：查询特征与记忆内容的特征 Jaccard
  static double _featureOverlap(
    Map<String, int> queryFeatures,
    String? content,
  ) {
    if (queryFeatures.isEmpty || content == null || content.isEmpty) return 0;
    final contentFeatures = TextEmbedder.featureCounts(content).keys.toSet();
    if (contentFeatures.isEmpty) return 0;
    final queryKeys = queryFeatures.keys.toSet();
    final intersection = queryKeys.intersection(contentFeatures).length;
    final union = queryKeys.union(contentFeatures).length;
    return union == 0 ? 0 : intersection / union;
  }
}

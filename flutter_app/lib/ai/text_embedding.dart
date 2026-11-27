import 'dart:math' as math;

/// 轻量文本嵌入：哈希字符 n-gram（feature hashing）+ 余弦相似度
///
/// 设计取舍：不引入 onnx 推理运行时与预训练模型（应用已内置 ASR/TTS 两套
/// 模型下载，embedding 模型会显著增加体积与启动开销），改用纯 Dart 的
/// hashing trick。对中文短句（用户记忆、偏好类信息）字符 n-gram 已能
/// 覆盖大部分语义相近的改写；接口保持 `encode/cosine` 不变，后续若接入
/// 神经网络 embedding 只需替换实现。
class TextEmbedder {
  const TextEmbedder._();

  /// 嵌入维度。256 维对短文本足够，冲突率低且存储小（约 2KB JSON）
  static const int dimensions = 256;

  static const TextEmbedder instance = TextEmbedder._();

  /// 把文本编码为 L2 归一化的稠密向量
  List<double> encode(String text) {
    final vector = List<double>.filled(dimensions, 0);
    final counts = featureCounts(text);
    if (counts.isEmpty) return vector;
    for (final entry in counts.entries) {
      final index = _hashIndex(entry.key);
      final sign = _hashSign(entry.key);
      // 亚线性词频压制重复特征的支配地位
      vector[index] += sign * (1 + math.log(entry.value) / math.ln2);
    }
    var norm = 0.0;
    for (final v in vector) {
      norm += v * v;
    }
    norm = math.sqrt(norm);
    if (norm <= 0) return vector;
    for (var i = 0; i < dimensions; i++) {
      vector[i] /= norm;
    }
    return vector;
  }

  /// 余弦相似度；长度不一致或零向量时返回 0
  static double cosine(List<double> a, List<double> b) {
    if (a.isEmpty || a.length != b.length) return 0;
    var dot = 0.0;
    var na = 0.0;
    var nb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na <= 0 || nb <= 0) return 0;
    return dot / math.sqrt(na * nb);
  }

  /// 特征计数：中文单字 + 二字组、ASCII 单词（小写）。公开给检索层复用
  /// （词面重叠兜底评分）。
  static Map<String, int> featureCounts(String text) {
    final counts = <String, int>{};
    void bump(String feature) {
      counts[feature] = (counts[feature] ?? 0) + 1;
    }

    final cleaned = text.trim().toLowerCase();
    if (cleaned.isEmpty) return counts;

    // ASCII 单词段
    final wordExp = RegExp(r'[a-z0-9]+');
    for (final match in wordExp.allMatches(cleaned)) {
      bump('w:${match.group(0)}');
    }

    // 中文字符序列：单字 + 相邻二字组
    final cjkExp = RegExp('[\u4e00-\u9fff]');
    final chars = cjkExp.allMatches(cleaned).map((m) => m.group(0)!).toList();
    for (final ch in chars) {
      bump('c:$ch');
    }
    for (var i = 0; i + 1 < chars.length; i++) {
      bump('b:${chars[i]}${chars[i + 1]}');
    }
    return counts;
  }

  /// djb2 变体：返回桶下标
  static int _hashIndex(String feature) {
    var h = 5381;
    for (var i = 0; i < feature.length; i++) {
      h = (h * 33 + feature.codeUnitAt(i)) & 0x3FFFFFFF;
    }
    return h % dimensions;
  }

  /// 用同一哈希的高位做随机正负号，降低碰撞导致的系统性偏置
  static double _hashSign(String feature) {
    var h = 5381;
    for (var i = feature.length - 1; i >= 0; i--) {
      h = (h * 33 + feature.codeUnitAt(i)) & 0x3FFFFFFF;
    }
    return (h & 1) == 0 ? 1.0 : -1.0;
  }
}

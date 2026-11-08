import 'package:tiktoken/tiktoken.dart';

/// 基于 tiktoken 的 token 计数，带采样与缓存以避免长文本卡顿
class TokenCounter {
  TokenCounter._();

  static final TokenCounter instance = TokenCounter._();

  Tiktoken? _encoder;
  final Map<String, int> _cache = {};

  Tiktoken get _enc {
    final cached = _encoder;
    if (cached != null) return cached;
    Tiktoken encoder;
    try {
      // o200k_base 覆盖 GPT-4o/o 系列，对中文也较接近
      encoder = getEncoding('o200k_base');
    } catch (_) {
      encoder = getEncoding('cl100k_base');
    }
    _encoder = encoder;
    return encoder;
  }

  /// 超过该长度的文本改用采样估算，避免编码 100KB+ 卡住 UI
  static const int _sampleThreshold = 20000;

  /// 统计文本 token 数
  int count(String text) {
    if (text.isEmpty) return 0;
    final cached = _cache[text];
    if (cached != null) return cached;

    int tokens;
    if (text.length <= _sampleThreshold) {
      tokens = _enc.encode(text).length;
    } else {
      // 采样前 20K 字符，按比例外推
      final sample = text.substring(0, _sampleThreshold);
      final sampleTokens = _enc.encode(sample).length;
      tokens = (sampleTokens * text.length / _sampleThreshold).round();
    }
    if (_cache.length > 500) _cache.clear();
    _cache[text] = tokens;
    return tokens;
  }
}

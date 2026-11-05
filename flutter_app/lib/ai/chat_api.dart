import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/chat_message.dart';
import 'ai_config.dart';

/// OpenAI Chat Completions 兼容的流式客户端（SSE）
class ChatApi {
  ChatApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 120),
            ));

  final Dio _dio;

  /// 逐段返回 delta 文本
  Stream<String> stream(AiConfig config, List<ChatMessage> messages) async* {
    final response = await _dio.post<ResponseBody>(
      '${config.baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions',
      data: {
        'model': config.model,
        'stream': true,
        'messages': messages
            .where((m) => m.content.isNotEmpty)
            .map((m) => {'role': m.role.name, 'content': m.content})
            .toList(),
      },
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        },
        validateStatus: (code) => code != null && code >= 200 && code < 300,
      ),
    );

    final body = response.data;
    if (body == null) return;

    final buffer = StringBuffer();
    await for (final chunk in body.stream) {
      buffer.write(utf8.decode(chunk, allowMalformed: true));
      var text = buffer.toString();
      var newline = text.indexOf('\n');
      while (newline >= 0) {
        final line = text.substring(0, newline).trim();
        text = text.substring(newline + 1);
        newline = text.indexOf('\n');
        if (line.isEmpty || !line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data == '[DONE]') return;
        final delta = _parseDelta(data);
        if (delta != null && delta.isNotEmpty) {
          yield delta;
        }
      }
      buffer
        ..clear()
        ..write(text);
    }
  }

  String? _parseDelta(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final choices = json['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final delta = choices.first['delta'];
      if (delta is! Map) return null;
      final content = delta['content'];
      if (content is String && content.isNotEmpty) return content;
      final reasoning = delta['reasoning_content'] ?? delta['reasoning'];
      if (reasoning is String && reasoning.isNotEmpty) return reasoning;
      return null;
    } catch (_) {
      return null;
    }
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/chat_message.dart';
import 'ai_config.dart';

/// 流式事件：正文 / 思考 / 工具调用增量
class ChatEvent {
  const ChatEvent({this.content, this.reasoning, this.toolCall});

  final String? content;
  final String? reasoning;
  final ToolCallDelta? toolCall;
}

class ToolCallDelta {
  const ToolCallDelta({
    required this.index,
    this.id,
    this.name,
    this.arguments,
  });

  final int index;
  final String? id;
  final String? name;
  final String? arguments;
}

/// OpenAI Chat Completions 兼容的流式客户端（SSE，支持工具调用）
class ChatApi {
  ChatApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 120),
            ));

  final Dio _dio;

  Stream<ChatEvent> stream(
    AiConfig config,
    List<ChatMessage> messages, {
    List<Map<String, dynamic>>? tools,
  }) async* {
    if (config.apiFormat == ApiFormat.anthropicMessages) {
      yield* _streamAnthropic(config, messages);
      return;
    }
    final body = {
      'model': config.model,
      'stream': true,
      'messages': messages.map((m) => _encodeMessage(m)).toList(),
    };
    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools;
    }

    final response = await _dio.post<ResponseBody>(
      '${_normalizeBaseUrl(config.baseUrl)}/v1/chat/completions',
      data: body,
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

    final respBody = response.data;
    if (respBody == null) return;

    final buffer = StringBuffer();
    await for (final chunk in respBody.stream) {
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
        final event = _parseEvent(data);
        if (event != null) yield event;
      }
      buffer
        ..clear()
        ..write(text);
    }
  }

  /// Anthropic Messages 协议（/v1/messages + x-api-key）
  Stream<ChatEvent> _streamAnthropic(
    AiConfig config,
    List<ChatMessage> messages,
  ) async* {
    final body = {
      'model': config.model,
      'max_tokens': 4096,
      'stream': true,
      'messages': [
        for (final m in messages)
          {
            'role': m.role == ChatRole.assistant ? 'assistant' : 'user',
            'content': m.content,
          }
      ],
    };

    final response = await _dio.post<ResponseBody>(
      '${_normalizeBaseUrl(config.baseUrl)}/v1/messages',
      data: body,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'x-api-key': config.apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
        },
        validateStatus: (code) => code != null && code >= 200 && code < 300,
      ),
    );

    final respBody = response.data;
    if (respBody == null) return;

    final buffer = StringBuffer();
    await for (final chunk in respBody.stream) {
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
        final event = _parseAnthropicEvent(data);
        if (event != null) yield event;
      }
      buffer
        ..clear()
        ..write(text);
    }
  }

  ChatEvent? _parseAnthropicEvent(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final type = json['type'] as String?;
      if (type == 'content_block_delta') {
        final delta = json['delta'];
        if (delta is Map) {
          final deltaType = delta['type'] as String?;
          if (deltaType == 'text_delta') {
            final t = delta['text'] as String?;
            if (t != null && t.isNotEmpty) return ChatEvent(content: t);
          } else if (deltaType == 'thinking_delta') {
            final t = delta['thinking'] as String?;
            if (t != null && t.isNotEmpty) return ChatEvent(reasoning: t);
          }
        }
      } else if (type == 'content_block_start') {
        final block = json['content_block'];
        if (block is Map && block['type'] == 'tool_use') {
          return ChatEvent(
            toolCall: ToolCallDelta(
              index: json['index'] as int? ?? 0,
              id: block['id'] as String?,
              name: block['name'] as String?,
              arguments: '',
            ),
          );
        }
      } else if (type == 'content_block_delta') {
        // handled above
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 与原生 ApiEndpoint.normalizeBaseUrl 一致：统一视为根地址
  static String _normalizeBaseUrl(String raw) {
    var url = raw.trim().replaceAll(RegExp(r'/+$'), '');
    for (final suffix in ['/v1/messages', '/v1/chat/completions', '/v1']) {
      if (url.endsWith(suffix)) {
        url = url.substring(0, url.length - suffix.length);
        url = url.replaceAll(RegExp(r'/+$'), '');
      }
    }
    return url;
  }

  Map<String, dynamic> _encodeMessage(ChatMessage message) {
    if (message.role == ChatRole.tool) {
      return {
        'role': 'tool',
        'tool_call_id': message.toolCallId ?? '',
        'content': message.content,
      };
    }
    final map = <String, dynamic>{
      'role': message.role.name,
      'content': message.content,
    };
    if (message.images.isNotEmpty) {
      map['content'] = [
        {'type': 'text', 'text': message.content},
        for (final image in message.images)
          {'type': 'image_url', 'image_url': {'url': image}},
      ];
    }
    if (message.toolCalls.isNotEmpty) {
      map['tool_calls'] = message.toolCalls
          .map((call) => {
                'id': call.id,
                'type': 'function',
                'function': {'name': call.name, 'arguments': call.arguments},
              })
          .toList();
      map.remove('content');
    }
    return map;
  }

  ChatEvent? _parseEvent(String data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final choices = json['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final delta = choices.first['delta'];
      if (delta is! Map) return null;

      final toolCalls = delta['tool_calls'];
      if (toolCalls is List && toolCalls.isNotEmpty) {
        final call = toolCalls.first as Map;
        final fn = call['function'];
        return ChatEvent(
          toolCall: ToolCallDelta(
            index: call['index'] as int? ?? 0,
            id: call['id'] as String?,
            name: fn is Map ? fn['name'] as String? : null,
            arguments: fn is Map ? fn['arguments'] as String? : null,
          ),
        );
      }

      final content = delta['content'];
      if (content is String && content.isNotEmpty) {
        return ChatEvent(content: content);
      }
      final reasoning = delta['reasoning_content'] ?? delta['reasoning'];
      if (reasoning is String && reasoning.isNotEmpty) {
        return ChatEvent(reasoning: reasoning);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

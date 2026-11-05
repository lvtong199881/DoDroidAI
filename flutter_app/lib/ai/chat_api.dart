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
    final body = {
      'model': config.model,
      'stream': true,
      'messages': messages.map((m) => _encodeMessage(m)).toList(),
    };
    if (tools != null && tools.isNotEmpty) {
      body['tools'] = tools;
    }

    final response = await _dio.post<ResponseBody>(
      '${config.baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions',
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

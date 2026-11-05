import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dodroidai/ai/ai_config.dart';
import 'package:dodroidai/ai/tools.dart';
import 'package:dodroidai/ai/chat_api.dart';
import 'package:dodroidai/models/chat_message.dart';

void main() {
  test('parses OpenAI SSE deltas', () async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((request) async {
      request.response.statusCode = 200;
      request.response.headers.contentType =
          ContentType('text', 'event-stream', charset: 'utf-8');
      for (final chunk in ['你好', '，世界', '！']) {
        request.response.write(
          'data: ${jsonEncode({
                'choices': [
                  {
                    'delta': {'content': chunk}
                  }
                ]
              })}\n\n',
        );
        await request.response.flush();
      }
      request.response.write('data: [DONE]\n\n');
      await request.response.close();
    });

    final api = ChatApi();
    final config = AiConfig(
      id: 'test',
      provider: AiProvider.custom,
      apiFormat: ApiFormat.openAiChatCompletions,
      providerName: 'test',
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'test-key',
      mainModel: 'mock',
    );
    final events = await api
        .stream(config, [ChatMessage(role: ChatRole.user, content: 'hi')])
        .toList();
    final result = events
        .where((e) => e.content != null)
        .map((e) => e.content!)
        .join();
    expect(result, '你好，世界！');
    await server.close(force: true);
  });

  test('parses tool_calls events', () async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((request) async {
      request.response.statusCode = 200;
      request.response.headers.contentType =
          ContentType('text', 'event-stream', charset: 'utf-8');
      request.response.write(
        'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {
                    'tool_calls': [
                      {
                        'index': 0,
                        'id': 'call_1',
                        'type': 'function',
                        'function': {'name': 'get_current_time', 'arguments': ''}
                      }
                    ]
                  }
                }
              ]
            })}\n\n',
      );
      request.response.write('data: [DONE]\n\n');
      await request.response.close();
    });

    final api = ChatApi();
    final config = AiConfig(
      id: 'test',
      provider: AiProvider.custom,
      apiFormat: ApiFormat.openAiChatCompletions,
      providerName: 'test',
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'test-key',
      mainModel: 'mock',
    );
    final events = await api
        .stream(config, [ChatMessage(role: ChatRole.user, content: 'hi')])
        .toList();
    final toolCall = events.firstWhere((e) => e.toolCall != null).toolCall!;
    expect(toolCall.id, 'call_1');
    expect(toolCall.name, 'get_current_time');
    await server.close(force: true);
  });

  test('accumulates multiple tool_calls and reasoning', () async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((request) async {
      request.response.statusCode = 200;
      request.response.headers.contentType =
          ContentType('text', 'event-stream', charset: 'utf-8');
      request.response.write(
        'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {
                    'reasoning_content': '思考中',
                  }
                }
              ]
            })}\n\n',
      );
      request.response.write(
        'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {
                    'tool_calls': [
                      {
                        'index': 0,
                        'id': 'call_a',
                        'function': {'name': 'get_current_time', 'arguments': ''}
                      }
                    ]
                  }
                }
              ]
            })}\n\n',
      );
      request.response.write(
        'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {
                    'tool_calls': [
                      {
                        'index': 0,
                        'function': {'arguments': '{}'}
                      }
                    ]
                  }
                }
              ]
            })}\n\n',
      );
      request.response.write('data: [DONE]\n\n');
      await request.response.close();
    });

    final api = ChatApi();
    final config = AiConfig(
      id: 'test',
      provider: AiProvider.custom,
      apiFormat: ApiFormat.openAiChatCompletions,
      providerName: 'test',
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'k',
      mainModel: 'm',
    );
    final events = await api
        .stream(config, [ChatMessage(role: ChatRole.user, content: 'hi')])
        .toList();
    final reasoning = events.where((e) => e.reasoning != null).length;
    final calls = events.where((e) => e.toolCall != null).toList();
    expect(reasoning, 1);
    expect(calls.length, 2);
    expect(calls.first.toolCall!.name, 'get_current_time');
    expect(calls.last.toolCall!.arguments, '{}');
    await server.close(force: true);
  });

  test('executes local tools', () async {
    final result = await ToolRegistry.execute('get_current_time', '{}');
    expect(result, isNotEmpty);
    final unknown = await ToolRegistry.execute('nope', '');
    expect(unknown, contains('未知工具'));
  });
}

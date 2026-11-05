import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dodroidai/ai/ai_config.dart';
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
      baseUrl: 'http://127.0.0.1:${server.port}',
      apiKey: 'test-key',
      model: 'mock',
    );
    final result = await api
        .stream(config, [ChatMessage(role: ChatRole.user, content: 'hi')])
        .join();
    expect(result, '你好，世界！');
    await server.close(force: true);
  });
}

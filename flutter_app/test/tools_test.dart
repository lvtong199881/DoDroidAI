import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/ai/tools.dart';

void main() {
  test('get_current_time returns iso string', () async {
    final result = await ToolRegistry.execute('get_current_time', '{}');
    expect(DateTime.tryParse(result), isNotNull);
  });

  test('unknown tool returns message', () async {
    final result = await ToolRegistry.execute('unknown_tool', '{}');
    expect(result, contains('未知工具'));
  });

  test('high risk tools are marked', () {
    expect(ToolRegistry.isHighRisk('send_sms'), isTrue);
    expect(ToolRegistry.isHighRisk('get_current_time'), isFalse);
  });

  test('session tools are registered', () {
    for (final name in [
      'session_search',
      'session_event_search',
      'session_event_read',
      'session_trace',
      'session_event_trace',
    ]) {
      expect(ToolRegistry.isKnown(name), isTrue, reason: name);
    }
  });

  test('web_search schema accepts multiple queries', () {
    final def = ToolRegistry.definitions.firstWhere(
      (d) => (d['function'] as Map)['name'] == 'web_search',
    );
    final parameters = (def['function'] as Map)['parameters'] as Map;
    expect(parameters['properties'], contains('queries'));
    expect(parameters['required'], contains('queries'));
  });

  test('session tools are not high risk', () {
    expect(ToolRegistry.isHighRisk('session_search'), isFalse);
    expect(ToolRegistry.isHighRisk('session_event_read'), isFalse);
  });
}

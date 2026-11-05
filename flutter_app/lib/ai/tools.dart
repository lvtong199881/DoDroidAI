/// Flutter 侧的工具注册与执行
class ToolRegistry {
  static const List<Map<String, dynamic>> definitions = [
    {
      'type': 'function',
      'function': {
        'name': 'get_current_time',
        'description': '获取设备当前日期与时间，返回 ISO 格式字符串',
        'parameters': {
          'type': 'object',
          'properties': <String, dynamic>{},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_battery_level',
        'description': '获取设备电池电量百分比',
        'parameters': {
          'type': 'object',
          'properties': <String, dynamic>{},
        },
      },
    },
  ];

  static bool isKnown(String name) =>
      definitions.any((d) => d['function']['name'] == name);

  static Future<String> execute(String name, String argumentsJson) async {
    switch (name) {
      case 'get_current_time':
        return DateTime.now().toIso8601String();
      case 'get_battery_level':
        return '电池信息需要在原生侧读取';
      default:
        return '未知工具: $name';
    }
  }
}

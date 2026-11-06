import 'dart:convert';

enum ChatRole { user, assistant, tool }

/// 消息内容块的类型：思考 / 工具调用 / 正文
enum MessageBlockKind { reasoning, toolCall, text }

/// 工具调用信息
class ToolCallInfo {
  ToolCallInfo({
    required this.id,
    required this.name,
    required this.arguments,
    required this.argsSummary,
    this.isRunning = false,
    this.isSuccess,
    this.resultSummary,
  });

  final String id;
  final String name;
  final String arguments;
  final String argsSummary;
  bool isRunning;
  bool? isSuccess;
  String? resultSummary;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'arguments': arguments,
        'argsSummary': argsSummary,
        'isRunning': isRunning,
        'isSuccess': isSuccess,
        'resultSummary': resultSummary,
      };

  static ToolCallInfo fromJson(Map<String, dynamic> json) => ToolCallInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        arguments: json['arguments'] as String? ?? '',
        argsSummary: json['argsSummary'] as String? ?? '',
        isRunning: json['isRunning'] as bool? ?? false,
        isSuccess: json['isSuccess'] as bool?,
        resultSummary: json['resultSummary'] as String?,
      );
}

/// 一条助手回复中的有序内容块，保证思考 / 工具 / 正文的真实时序
class MessageBlock {
  MessageBlock.reasoning({this.seconds = 0})
      : kind = MessageBlockKind.reasoning;

  MessageBlock.text() : kind = MessageBlockKind.text, seconds = 0;

  MessageBlock.tool(this.tool) : kind = MessageBlockKind.toolCall, seconds = 0;

  final MessageBlockKind kind;
  String text = '';
  ToolCallInfo? tool;
  int seconds;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'text': text,
        'seconds': seconds,
        if (tool != null) 'tool': tool!.toJson(),
      };

  static MessageBlock fromJson(Map<String, dynamic> json) {
    final kind = MessageBlockKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => MessageBlockKind.text,
    );
    final block = switch (kind) {
      MessageBlockKind.reasoning => MessageBlock.reasoning(),
      MessageBlockKind.toolCall =>
        MessageBlock.tool(ToolCallInfo.fromJson(
          (json['tool'] as Map?)?.cast<String, dynamic>() ?? const {},
        )),
      MessageBlockKind.text => MessageBlock.text(),
    };
    block.text = json['text'] as String? ?? '';
    block.seconds = (json['seconds'] as num?)?.toInt() ?? 0;
    return block;
  }
}

class ChatMessage {
  ChatMessage({
    required this.role,
    this.content = '',
    List<MessageBlock>? blocks,
    this.toolCallId,
    List<String>? images,
    this.isLoading = false,
    this.isError = false,
    DateTime? createdAt,
  })  : blocks = blocks ?? [],
        images = images ?? [],
        createdAt = createdAt ?? DateTime.now();

  final ChatRole role;

  /// 正文（朗读、复制、请求编码使用）
  String content;

  /// 有序内容块：思考 / 工具 / 正文片段
  final List<MessageBlock> blocks;

  String? toolCallId;
  List<String> images;
  bool isLoading;
  bool isError;
  final DateTime createdAt;

  /// 从 blocks 派生，供请求编码构建 assistant 的 tool_calls
  List<ToolCallInfo> get toolCalls =>
      blocks.where((b) => b.kind == MessageBlockKind.toolCall).map((b) => b.tool!).toList();

  /// 全部思考文本（用于需要整段思考的场景）
  String get reasoningText => blocks
      .where((b) => b.kind == MessageBlockKind.reasoning)
      .map((b) => b.text)
      .join('\n');

  String blocksToJson() => jsonEncode(blocks.map((b) => b.toJson()).toList());

  static List<MessageBlock> blocksFromJson(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((m) => MessageBlock.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

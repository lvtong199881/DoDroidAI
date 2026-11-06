enum ChatRole { user, assistant, tool }

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
}

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.reasoning,
    this.reasoningSeconds = 0,
    this.toolCalls = const [],
    this.toolCallId,
    List<String>? images,
    this.isLoading = false,
    this.isError = false,
    DateTime? createdAt,
  })  : images = images ?? [],
        createdAt = createdAt ?? DateTime.now();

  final ChatRole role;
  String content;
  String? reasoning;
  int reasoningSeconds;
  List<ToolCallInfo> toolCalls;
  String? toolCallId;
  List<String> images;
  bool isLoading;
  bool isError;
  final DateTime createdAt;
}

enum ChatRole { user, assistant }

class ToolCallInfo {
  ToolCallInfo({
    required this.name,
    required this.argsSummary,
    this.isRunning = false,
    this.isSuccess,
    this.resultSummary,
  });

  final String name;
  final String argsSummary;
  final bool isRunning;
  final bool? isSuccess;
  final String? resultSummary;
}

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    this.reasoning,
    this.reasoningSeconds = 0,
    this.toolCalls = const [],
    this.isLoading = false,
    this.isError = false,
  });

  final ChatRole role;
  String content;
  String? reasoning;
  int reasoningSeconds;
  List<ToolCallInfo> toolCalls;
  bool isLoading;
  bool isError;
}

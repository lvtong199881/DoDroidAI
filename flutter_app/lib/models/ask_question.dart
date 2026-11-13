import 'dart:convert';

/// 单个选项：label 必填，description 可选（一句话解释取舍）
class AskQuestionOption {
  const AskQuestionOption({required this.label, this.description});

  final String label;
  final String? description;

  factory AskQuestionOption.fromJson(Map<String, dynamic> json) {
    return AskQuestionOption(
      label: (json['label'] as String?) ?? '',
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        if (description != null) 'description': description,
      };
}

/// 模型发起的一个问题
class AskQuestion {
  const AskQuestion({
    required this.id,
    required this.question,
    this.header,
    this.options = const [],
    this.multiSelect = false,
  });

  final String id;
  final String question;
  final String? header;
  final List<AskQuestionOption> options;
  final bool multiSelect;

  bool get hasOptions => options.isNotEmpty;

  /// 容错解析：缺 id 用 q{index}，options 非数组按空处理
  factory AskQuestion.fromJson(Map<String, dynamic> json, int index) {
    final rawOptions = json['options'];
    final options = <AskQuestionOption>[];
    if (rawOptions is List) {
      for (final item in rawOptions) {
        if (item is Map) {
          final label = (item['label'] as String?)?.trim() ?? '';
          if (label.isNotEmpty) {
            options.add(AskQuestionOption.fromJson(
              Map<String, dynamic>.from(item),
            ));
          }
        } else if (item is String && item.trim().isNotEmpty) {
          options.add(AskQuestionOption(label: item.trim()));
        }
      }
    }
    final id = (json['id'] as String?)?.trim();
    return AskQuestion(
      id: (id == null || id.isEmpty) ? 'q$index' : id,
      question: (json['question'] as String?)?.trim() ?? '',
      header: (json['header'] as String?)?.trim(),
      options: options,
      multiSelect: json['multi_select'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        if (header != null && header!.isNotEmpty) 'header': header,
        if (options.isNotEmpty)
          'options': options.map((o) => o.toJson()).toList(),
        'multi_select': multiSelect,
      };

  /// 解析整批问题；返回 null 表示结构非法
  static List<AskQuestion>? parseList(Object? raw) {
    if (raw is! List || raw.isEmpty) return null;
    final result = <AskQuestion>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map) return null;
      final map = Map<String, dynamic>.from(item);
      final parsed = AskQuestion.fromJson(map, i);
      if (parsed.question.isEmpty) return null;
      result.add(parsed);
    }
    return result;
  }

  static String? duplicateId(List<AskQuestion> questions) {
    final seen = <String>{};
    for (final q in questions) {
      if (seen.contains(q.id)) return q.id;
      seen.add(q.id);
    }
    return null;
  }
}

/// 用户对单个问题的回答
class AskAnswer {
  const AskAnswer({
    required this.id,
    this.selected = const [],
    this.custom,
  });

  final String id;
  final List<String> selected;
  final String? custom;

  /// 跳过：没有选中项也没有自定义内容
  bool get isSkipped =>
      selected.isEmpty && (custom == null || custom!.trim().isEmpty);

  /// 与 DSH 一致：省略 null 与空 custom
  Map<String, dynamic> toJson() => {
        'id': id,
        'selected': List<String>.from(selected),
        if (custom != null && custom!.trim().isNotEmpty) 'custom': custom,
      };

  factory AskAnswer.fromJson(Map<String, dynamic> json) {
    final raw = json['selected'];
    return AskAnswer(
      id: (json['id'] as String?) ?? '',
      selected: raw is List ? raw.whereType<String>().toList() : const [],
      custom: json['custom'] as String?,
    );
  }
}

/// 超时落库的待答问题
class PendingQuestion {
  const PendingQuestion({
    required this.callId,
    required this.sessionId,
    required this.questions,
    required this.createdAt,
  });

  final String callId;
  final String sessionId;
  final List<AskQuestion> questions;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'call_id': callId,
        'session_id': sessionId,
        'questions': questions.map((q) => q.toJson()).toList(),
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  String get questionsJson => jsonEncode(questions.map((q) => q.toJson()).toList());

  static List<AskQuestion> decodeQuestions(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return AskQuestion.parseList(decoded) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  factory PendingQuestion.fromRow(Map<String, Object?> row) {
    return PendingQuestion(
      callId: (row['call_id'] as String?) ?? (row['id'] as String?) ?? '',
      sessionId: (row['session_id'] as String?) ?? '',
      questions: decodeQuestions((row['questions'] as String?) ?? ''),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as int?) ?? 0,
      ),
    );
  }
}

/// 工具执行结果：按时回答 / 超时 / 取消
class AskOutcome {
  const AskOutcome.answered(this.answers)
      : timedOut = false,
        cancelled = false,
        error = null;
  const AskOutcome.timedOut()
      : answers = const [],
        timedOut = true,
        cancelled = false,
        error = null;
  const AskOutcome.cancelled()
      : answers = const [],
        timedOut = false,
        cancelled = true,
        error = null;
  const AskOutcome.failed(this.error)
      : answers = const [],
        timedOut = false,
        cancelled = false;

  final List<AskAnswer> answers;
  final bool timedOut;
  final bool cancelled;

  /// 参数校验失败时的错误文案（对齐 DSH 的 Error: 前缀）
  final String? error;
}

/// 超时后返回给模型的提示（对齐 DSH pendingNotice 语义）
const String kAskPendingNotice =
    '等待时间内没有收到答案。这是 pending，不是跳过：继续做可以独立完成的工作。'
    '用户之后仍可回答，回答会以 answer_to_pending_question 标记的 user 消息'
    '连同 callId 与原始问题一起返回。不要把它当成许可。';

/// 超时后补答注入的用户消息前缀
String pendingAnswerMessage(String callId, List<AskAnswer> answers) {
  final payload = jsonEncode({
    'answers': answers.map((a) => a.toJson()).toList(),
  });
  return '[answer_to_pending_question callId=$callId]\n$payload';
}

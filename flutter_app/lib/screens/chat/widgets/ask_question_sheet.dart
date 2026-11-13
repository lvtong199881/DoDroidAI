import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../models/ask_question.dart';

/// 提问面板：逐题单选/多选/自定义输入，整体提交或跳过
Future<List<AskAnswer>?> showAskQuestionSheet(
  BuildContext context, {
  required List<AskQuestion> questions,
  int timeoutSeconds = 120,
}) {
  return showModalBottomSheet<List<AskAnswer>>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AskQuestionSheet(
      questions: questions,
      timeoutSeconds: timeoutSeconds,
    ),
  );
}

class _AskQuestionSheet extends StatefulWidget {
  const _AskQuestionSheet({
    required this.questions,
    required this.timeoutSeconds,
  });

  final List<AskQuestion> questions;
  final int timeoutSeconds;

  @override
  State<_AskQuestionSheet> createState() => _AskQuestionSheetState();
}

class _AskQuestionSheetState extends State<_AskQuestionSheet> {
  late final Map<String, Set<String>> _selected;
  late final Map<String, TextEditingController> _custom;
  Timer? _ticker;
  int _remaining = 0;

  bool get _infinite => widget.timeoutSeconds <= 0;

  @override
  void initState() {
    super.initState();
    _selected = {
      for (final q in widget.questions) q.id: <String>{},
    };
    _custom = {
      for (final q in widget.questions) q.id: TextEditingController(),
    };
    if (!_infinite) {
      _remaining = widget.timeoutSeconds;
      _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _remaining = (_remaining - 1).clamp(0, widget.timeoutSeconds);
        });
        if (_remaining <= 0) timer.cancel();
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final controller in _custom.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _formatRemaining() {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  List<AskAnswer> _collect() {
    return widget.questions.map((q) {
      final custom = _custom[q.id]?.text.trim() ?? '';
      return AskAnswer(
        id: q.id,
        selected: _selected[q.id]!.toList(),
        custom: custom.isEmpty ? null : custom,
      );
    }).toList();
  }

  void _submit() {
    Navigator.of(context).pop(_collect());
  }

  void _skipAll() {
    Navigator.of(context).pop(
      widget.questions
          .map((q) => AskAnswer(id: q.id, selected: const []))
          .toList(),
    );
  }

  void _skipOne(AskQuestion q) {
    setState(() {
      _selected[q.id]!.clear();
      _custom[q.id]!.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);
    // 高度自适应内容，上限为屏幕 80%
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(null);
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.t('askTitle'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    _infinite
                        ? strings.t('askWaiting')
                        : '${strings.t('askCountdown')} ${_formatRemaining()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _remaining <= 10 && !_infinite
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // 内容少时按内容高度收缩，超出上限后内部滚动
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.questions.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      _buildQuestion(context, scheme, widget.questions[i]),
                    ],
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _skipAll,
                        child: Text(strings.t('askSkipAll')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _submit,
                        child: Text(strings.t('askSubmit')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(
    BuildContext context,
    ColorScheme scheme,
    AskQuestion question,
  ) {
    final strings = AppStrings.of(context);
    final selected = _selected[question.id]!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (question.header != null && question.header!.isNotEmpty)
                Expanded(
                  child: Text(
                    question.header!,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                const Spacer(),
              TextButton(
                onPressed: () => _skipOne(question),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  strings.t('askSkipOne'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            question.question,
            style: const TextStyle(fontSize: 15, height: 1.35),
          ),
          if (question.hasOptions) ...[
            const SizedBox(height: 10),
            for (final option in question.options)
              _buildOption(scheme, question, option, selected),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _custom[question.id],
            maxLength: 500,
            minLines: 1,
            maxLines: 3,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: strings.t('askCustomHint'),
              isDense: true,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    ColorScheme scheme,
    AskQuestion question,
    AskQuestionOption option,
    Set<String> selected,
  ) {
    final isSelected = selected.contains(option.label);
    final multi = question.multiSelect;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          if (multi) {
            if (isSelected) {
              selected.remove(option.label);
            } else {
              selected.add(option.label);
            }
          } else {
            selected
              ..clear()
              ..add(option.label);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              multi
                  ? (isSelected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank)
                  : (isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked),
              size: 20,
              color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (option.description != null &&
                      option.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        option.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

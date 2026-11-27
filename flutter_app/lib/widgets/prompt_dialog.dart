import 'package:flutter/material.dart';

/// 一个输入框的配置。
class PromptField {
  const PromptField({required this.label, this.maxLines = 1, this.hintText});

  final String label;
  final int maxLines;
  final String? hintText;
}

/// 文本输入对话框。
///
/// TextEditingController 由对话框自己的 State 持有并在 `dispose()` 里释放：
/// `showDialog` 的 future 在退出动画开始前就会完成，如果在 future 之后立即
/// dispose，退场动画期间 TextField 重建会触发
/// "A TextEditingController was used after being disposed" 断言（红屏）。
class PromptDialog extends StatefulWidget {
  const PromptDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.cancelLabel,
    required this.saveLabel,
  });

  final String title;
  final List<PromptField> fields;
  final String cancelLabel;
  final String saveLabel;

  /// 弹出对话框；确认返回每个输入框的文本（按 fields 顺序，已 trim），
  /// 取消/点外部返回 null。
  static Future<List<String>?> show(
    BuildContext context, {
    required String title,
    required List<PromptField> fields,
    required String cancelLabel,
    required String saveLabel,
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (_) => PromptDialog(
        title: title,
        fields: fields,
        cancelLabel: cancelLabel,
        saveLabel: saveLabel,
      ),
    );
  }

  @override
  State<PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<PromptDialog> {
  late final List<TextEditingController> _controllers =
      List.generate(widget.fields.length, (_) => TextEditingController());

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _controllers.length == 1
        ? _buildField(_controllers[0], widget.fields[0])
        : SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _controllers.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _buildField(_controllers[i], widget.fields[i]),
                ],
              ],
            ),
          );
    return AlertDialog(
      title: Text(widget.title),
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _controllers.map((c) => c.text.trim()).toList(),
          ),
          child: Text(widget.saveLabel),
        ),
      ],
    );
  }

  Widget _buildField(TextEditingController controller, PromptField field) {
    return TextField(
      controller: controller,
      maxLines: field.maxLines,
      decoration: InputDecoration(labelText: field.label, hintText: field.hintText),
    );
  }
}

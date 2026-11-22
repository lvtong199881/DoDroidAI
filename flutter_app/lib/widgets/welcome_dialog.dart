import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../settings/welcome_contract.dart';

/// 一次性欢迎弹窗（模态）。
///
/// 结构：固定标题区 → 可滚动内容区（导语 + 三条卖点）→ 固定底部按钮区，
/// 保证最大字号下标题和主按钮始终可见。关闭只允许主按钮和系统返回键。
class WelcomeDialog extends StatefulWidget {
  const WelcomeDialog({super.key});

  @override
  State<WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<WelcomeDialog> {
  /// 连点保护：第一次 pop 之后忽略后续点击。
  bool _closing = false;

  void _close(WelcomeDismissMethod method) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(method);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return Dialog(
      backgroundColor: scheme.surface,
      elevation: 6,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Text(
                strings.t('welcomeTitle'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.t('welcomeIntro'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _WelcomeFeature(
                      icon: Icons.mic_none,
                      title: strings.t('welcomeFeat1Title'),
                      description: strings.t('welcomeFeat1Desc'),
                    ),
                    const SizedBox(height: 16),
                    _WelcomeFeature(
                      icon: Icons.phone_android,
                      title: strings.t('welcomeFeat2Title'),
                      description: strings.t('welcomeFeat2Desc'),
                    ),
                    const SizedBox(height: 16),
                    _WelcomeFeature(
                      icon: Icons.lock_outline,
                      title: strings.t('welcomeFeat3Title'),
                      description: strings.t('welcomeFeat3Desc'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  onPressed: () => _close(WelcomeDismissMethod.button),
                  child: Text(strings.t('welcomeStart')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeFeature extends StatelessWidget {
  const _WelcomeFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

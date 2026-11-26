import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../settings/welcome_contract.dart';

/// 欢迎图资源（2:1，1280×640），深浅各一套，按主题亮度选择。
const String welcomeHeroLightAsset = 'assets/images/welcome_hero_light.png';
const String welcomeHeroDarkAsset = 'assets/images/welcome_hero_dark.png';

/// 欢迎图宽高比：高 = 宽 / 2。
const double welcomeHeroAspectRatio = 2.0;

/// 一次性欢迎弹窗（模态）。
///
/// 结构：贴边欢迎图 → 居中的主标题与副标题 → 固定底部按钮。
/// 内容超高时图片与文字一起滚动，按钮固定在底部；
/// 图片缺失/解码失败时整块折叠，其余内容与关闭能力不受影响。
class WelcomeDialog extends StatefulWidget {
  const WelcomeDialog({
    super.key,
    this.showConfigureAi = false,
    @visibleForTesting this.heroAssetOverride,
  });

  /// 是否显示次要按钮「去配置AI」（未配置 AI 时由宿主传入 `true`）。
  ///
  /// 为 `false` 时整段不渲染，footer 高度与改动前一致。
  final bool showConfigureAi;

  /// 仅测试注入：非空时使用该 asset path；空字符串视为资源缺失，直接不渲染图片。
  @visibleForTesting
  final String? heroAssetOverride;

  @override
  State<WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<WelcomeDialog> {
  /// 连点保护：第一次 pop 之后忽略后续点击。
  bool _closing = false;

  /// 已加载失败并折叠的图片路径；路径变化（切换主题）时自动重试另一套素材。
  String? _failedHeroAsset;

  void _close(WelcomeDismissMethod method) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(method);
  }

  void _handleHeroFailed(String assetPath) {
    if (!mounted || _failedHeroAsset == assetPath) return;
    setState(() => _failedHeroAsset = assetPath);
  }

  String _resolveHeroAsset(Brightness brightness) {
    final override = widget.heroAssetOverride;
    if (override != null) return override;
    return brightness == Brightness.dark
        ? welcomeHeroDarkAsset
        : welcomeHeroLightAsset;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
    final heroAsset = _resolveHeroAsset(Theme.of(context).brightness);
    final showHero = heroAsset.isNotEmpty && _failedHeroAsset != heroAsset;

    return Dialog(
      backgroundColor: scheme.surface,
      elevation: 6,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        key: const Key('welcome_dialog_root'),
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                key: const Key('welcome_dialog_scroll'),
                primary: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showHero)
                      _WelcomeHero(
                        assetPath: heroAsset,
                        onFailed: () => _handleHeroFailed(heroAsset),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            strings.t('welcomeTitle'),
                            key: const Key('welcome_dialog_title'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            strings.t('welcomeIntro'),
                            key: const Key('welcome_dialog_subtitle'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 未配置 AI：次要按钮在上，主按钮在下；已配置时整段不渲染。
                  if (widget.showConfigureAi) ...[
                    OutlinedButton(
                      key: const Key('welcome_dialog_configure_ai'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.primary,
                        side: BorderSide(color: scheme.outline, width: 1),
                        minimumSize: const Size.fromHeight(48),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      onPressed: () =>
                          _close(WelcomeDismissMethod.configureAi),
                      child: Text(strings.t('welcomeConfigureAi')),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('welcome_dialog_start'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: const StadiumBorder(),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 贴边欢迎图：宽度撑满弹窗，高 = 宽 / 2，仅顶部两角 16dp 圆角。
class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.assetPath, required this.onFailed});

  final String assetPath;
  final VoidCallback onFailed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: const Key('welcome_dialog_hero'),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: AspectRatio(
        aspectRatio: welcomeHeroAspectRatio,
        child: Image.asset(
          assetPath,
          fit: BoxFit.fitWidth,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stackTrace) {
            // 下一帧整块折叠，避免失败图占位留下空白。
            WidgetsBinding.instance.addPostFrameCallback((_) => onFailed());
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

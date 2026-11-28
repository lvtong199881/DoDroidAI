import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../settings/welcome_contract.dart';

/// 欢迎图资源（2:1，1280×640），深浅各一套，按主题亮度选择。
const String welcomeHeroLightAsset = 'assets/images/welcome_hero_light.png';
const String welcomeHeroDarkAsset = 'assets/images/welcome_hero_dark.png';

/// 欢迎图宽高比：高 = 宽 / 2。
const double welcomeHeroAspectRatio = 2.0;

/// 卡片左右透明边距（= 屏宽 − 卡片宽 的一半）。
const double welcomeDialogInset = 20.0;

/// 卡片上下透明缓冲：恰好容纳 48dp 命中盒的一半。
const double welcomeDialogVerticalGutter = 24.0;

/// 关闭按钮视觉圆直径（含 1dp 描边）。
const double welcomeCloseVisualSize = 32.0;

/// 关闭按钮命中盒边长。
const double welcomeCloseHitSize = 48.0;

/// 弹窗最大高度占屏幕高度的比例。
const double welcomeDialogMaxHeightFactor = 0.8;

/// 无欢迎图时内容区额外顶部预留，避免标题被角标压住。
const double welcomeNoHeroExtraTop = 56.0;

/// 可见的弹窗矩形（内层 Material）；AC 里的「弹窗矩形」即此盒。
const Key welcomeDialogCardKey = Key('welcome_dialog_card');

/// 关闭按钮 48×48 命中盒 + 语义节点。
const Key welcomeDialogCloseKey = Key('welcome_dialog_close');

/// 关闭按钮 32×32 视觉圆。
const Key welcomeDialogCloseVisualKey = Key('welcome_dialog_close_visual');

/// 主按钮文字左侧的右箭头图标（纯装饰，仅测试定位用）。
const Key welcomeDialogStartIconKey = Key('welcome_dialog_start_icon');

/// 主按钮图标边长（dp）；固定值，不随系统字号缩放。
const double welcomeStartIconSize = 20.0;

/// 主按钮图标与文字之间的间距（dp）。
const double welcomeStartIconGap = 8.0;

/// 说明行定位 key（主标题与副标题之间的一行静态提示）。
const Key welcomeDialogAiHintKey = Key('welcome_dialog_ai_hint');

/// 主标题 → 说明行间距（dp）。
const double welcomeHintTitleGap = 6.0;

/// 说明行 → 副标题间距（dp）。
const double welcomeHintSubtitleGap = 12.0;

/// 说明行基准字号（sp）。
const double welcomeHintFontSize = 13.0;

/// 说明行字重。
const FontWeight welcomeHintFontWeight = FontWeight.w400;

/// 说明行行高倍数。
const double welcomeHintLineHeight = 1.4;

/// 一次性欢迎弹窗（模态）。
///
/// 结构：透明外壳（路由/遮罩/居中）→ 内层卡片 Material（背景/圆角/阴影/裁切）
/// → 贴边欢迎图、居中主标题与副标题、固定底部按钮；卡片右上角以「兄弟节点」
/// 方式钉一个半露出的关闭角标，因此不被卡片圆角裁切，层级高于卡片内容。
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
    final maxHeight =
        MediaQuery.sizeOf(context).height * welcomeDialogMaxHeightFactor;
    final heroAsset = _resolveHeroAsset(Theme.of(context).brightness);
    final showHero = heroAsset.isNotEmpty && _failedHeroAsset != heroAsset;

    return Dialog(
      // 外壳透明：只承担路由、遮罩与居中；可见背景/阴影/圆角/裁切下移到卡片，
      // 这样角标可以作为卡片的兄弟节点绘制在裁切之外。
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      clipBehavior: Clip.none,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: welcomeDialogInset,
              vertical: welcomeDialogVerticalGutter,
            ),
            child: Material(
              key: welcomeDialogCardKey,
              color: scheme.surface,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                              // 无欢迎图时顶部多留 56dp，给半露出的角标让位，
                              // 标题/副标题不与按钮相交。
                              padding: EdgeInsets.fromLTRB(
                                24,
                                showHero ? 20 : 20 + welcomeNoHeroExtraTop,
                                24,
                                8,
                              ),
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
                                  const SizedBox(height: welcomeHintTitleGap),
                                  Text(
                                    strings.t('welcomeAiHint'),
                                    key: welcomeDialogAiHintKey,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: welcomeHintFontSize,
                                      fontWeight: welcomeHintFontWeight,
                                      height: welcomeHintLineHeight,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: welcomeHintSubtitleGap,
                                  ),
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
                                side: BorderSide(
                                  color: scheme.outline,
                                  width: 1,
                                ),
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
                              onPressed: () =>
                                  _close(WelcomeDismissMethod.button),
                              // 图标+文字作为一组居中；文字空间不足时换行，
                              // 图标固定 20dp 不缩放。图标纯装饰：不绑手势、不进语义树。
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ExcludeSemantics(
                                    child: Icon(
                                      Icons.arrow_forward,
                                      key: welcomeDialogStartIconKey,
                                      size: welcomeStartIconSize,
                                      color: scheme.onPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: welcomeStartIconGap),
                                  Flexible(
                                    child: Text(strings.t('welcomeStart')),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 角标：圆心钉在卡片右上角。命中盒顶边与 Stack 顶边重合（48dp 纵向
          // 完整可命中）；右边超出 Stack 4dp，即屏幕右侧外 4dp。
          Positioned(
            top: 0,
            right: -4,
            child: _WelcomeCloseButton(
              label: strings.t('welcomeClose'),
              onPressed: () => _close(WelcomeDismissMethod.closeButton),
            ),
          ),
        ],
      ),
    );
  }
}

/// 右上角关闭角标：32dp 视觉圆、48dp 命中盒、半露出卡片边缘。
///
/// 图标自绘（16dp 画布内 11dp ×、2dp 圆头线宽），不引入图片资源；
/// 语义由外层 [Semantics] 统一提供，内部手势不再产生重复节点。
class _WelcomeCloseButton extends StatefulWidget {
  const _WelcomeCloseButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_WelcomeCloseButton> createState() => _WelcomeCloseButtonState();
}

class _WelcomeCloseButtonState extends State<_WelcomeCloseButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final fill = isDark ? scheme.surfaceContainerHigh : scheme.surface;
    final pressedFill = scheme.surfaceContainer;
    final shadowAlpha = isDark ? 0.50 : 0.18;

    return Semantics(
      key: welcomeDialogCloseKey,
      container: true,
      button: true,
      label: widget.label,
      onTap: widget.onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: SizedBox(
          width: welcomeCloseHitSize,
          height: welcomeCloseHitSize,
          child: Center(
            child: AnimatedScale(
              // 以圆心为锚缩放，露出比例保持 50%。
              scale: _pressed ? 0.94 : 1.0,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              child: Container(
                key: welcomeDialogCloseVisualKey,
                width: welcomeCloseVisualSize,
                height: welcomeCloseVisualSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _pressed ? pressedFill : fill,
                  border: Border.all(color: scheme.outline, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: shadowAlpha),
                      offset: const Offset(0, 2),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(16, 16),
                    painter: _CloseIconPainter(color: scheme.onSurface),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 16dp 画布内绘制 11×11 的 ×：线宽 2dp、圆头。
class _CloseIconPainter extends CustomPainter {
  const _CloseIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 2.5;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawLine(
      const Offset(inset, inset),
      Offset(size.width - inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(inset, size.height - inset),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CloseIconPainter oldDelegate) =>
      oldDelegate.color != color;
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

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/app_version.dart';
import 'package:dodroidai/l10n/app_strings.dart';
import 'package:dodroidai/settings/welcome_contract.dart';
import 'package:dodroidai/theme/app_theme.dart';
import 'package:dodroidai/widgets/welcome_dialog.dart';

const Key _heroKey = Key('welcome_dialog_hero');
const Key _scrollKey = Key('welcome_dialog_scroll');
const Key _titleKey = Key('welcome_dialog_title');
const Key _subtitleKey = Key('welcome_dialog_subtitle');
const Key _startKey = Key('welcome_dialog_start');
const Key _configureAiKey = Key('welcome_dialog_configure_ai');

/// 打开弹窗并返回「关闭时才会完成」的 Future。
Future<Future<WelcomeDismissMethod?>> openWelcome(
  WidgetTester tester, {
  Locale locale = const Locale('zh'),
  ThemeData? theme,
  Size logicalSize = const Size(360, 800),
  double textScale = 1.0,
  bool showConfigureAi = false,
  String versionLabel = 'v0.1.0',
  String? heroAssetOverride,
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = logicalSize;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final effectiveTheme = theme ?? AppTheme.light();
  Future<WelcomeDismissMethod?>? closing;
  await tester.pumpWidget(
    MaterialApp(
      theme: effectiveTheme,
      darkTheme: effectiveTheme,
      themeMode: ThemeMode.light,
      locale: locale,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () {
                closing = showDialog<WelcomeDismissMethod>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => WelcomeDialog(
                    showConfigureAi: showConfigureAi,
                    versionLabel: versionLabel,
                    heroAssetOverride: heroAssetOverride,
                  ),
                );
              },
              child: const Text('打开弹窗'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pump(); // 本地化是异步 load，补一拍让 home 真正建出来

  await tester.tap(find.text('打开弹窗'));
  await tester.pump();
  if (settle) await tester.pumpAndSettle();
  expect(find.byType(WelcomeDialog), findsOneWidget);
  return closing!;
}

/// 「弹窗矩形」= 可见的卡片 Material（AC-1/2/6/8 的几何基准）。
Rect dialogSurfaceRect(WidgetTester tester) {
  return tester.getRect(find.byKey(welcomeDialogCardKey));
}

/// 关闭按钮 32dp 视觉圆。
Rect closeVisualRect(WidgetTester tester) {
  return tester.getRect(find.byKey(welcomeDialogCloseVisualKey));
}

/// 关闭按钮 48dp 命中盒。
Rect closeHitRect(WidgetTester tester) {
  return tester.getRect(find.byKey(welcomeDialogCloseKey));
}

/// WCAG 相对亮度对比度。
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

String heroAssetName(WidgetTester tester) {
  final image = tester.widget<Image>(
    find.descendant(of: find.byKey(_heroKey), matching: find.byType(Image)),
  );
  final provider = image.image;
  expect(provider, isA<AssetImage>());
  return (provider as AssetImage).assetName;
}

ScrollableState scrollState(WidgetTester tester) {
  return tester.state<ScrollableState>(
    find.descendant(
      of: find.byKey(_scrollKey),
      matching: find.byType(Scrollable),
    ),
  );
}

/// footer 高度 = 弹窗底边 - 滚动区底边（滚动区下方紧接固定 footer）。
double footerHeight(WidgetTester tester) {
  final dialogRect = dialogSurfaceRect(tester);
  final scrollRect = tester.getRect(find.byKey(_scrollKey));
  return dialogRect.bottom - scrollRect.bottom;
}

/// 说明行（主标题与副标题之间的静态提示）矩形。
Rect hintRect(WidgetTester tester) {
  return tester.getRect(find.byKey(welcomeDialogAiHintKey));
}

/// 说明行 Text 组件。
Text hintText(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(welcomeDialogAiHintKey));
}

/// 读取 PNG 的 IHDR 宽高。
({int width, int height}) readPngSize(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: path);
  final bytes = file.readAsBytesSync();
  expect(bytes.sublist(0, 8), [
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
  ], reason: 'PNG signature: $path');
  final data = ByteData.sublistView(bytes);
  return (width: data.getUint32(16), height: data.getUint32(20));
}

void expectCentered(WidgetTester tester, Key key, Rect dialogRect) {
  final text = tester.widget<Text>(find.byKey(key));
  expect(text.textAlign, TextAlign.center, reason: key.toString());
  final rect = tester.getRect(find.byKey(key));
  expect(
    rect.center.dx,
    closeTo(dialogRect.center.dx, 1.0),
    reason: '${key.toString()} 未水平居中',
  );
}

void main() {
  testWidgets('中文：欢迎图贴边置顶，标题与副标题居中，三组卖点消失', (tester) async {
    await openWelcome(tester);

    final dialogRect = dialogSurfaceRect(tester);
    final heroRect = tester.getRect(find.byKey(_heroKey));

    // AC-1 / AC-2 / AC-4：图在弹窗最上方、左右贴边、2:1
    expect(heroRect.top, closeTo(dialogRect.top, 0.5));
    expect(heroRect.left, closeTo(dialogRect.left, 1.0));
    expect(heroRect.right, closeTo(dialogRect.right, 1.0));
    expect(heroRect.height / heroRect.width, closeTo(0.5, 0.005));

    final titleRect = tester.getRect(find.byKey(_titleKey));
    final subtitleRect = tester.getRect(find.byKey(_subtitleKey));
    expect(heroRect.bottom, lessThanOrEqualTo(titleRect.top + 0.5));
    expect(titleRect.bottom, lessThanOrEqualTo(subtitleRect.top + 0.5));

    // AC-6 / AC-7：标题、副标题居中
    expectCentered(tester, _titleKey, dialogRect);
    expectCentered(tester, _subtitleKey, dialogRect);

    // AC-5：三组卖点的图标、标题、描述都不再渲染
    final strings = AppStrings(const Locale('zh'));
    for (final key in const [
      'welcomeFeat1Title',
      'welcomeFeat1Desc',
      'welcomeFeat2Title',
      'welcomeFeat2Desc',
      'welcomeFeat3Title',
      'welcomeFeat3Desc',
    ]) {
      expect(find.text(strings.t(key)), findsNothing, reason: key);
    }
    expect(find.byIcon(Icons.mic_none), findsNothing);
    expect(find.byIcon(Icons.phone_android), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);

    // AC-14：浅色主题选浅色素材
    expect(heroAssetName(tester), welcomeHeroLightAsset);

    // 右上角新增角标（AC-1），底部主按钮仍在
    expect(find.byKey(welcomeDialogCloseKey), findsOneWidget);
    expect(find.byKey(welcomeDialogCloseVisualKey), findsOneWidget);
    expect(find.text(strings.t('welcomeStart')), findsOneWidget);
  });

  testWidgets('411dp 宽度：欢迎图仍贴边且保持 2:1', (tester) async {
    await openWelcome(tester, logicalSize: const Size(411, 800));

    final dialogRect = dialogSurfaceRect(tester);
    final heroRect = tester.getRect(find.byKey(_heroKey));
    expect(heroRect.left, closeTo(dialogRect.left, 1.0));
    expect(heroRect.right, closeTo(dialogRect.right, 1.0));
    expect(heroRect.width, closeTo(371, 1.0));
    expect(heroRect.height, closeTo(371 / 2, 1.0));
    expect(heroRect.height / heroRect.width, closeTo(0.5, 0.005));
  });

  testWidgets('卡片承载背景/圆角/阴影/裁切，路由外壳透明', (tester) async {
    await openWelcome(tester);

    final clip = tester.widget<ClipRRect>(find.byKey(_heroKey));
    expect(
      clip.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(16)),
    );

    // AC-1/2/7：可见弹窗矩形是卡片 Material，背景/圆角/阴影/裁切都在这里。
    final card = tester.widget<Material>(find.byKey(welcomeDialogCardKey));
    final scheme = AppTheme.light().colorScheme;
    expect(card.color, scheme.surface);
    expect(card.elevation, 6);
    expect(card.clipBehavior, Clip.antiAlias);
    expect(card.shape, isA<RoundedRectangleBorder>());
    expect(
      (card.shape as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(16),
    );

    // 外壳透明、不裁切，角标才能画到卡片圆角之外。
    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, Colors.transparent);
    expect(dialog.elevation, 0);
    expect(dialog.clipBehavior, Clip.none);
    expect(dialog.insetPadding, EdgeInsets.zero);
  });

  testWidgets('英文文案完整且居中', (tester) async {
    await openWelcome(tester, locale: const Locale('en'));

    final strings = AppStrings(const Locale('en'));
    expect(find.text('Welcome to DoDroidAI'), findsOneWidget);
    expect(find.text('Say it, and let your phone do it.'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('开始使用'), findsNothing);

    final dialogRect = dialogSurfaceRect(tester);
    expectCentered(tester, _titleKey, dialogRect);
    expectCentered(tester, _subtitleKey, dialogRect);

    for (final key in const [
      'welcomeFeat1Title',
      'welcomeFeat1Desc',
      'welcomeFeat2Title',
      'welcomeFeat2Desc',
      'welcomeFeat3Title',
      'welcomeFeat3Desc',
    ]) {
      expect(find.text(strings.t(key)), findsNothing, reason: key);
    }
  });

  testWidgets('深色主题选深色欢迎图', (tester) async {
    await openWelcome(tester, theme: AppTheme.dark());

    expect(heroAssetName(tester), welcomeHeroDarkAsset);
  });

  testWidgets('欢迎图缺失：整块折叠，其余内容可用且可关闭', (tester) async {
    final closing = await openWelcome(
      tester,
      heroAssetOverride: 'assets/images/__missing_welcome_hero__.png',
    );

    // 让真实 asset 加载失败跑完，再让 errorBuilder 触发下一帧折叠。
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(_heroKey), findsNothing);
    expect(find.byKey(_titleKey), findsOneWidget);
    expect(find.byKey(_subtitleKey), findsOneWidget);
    expect(find.byKey(_startKey), findsOneWidget);

    await tester.tap(find.text('开始使用'));
    await tester.pumpAndSettle();
    expect(await closing, WelcomeDismissMethod.button);
  });

  testWidgets('空路径视为资源缺失，直接不渲染图片', (tester) async {
    final closing = await openWelcome(tester, heroAssetOverride: '');

    expect(tester.takeException(), isNull);
    expect(find.byKey(_heroKey), findsNothing);
    expect(find.byKey(_titleKey), findsOneWidget);
    expect(find.byKey(_subtitleKey), findsOneWidget);

    await tester.tap(find.text('开始使用'));
    await tester.pumpAndSettle();
    expect(await closing, WelcomeDismissMethod.button);
  });

  testWidgets('遮罩点击不关闭，主按钮关闭并回到首页', (tester) async {
    final closing = await openWelcome(tester);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeDialog), findsOneWidget);

    final barriers = tester.widgetList<ModalBarrier>(find.byType(ModalBarrier));
    expect(barriers.any((barrier) => barrier.dismissible == false), isTrue);

    await tester.tap(find.text('开始使用'));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeDialog), findsNothing);
    expect(find.text('打开弹窗'), findsOneWidget);
    expect(await closing, WelcomeDismissMethod.button);
  });

  testWidgets('系统返回键关闭且不返回结果', (tester) async {
    final closing = await openWelcome(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeDialog), findsNothing);
    expect(find.text('打开弹窗'), findsOneWidget);
    expect(await closing, isNull);
  });

  testWidgets('连点主按钮只关闭一次', (tester) async {
    final closing = await openWelcome(tester);
    final button = find.widgetWithText(FilledButton, '开始使用');

    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(await closing, WelcomeDismissMethod.button);
    expect(find.byType(WelcomeDialog), findsNothing);
    expect(find.text('打开弹窗'), findsOneWidget);
  });

  testWidgets('浅色主题卡片背景为 #FFFFFF', (tester) async {
    await openWelcome(tester, theme: AppTheme.light());

    final card = tester.widget<Material>(find.byKey(welcomeDialogCardKey));
    expect(card.color, const Color(0xFFFFFFFF));
    expect(card.shape, isA<RoundedRectangleBorder>());
  });

  testWidgets('深色主题卡片背景为 #161920', (tester) async {
    await openWelcome(tester, theme: AppTheme.dark());

    final card = tester.widget<Material>(find.byKey(welcomeDialogCardKey));
    expect(card.color, const Color(0xFF161920));
  });

  testWidgets('文字不设 maxLines/ellipsis（版本行除外），不覆盖系统字号', (tester) async {
    await openWelcome(tester, textScale: 2.0);

    final texts = tester.widgetList<Text>(
      find.descendant(
        of: find.byType(WelcomeDialog),
        matching: find.byType(Text),
      ),
    );
    expect(texts, isNotEmpty);
    for (final text in texts) {
      if (text.key == welcomeDialogVersionKey) continue;
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
    }

    // 版本行按需求单行末尾省略，是唯一例外。
    final version = tester.widget<Text>(find.byKey(welcomeDialogVersionKey));
    expect(version.maxLines, 1);
    expect(version.overflow, TextOverflow.ellipsis);
  });

  testWidgets('640×400 超高：图与文字可滚动，按钮固定可见', (tester) async {
    final closing = await openWelcome(
      tester,
      logicalSize: const Size(640, 400),
    );

    expect(tester.takeException(), isNull);

    final dialogRect = dialogSurfaceRect(tester);
    expect(dialogRect.height, lessThanOrEqualTo(400 * 0.8 + 0.5));
    expect(dialogRect.width, closeTo(600, 1.0));

    // AC-12：初始在顶部，滚动范围 > 0
    final state = scrollState(tester);
    expect(state.position.pixels, 0);
    expect(state.position.maxScrollExtent, greaterThan(0));

    // 按钮始终在屏幕内、在弹窗底部
    final buttonRect = tester.getRect(find.byKey(_startKey));
    expect(buttonRect.top, greaterThanOrEqualTo(dialogRect.top));
    expect(buttonRect.bottom, lessThanOrEqualTo(dialogRect.bottom));
    expect(buttonRect.bottom, lessThanOrEqualTo(400));

    // 滚到底能看到完整副标题
    await tester.drag(find.byKey(_scrollKey), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(state.position.pixels, state.position.maxScrollExtent);

    final subtitleRect = tester.getRect(find.byKey(_subtitleKey));
    expect(subtitleRect.top, greaterThanOrEqualTo(dialogRect.top - 0.5));
    expect(subtitleRect.bottom, lessThanOrEqualTo(dialogRect.bottom + 0.5));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('开始使用'));
    await tester.pumpAndSettle();
    expect(await closing, WelcomeDismissMethod.button);
  });

  testWidgets('2.0 倍字号小屏：内容可滚动、按钮固定可见、无溢出', (tester) async {
    final closing = await openWelcome(
      tester,
      textScale: 2.0,
      logicalSize: const Size(360, 500),
    );

    expect(tester.takeException(), isNull);

    final dialogRect = dialogSurfaceRect(tester);
    expect(dialogRect.height, lessThanOrEqualTo(500 * 0.8 + 0.5));

    final state = scrollState(tester);
    expect(state.position.maxScrollExtent, greaterThan(0));

    final buttonRect = tester.getRect(find.byKey(_startKey));
    expect(buttonRect.top, greaterThanOrEqualTo(0));
    expect(buttonRect.bottom, lessThanOrEqualTo(500));

    await tester.drag(find.byKey(_scrollKey), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(state.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(_startKey));
    await tester.pumpAndSettle();
    expect(await closing, WelcomeDismissMethod.button);
  });

  testWidgets('320dp 窄屏：不横向溢出，主按钮完整可点', (tester) async {
    final closing = await openWelcome(
      tester,
      logicalSize: const Size(320, 640),
    );

    expect(tester.takeException(), isNull);

    final dialogRect = dialogSurfaceRect(tester);
    expect(dialogRect.width, closeTo(280, 1.0));
    expect(dialogRect.left, greaterThanOrEqualTo(0));
    expect(dialogRect.right, lessThanOrEqualTo(320));

    final heroRect = tester.getRect(find.byKey(_heroKey));
    expect(heroRect.width, closeTo(dialogRect.width, 1.0));
    expect(heroRect.height, closeTo(heroRect.width / 2, 1.0));

    final buttonRect = tester.getRect(find.byKey(_startKey));
    expect(buttonRect.left, greaterThanOrEqualTo(0));
    expect(buttonRect.right, lessThanOrEqualTo(320));
    expect(buttonRect.height, greaterThanOrEqualTo(48));

    await tester.tap(find.text('开始使用'));
    await tester.pumpAndSettle();
    expect(await closing, WelcomeDismissMethod.button);
  });

  testWidgets('未配置：双按钮纵向全宽，副在上、主在下、间距 8', (tester) async {
    await openWelcome(tester, showConfigureAi: true);

    expect(tester.takeException(), isNull);
    expect(find.byKey(_configureAiKey), findsOneWidget);
    expect(find.byKey(_startKey), findsOneWidget);
    expect(find.text('去配置AI'), findsOneWidget);

    final dialogRect = dialogSurfaceRect(tester);
    final secondaryRect = tester.getRect(find.byKey(_configureAiKey));
    final primaryRect = tester.getRect(find.byKey(_startKey));

    // 上副下主、不重叠，间距 8
    expect(secondaryRect.bottom, lessThanOrEqualTo(primaryRect.top));
    expect(primaryRect.top - secondaryRect.bottom, closeTo(8, 0.5));

    // 全宽：等于弹窗内容宽度（左右各 20 内边距），两按钮等宽
    expect(secondaryRect.width, closeTo(dialogRect.width - 40, 0.5));
    expect(primaryRect.width, closeTo(secondaryRect.width, 0.5));
    expect(secondaryRect.left, closeTo(dialogRect.left + 20, 0.5));
    expect(secondaryRect.right, closeTo(dialogRect.right - 20, 0.5));

    // 都在弹窗内且高度 >= 48（不重叠、不裁切）
    for (final rect in [secondaryRect, primaryRect]) {
      expect(rect.top, greaterThanOrEqualTo(dialogRect.top));
      expect(rect.bottom, lessThanOrEqualTo(dialogRect.bottom));
      expect(rect.height, greaterThanOrEqualTo(48));
    }

    // footer 高度 = 上 12 + 48 + 8 + 48 + 8 + 19.6 + 下 20 = 163.6
    expect(footerHeight(tester), closeTo(163.6, 0.5));

    // 次要样式：OutlinedButton + 主题 outline 描边 / primary 文字，主按钮仍是 FilledButton
    final secondary = tester.widget<OutlinedButton>(find.byKey(_configureAiKey));
    expect(tester.widget(find.byKey(_startKey)), isA<FilledButton>());
    final scheme = AppTheme.light().colorScheme;
    final side = secondary.style?.side?.resolve(const <WidgetState>{});
    expect(side, isNotNull);
    expect(side!.color, scheme.outline);
    expect(side.width, 1);
    expect(
      secondary.style?.foregroundColor?.resolve(const <WidgetState>{}),
      scheme.primary,
    );
    expect(
      secondary.style?.shape?.resolve(const <WidgetState>{}),
      isA<StadiumBorder>(),
    );
  });

  testWidgets('已配置：无次要按钮、无额外占位（footer 107.6，版本行贴底）', (tester) async {
    await openWelcome(tester, showConfigureAi: false);

    final dialogRect = dialogSurfaceRect(tester);
    final primaryRect = tester.getRect(find.byKey(_startKey));

    expect(find.byKey(_configureAiKey), findsNothing);
    expect(find.text('去配置AI'), findsNothing);
    // 未配置时 footer 为 163.6（多一个 48 按钮 + 8 间距），已配置为 107.6
    expect(footerHeight(tester), closeTo(107.6, 0.5));
    // 版本行贴底：19.6 行盒 + 下内边距 20
    final versionRect = tester.getRect(find.byKey(welcomeDialogVersionKey));
    expect(dialogRect.bottom - versionRect.bottom, closeTo(20, 0.5));
    expect(versionRect.top - primaryRect.bottom, closeTo(8, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('英文：次要按钮显示 Set up AI', (tester) async {
    await openWelcome(
      tester,
      locale: const Locale('en'),
      showConfigureAi: true,
    );

    expect(find.text('Set up AI'), findsOneWidget);
    expect(find.text('去配置AI'), findsNothing);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('点击「去配置AI」：关闭弹窗并返回 configureAi', (tester) async {
    final closing = await openWelcome(tester, showConfigureAi: true);

    await tester.tap(find.byKey(_configureAiKey));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeDialog), findsNothing);
    expect(find.text('打开弹窗'), findsOneWidget);
    expect(await closing, WelcomeDismissMethod.configureAi);
  });

  testWidgets('连点「去配置AI」只关闭一次', (tester) async {
    final closing = await openWelcome(tester, showConfigureAi: true);

    await tester.tap(find.byKey(_configureAiKey));
    await tester.tap(find.byKey(_configureAiKey), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(WelcomeDialog), findsNothing);
    expect(await closing, WelcomeDismissMethod.configureAi);
  });

  testWidgets('深色主题：双按钮存在、取主题描边与文字色', (tester) async {
    await openWelcome(tester, theme: AppTheme.dark(), showConfigureAi: true);

    expect(find.byKey(_configureAiKey), findsOneWidget);
    expect(find.byKey(_startKey), findsOneWidget);
    final scheme = AppTheme.dark().colorScheme;
    final secondary = tester.widget<OutlinedButton>(find.byKey(_configureAiKey));
    expect(
      secondary.style?.side?.resolve(const <WidgetState>{})?.color,
      scheme.outline,
    );
    expect(
      secondary.style?.foregroundColor?.resolve(const <WidgetState>{}),
      scheme.primary,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp 英文双按钮：不溢出、完整可点', (tester) async {
    final closing = await openWelcome(
      tester,
      locale: const Locale('en'),
      logicalSize: const Size(320, 640),
      showConfigureAi: true,
    );

    expect(tester.takeException(), isNull);

    final dialogRect = dialogSurfaceRect(tester);
    final secondaryRect = tester.getRect(find.byKey(_configureAiKey));
    final primaryRect = tester.getRect(find.byKey(_startKey));
    for (final rect in [secondaryRect, primaryRect]) {
      expect(rect.left, greaterThanOrEqualTo(dialogRect.left - 0.5));
      expect(rect.right, lessThanOrEqualTo(dialogRect.right + 0.5));
      expect(rect.height, greaterThanOrEqualTo(48));
    }
    expect(primaryRect.top - secondaryRect.bottom, closeTo(8, 0.5));

    await tester.tap(find.byKey(_configureAiKey));
    await tester.pumpAndSettle();
    expect(await closing, WelcomeDismissMethod.configureAi);
  });

  testWidgets('AC-1/2/4：角标钉在卡片右上角，露出 50%，命中 48', (tester) async {
    await openWelcome(tester);

    final card = dialogSurfaceRect(tester);
    final visual = closeVisualRect(tester);
    final hit = closeHitRect(tester);

    // 圆心与卡片矩形右上角重合（偏差 ≤ 1dp）
    expect(visual.center.dx, closeTo(card.right, 1.0));
    expect(visual.center.dy, closeTo(card.top, 1.0));

    // 32dp 视觉圆，右/上各露出 16dp = 50%（AC-2 要求 45%–55%）
    expect(visual.width, closeTo(welcomeCloseVisualSize, 0.5));
    expect(visual.height, closeTo(welcomeCloseVisualSize, 0.5));
    final exposedX = (visual.right - card.right) / visual.width;
    final exposedY = (card.top - visual.top) / visual.height;
    expect(exposedX, closeTo(0.5, 0.02));
    expect(exposedY, closeTo(0.5, 0.02));

    // 命中盒 48dp（AC-4），且 48 盒中心与视觉圆心同心
    expect(hit.width, closeTo(welcomeCloseHitSize, 0.5));
    expect(hit.height, closeTo(welcomeCloseHitSize, 0.5));
    expect(hit.center.dx, closeTo(visual.center.dx, 0.5));
    expect(hit.center.dy, closeTo(visual.center.dy, 0.5));

    // 视觉圆完整落在 360dp 屏幕内，渲染无异常（不被裁切）
    expect(visual.left, greaterThanOrEqualTo(0));
    expect(visual.right, lessThanOrEqualTo(360));
    expect(visual.top, greaterThanOrEqualTo(0));
    expect(visual.bottom, lessThanOrEqualTo(800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC-3：点卡片外露出的部分可关闭，返回 closeButton', (tester) async {
    final closing = await openWelcome(tester);
    final card = dialogSurfaceRect(tester);
    final outsidePoint = Offset(card.right + 10, card.top - 10);

    // 该点已在卡片矩形外（外露的半圆上），但仍在 48dp 命中盒内
    expect(outsidePoint.dx, greaterThan(card.right));
    expect(outsidePoint.dy, lessThan(card.top));
    expect(closeHitRect(tester).contains(outsidePoint), isTrue);

    await tester.tapAt(outsidePoint);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(WelcomeDialog), findsNothing);
    expect(await closing, WelcomeDismissMethod.closeButton);
  });

  testWidgets('AC-6：角标不与标题/副标题/主按钮矩形相交', (tester) async {
    await openWelcome(tester);

    final visual = closeVisualRect(tester);
    for (final key in [_titleKey, _subtitleKey, _startKey]) {
      final rect = tester.getRect(find.byKey(key));
      expect(
        visual.overlaps(rect),
        isFalse,
        reason: '角标与 ${key.toString()} 相交: $visual vs $rect',
      );
    }
  });

  testWidgets('AC-7：小屏 + 2 倍字号滚动后角标仍钉角、仍可点', (tester) async {
    final closing = await openWelcome(
      tester,
      logicalSize: const Size(640, 400),
      textScale: 2.0,
    );

    final card = dialogSurfaceRect(tester);
    final state = scrollState(tester);
    expect(state.position.maxScrollExtent, greaterThan(0));

    final before = closeVisualRect(tester).center;
    await tester.drag(find.byKey(_scrollKey), const Offset(0, -300));
    await tester.pumpAndSettle();

    final after = closeVisualRect(tester).center;
    expect(after.dx, closeTo(before.dx, 0.5));
    expect(after.dy, closeTo(before.dy, 0.5));
    expect(after.dx, closeTo(card.right, 1.0));
    expect(after.dy, closeTo(card.top, 1.0));

    await tester.tapAt(Offset(card.right + 10, card.top - 10));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(WelcomeDialog), findsNothing);
    expect(await closing, WelcomeDismissMethod.closeButton);
  });

  testWidgets('AC-8：无欢迎图时角标仍在原位，且不压标题/副标题', (tester) async {
    final closing = await openWelcome(tester, heroAssetOverride: '');

    expect(find.byKey(_heroKey), findsNothing);

    final card = dialogSurfaceRect(tester);
    final visual = closeVisualRect(tester);
    expect(visual.center.dx, closeTo(card.right, 1.0));
    expect(visual.center.dy, closeTo(card.top, 1.0));

    for (final key in [_titleKey, _subtitleKey]) {
      final rect = tester.getRect(find.byKey(key));
      expect(
        visual.overlaps(rect),
        isFalse,
        reason: '无图时角标与 ${key.toString()} 相交',
      );
      // 内容顶部为角标预留空间：标题/副标题都在角标视觉下边缘之下
      expect(rect.top, greaterThan(visual.bottom));
    }
    expect(
      tester.getRect(find.byKey(_titleKey)).top - card.top,
      greaterThanOrEqualTo(20 + welcomeNoHeroExtraTop - 1),
    );

    await tester.tapAt(Offset(card.right + 10, card.top - 10));
    await tester.pumpAndSettle();
    expect(await closing, WelcomeDismissMethod.closeButton);
  });

  testWidgets('AC-9：320dp 窄屏视觉圆完整在屏幕内', (tester) async {
    await openWelcome(tester, logicalSize: const Size(320, 640));

    final card = dialogSurfaceRect(tester);
    final visual = closeVisualRect(tester);

    expect(card.width, closeTo(280, 1.0));
    expect(visual.center.dx, closeTo(card.right, 1.0));
    expect(visual.center.dy, closeTo(card.top, 1.0));
    expect(visual.left, greaterThanOrEqualTo(0));
    expect(visual.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC-10/11：点角标只关闭一次，返回 closeButton，首页可交互', (tester) async {
    final closing = await openWelcome(tester);

    await tester.tap(find.byKey(welcomeDialogCloseKey));
    await tester.tap(
      find.byKey(welcomeDialogCloseKey),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(WelcomeDialog), findsNothing);
    expect(find.text('打开弹窗'), findsOneWidget);
    expect(await closing, WelcomeDismissMethod.closeButton);
  });

  testWidgets('AC-14：角标语义为按钮，中文名「关闭」且可激活', (tester) async {
    final handle = tester.ensureSemantics();

    final closing = await openWelcome(tester);
    final data = tester
        .getSemantics(find.byKey(welcomeDialogCloseKey))
        .getSemanticsData();

    expect(data.label, '关闭');
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);

    // 语义节点覆盖 48dp 命中盒
    expect(data.rect.width, closeTo(welcomeCloseHitSize, 1.0));
    expect(data.rect.height, closeTo(welcomeCloseHitSize, 1.0));

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(await closing, isNull);

    handle.dispose();
  });

  testWidgets('AC-14：英文可访问名称为 Close', (tester) async {
    final handle = tester.ensureSemantics();

    await openWelcome(tester, locale: const Locale('en'));
    final data = tester
        .getSemantics(find.byKey(welcomeDialogCloseKey))
        .getSemanticsData();

    expect(data.label, 'Close');
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(find.text('Close'), findsNothing);

    handle.dispose();
  });

  testWidgets('按压态：底色切换并缩至 0.94，取消后复位', (tester) async {
    await openWelcome(tester);

    final scheme = AppTheme.light().colorScheme;
    final hitCenter = closeHitRect(tester).center;
    final gesture = await tester.startGesture(hitCenter);
    await tester.pump(const Duration(milliseconds: 150));

    BoxDecoration? decoration() => tester
        .widget<Container>(find.byKey(welcomeDialogCloseVisualKey))
        .decoration as BoxDecoration?;
    AnimatedScale scale() => tester.widget<AnimatedScale>(
          find.descendant(
            of: find.byKey(welcomeDialogCloseKey),
            matching: find.byType(AnimatedScale),
          ),
        );

    expect(decoration()?.color, scheme.surfaceContainer);
    expect(scale().scale, 0.94);
    // 圆心不动：位置只由布局决定，缩放不改变矩形
    final card = dialogSurfaceRect(tester);
    expect(closeVisualRect(tester).center.dx, closeTo(card.right, 1.0));
    expect(closeVisualRect(tester).center.dy, closeTo(card.top, 1.0));

    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(decoration()?.color, scheme.surface);
    expect(scale().scale, 1.0);
    expect(find.byType(WelcomeDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('AC-5：角标图标与底色对比度均 ≥ 3:1（浅/深/按压）', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final scheme = theme.colorScheme;
      final fill = theme.brightness == Brightness.dark
          ? scheme.surfaceContainerHigh
          : scheme.surface;
      expect(
        contrastRatio(scheme.onSurface, fill),
        greaterThanOrEqualTo(3.0),
        reason: 'default fill ${theme.brightness}',
      );
      expect(
        contrastRatio(scheme.onSurface, scheme.surfaceContainer),
        greaterThanOrEqualTo(3.0),
        reason: 'pressed fill ${theme.brightness}',
      );
    }
  });

  testWidgets('浅色角标底色取 surface（#FFFFFF）', (tester) async {
    await openWelcome(tester);
    final decoration = tester
        .widget<Container>(find.byKey(welcomeDialogCloseVisualKey))
        .decoration as BoxDecoration?;
    expect(decoration?.color, AppTheme.light().colorScheme.surface);
    expect(tester.takeException(), isNull);
  });

  testWidgets('深色角标底色取 surfaceContainerHigh（#262B36）', (tester) async {
    await openWelcome(tester, theme: AppTheme.dark());
    final decoration = tester
        .widget<Container>(find.byKey(welcomeDialogCloseVisualKey))
        .decoration as BoxDecoration?;
    expect(
      decoration?.color,
      AppTheme.dark().colorScheme.surfaceContainerHigh,
    );
    expect(tester.takeException(), isNull);
  });

  group('主按钮右箭头图标（REQ-1～REQ-4）', () {
    Icon startIcon(WidgetTester tester) =>
        tester.widget<Icon>(find.byKey(welcomeDialogStartIconKey));

    Color? startTextColor(WidgetTester tester, String label) =>
        DefaultTextStyle.of(tester.element(find.text(label))).style.color;

    /// AC-3：图标与文字均在按钮矩形内、不重叠、图标不缩放。
    void expectStartContentInsideButton(WidgetTester tester, String label) {
      final buttonRect = tester.getRect(find.byKey(_startKey));
      final iconRect = tester.getRect(find.byKey(welcomeDialogStartIconKey));
      final textRect = tester.getRect(find.text(label));

      expect(
        iconRect.size,
        const Size(welcomeStartIconSize, welcomeStartIconSize),
        reason: '图标固定 20dp，不随字号缩放',
      );

      for (final rect in [iconRect, textRect]) {
        expect(rect.left, greaterThanOrEqualTo(buttonRect.left - 0.5));
        expect(rect.right, lessThanOrEqualTo(buttonRect.right + 0.5));
        expect(rect.top, greaterThanOrEqualTo(buttonRect.top - 0.5));
        expect(rect.bottom, lessThanOrEqualTo(buttonRect.bottom + 0.5));
      }

      // 不重叠：图标在文字左侧，间距 8dp
      expect(iconRect.right, lessThanOrEqualTo(textRect.left + 0.5));
      expect(textRect.left - iconRect.right, closeTo(welcomeStartIconGap, 0.5));
      // 垂直居中（多行时图标随文字块居中）
      expect(
        (iconRect.center.dy - textRect.center.dy).abs(),
        lessThanOrEqualTo(1.0),
      );
    }

    testWidgets('AC-1/AC-2：20dp 实心右箭头位于文字左侧，同色、垂直居中、整组居中', (
      tester,
    ) async {
      await openWelcome(tester);

      final icon = startIcon(tester);
      expect(icon.icon, Icons.arrow_forward);
      expect(icon.size, welcomeStartIconSize);
      expect(icon.color, AppTheme.light().colorScheme.onPrimary);
      expect(icon.color, const Color(0xFFFFFFFF));

      final iconRect = tester.getRect(find.byKey(welcomeDialogStartIconKey));
      final textRect = tester.getRect(find.text('开始使用'));
      final buttonRect = tester.getRect(find.byKey(_startKey));

      expect(iconRect.size, const Size(20, 20));
      expect(iconRect.right, lessThanOrEqualTo(textRect.left));
      expect(textRect.left - iconRect.right, closeTo(welcomeStartIconGap, 0.5));
      expect(
        (iconRect.center.dy - textRect.center.dy).abs(),
        lessThanOrEqualTo(1.0),
      );

      // 图标+文字作为一组在按钮内容区居中
      final groupCenter = (iconRect.left + textRect.right) / 2;
      expect(
        (groupCenter - buttonRect.center.dx).abs(),
        lessThanOrEqualTo(1.0),
        reason: '图标+文字整组未居中',
      );

      // 图标与文字同色（AC-2）
      expect(startTextColor(tester, '开始使用'), icon.color);

      // 1x 下按钮高度仍为 48（A-3 / AC-10）
      expect(buttonRect.height, closeTo(48, 1.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AC-4：深色主题图标取 onPrimary（#0A1F5C），与文字同色', (tester) async {
      await openWelcome(tester, theme: AppTheme.dark());

      final icon = startIcon(tester);
      expect(icon.color, AppTheme.dark().colorScheme.onPrimary);
      expect(icon.color, const Color(0xFF0A1F5C));
      expect(startTextColor(tester, '开始使用'), icon.color);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AC-9：英文下箭头同样在文字左侧，文案为 Get started', (tester) async {
      await openWelcome(tester, locale: const Locale('en'));

      final icon = startIcon(tester);
      expect(icon.icon, Icons.arrow_forward);
      expect(icon.color, const Color(0xFFFFFFFF));
      expect(find.text('Get started'), findsOneWidget);

      final iconRect = tester.getRect(find.byKey(welcomeDialogStartIconKey));
      final textRect = tester.getRect(find.text('Get started'));
      final buttonRect = tester.getRect(find.byKey(_startKey));

      expect(iconRect.right, lessThanOrEqualTo(textRect.left));
      expect(textRect.left - iconRect.right, closeTo(welcomeStartIconGap, 0.5));
      expect(
        (iconRect.center.dy - textRect.center.dy).abs(),
        lessThanOrEqualTo(1.0),
      );
      expect(
        (((iconRect.left + textRect.right) / 2) - buttonRect.center.dx).abs(),
        lessThanOrEqualTo(1.0),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AC-8：图标不进语义树，按钮可访问名称仍为「开始使用」', (tester) async {
      final handle = tester.ensureSemantics();
      await openWelcome(tester);

      final buttonNode = tester.getSemantics(find.byKey(_startKey));
      expect(buttonNode.getSemanticsData().label, '开始使用');
      expect(buttonNode.getSemanticsData().flagsCollection.isButton, isTrue);

      // 图标没有独立语义节点：查询图标命中的是最近的祖先（按钮）节点
      final iconNode = tester.getSemantics(
        find.byKey(welcomeDialogStartIconKey),
      );
      expect(
        identical(iconNode, buttonNode),
        isTrue,
        reason: '图标产生了独立语义节点',
      );
      expect(
        find.bySemanticsLabel(RegExp('arrow', caseSensitive: false)),
        findsNothing,
        reason: '箭头不应被读屏朗读',
      );

      handle.dispose();
    });

    testWidgets('AC-8：英文下可访问名称仍为 Get started', (tester) async {
      final handle = tester.ensureSemantics();
      await openWelcome(tester, locale: const Locale('en'));

      final data = tester
          .getSemantics(find.byKey(_startKey))
          .getSemanticsData();
      expect(data.label, 'Get started');

      handle.dispose();
    });

    testWidgets('AC-5：点图标中心即点按钮，返回 button 且只关闭一次', (tester) async {
      final closing = await openWelcome(tester);
      final iconCenter = tester.getCenter(
        find.byKey(welcomeDialogStartIconKey),
      );

      await tester.tapAt(iconCenter);
      await tester.tapAt(iconCenter);
      await tester.pumpAndSettle();

      expect(await closing, WelcomeDismissMethod.button);
      expect(find.byType(WelcomeDialog), findsNothing);
      expect(find.text('打开弹窗'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AC-3：320dp + 2x 中文，图标与文字不截断、不重叠、不越界', (tester) async {
      await openWelcome(
        tester,
        logicalSize: const Size(320, 640),
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
      expectStartContentInsideButton(tester, '开始使用');
    });

    testWidgets('AC-3：320dp + 2x 英文，图标与文字不截断、不重叠、不越界', (tester) async {
      await openWelcome(
        tester,
        logicalSize: const Size(320, 640),
        textScale: 2.0,
        locale: const Locale('en'),
      );

      expect(tester.takeException(), isNull);
      expectStartContentInsideButton(tester, 'Get started');
    });
  });

  group('说明行（REQ-1～REQ-5）', () {
    const zhHint = '随时可以在设置里改 AI 配置';
    const enHint = 'You can change your AI config anytime in Settings.';

    testWidgets('AC-1/13/17：主标题 → 说明行 → 副标题，间距 6/12，水平居中，副标题不变', (
      tester,
    ) async {
      await openWelcome(tester);

      final dialogRect = dialogSurfaceRect(tester);
      final titleRect = tester.getRect(find.byKey(_titleKey));
      final hint = hintRect(tester);
      final subtitleRect = tester.getRect(find.byKey(_subtitleKey));

      // 纵向顺序与相邻不重叠
      expect(titleRect.bottom, lessThanOrEqualTo(hint.top + 0.5));
      expect(hint.bottom, lessThanOrEqualTo(subtitleRect.top + 0.5));
      expect(hint.overlaps(titleRect), isFalse);
      expect(hint.overlaps(subtitleRect), isFalse);

      // 间距 6 / 12
      expect(hint.top - titleRect.bottom, closeTo(welcomeHintTitleGap, 0.5));
      expect(
        subtitleRect.top - hint.bottom,
        closeTo(welcomeHintSubtitleGap, 0.5),
      );

      // 水平居中，与主标题中心偏差 ≤ 1dp
      expect(hint.center.dx, closeTo(dialogRect.center.dx, 1.0));
      expect(hint.center.dx, closeTo(titleRect.center.dx, 1.0));

      // 副标题文案/字号/颜色保持既有实现
      final subtitle = tester.widget<Text>(find.byKey(_subtitleKey));
      expect(subtitle.data, '说一句话，让手机替你做事。');
      expect(subtitle.style?.fontSize, 15);
      expect(
        subtitle.style?.color,
        AppTheme.light().colorScheme.onSurfaceVariant,
      );
      expect(find.byKey(welcomeDialogAiHintKey), findsOneWidget);
    });

    testWidgets('AC-5/6/7：中英逐字文案，非中英回退中文', (tester) async {
      await openWelcome(tester);
      expect(find.text(zhHint), findsOneWidget);
      expect(find.text('welcomeAiHint'), findsNothing);
      expect(hintText(tester).data, zhHint);

      // 关闭后再以另一语言重建，避免旧路由遮住入口
      await tester.tap(find.byKey(_startKey));
      await tester.pumpAndSettle();

      await openWelcome(tester, locale: const Locale('en'));
      expect(find.text(enHint), findsOneWidget);
      expect(find.text(zhHint), findsNothing);
      expect(find.text('welcomeAiHint'), findsNothing);
      expect(hintText(tester).data, enHint);

      await tester.tap(find.byKey(_startKey));
      await tester.pumpAndSettle();

      await openWelcome(tester, locale: const Locale('fr'));
      expect(find.text(zhHint), findsOneWidget);
      expect(hintText(tester).data, zhHint);
    });

    testWidgets('AC-8：默认字号 13sp、400、行高 1.4、渲染行高 18.2', (tester) async {
      await openWelcome(tester);

      final text = hintText(tester);
      expect(text.style?.fontSize, welcomeHintFontSize);
      expect(text.style?.fontSize, 13);
      expect(text.style?.fontWeight, FontWeight.w400);
      expect(text.style?.height, 1.4);
      expect(text.textAlign, TextAlign.center);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);

      final paragraph = tester.renderObject<RenderParagraph>(
        find.byKey(welcomeDialogAiHintKey),
      );
      expect(paragraph.textScaler.scale(welcomeHintFontSize), 13);
      expect(paragraph.preferredLineHeight, closeTo(13 * 1.4, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AC-10：2 倍线性缩放渲染 26sp、行高 36.4', (tester) async {
      await openWelcome(tester, textScale: 2.0);

      final text = hintText(tester);
      expect(text.style?.fontSize, welcomeHintFontSize);

      final paragraph = tester.renderObject<RenderParagraph>(
        find.byKey(welcomeDialogAiHintKey),
      );
      expect(paragraph.textScaler.scale(welcomeHintFontSize), 26);
      expect(paragraph.preferredLineHeight, closeTo(26 * 1.4, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AC-9：浅色取 #5B6270、深色取 #A6ADBB，对比度均 ≥ 4.5', (tester) async {
      await openWelcome(tester);
      final lightScheme = AppTheme.light().colorScheme;
      expect(hintText(tester).style?.color, lightScheme.onSurfaceVariant);
      expect(hintText(tester).style?.color, const Color(0xFF5B6270));
      expect(
        contrastRatio(lightScheme.onSurfaceVariant, lightScheme.surface),
        greaterThanOrEqualTo(4.5),
      );

      await tester.tap(find.byKey(_startKey));
      await tester.pumpAndSettle();

      await openWelcome(tester, theme: AppTheme.dark());
      final darkScheme = AppTheme.dark().colorScheme;
      expect(hintText(tester).style?.color, darkScheme.onSurfaceVariant);
      expect(hintText(tester).style?.color, const Color(0xFFA6ADBB));
      expect(
        contrastRatio(darkScheme.onSurfaceVariant, darkScheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AC-11：320dp 窄屏宽 232、无横向溢出、不截断', (tester) async {
      await openWelcome(tester, logicalSize: const Size(320, 640));

      expect(tester.takeException(), isNull);
      final dialogRect = dialogSurfaceRect(tester);
      final hint = hintRect(tester);

      expect(dialogRect.width, closeTo(280, 1.0));
      expect(hint.width, closeTo(232, 1.0));
      expect(hint.left, greaterThanOrEqualTo(dialogRect.left));
      expect(hint.right, lessThanOrEqualTo(dialogRect.right));
      // 中文 1 行；无省略号/最大行数
      expect(hint.height, closeTo(13 * 1.4, 0.5));
      expect(hintText(tester).maxLines, isNull);
      expect(hintText(tester).overflow, isNull);
      expect(
        find.descendant(
          of: find.byKey(_scrollKey),
          matching: find.byKey(welcomeDialogAiHintKey),
        ),
        findsOneWidget,
      );
    });

    testWidgets('AC-11/R2：320dp 英文 + 2 倍字号仍换行、可滚、主按钮可点', (tester) async {
      final closing = await openWelcome(
        tester,
        locale: const Locale('en'),
        logicalSize: const Size(320, 640),
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
      final hint = hintRect(tester);
      expect(hint.width, closeTo(232, 1.0));
      // 26sp 英文在 232dp 宽下至少 2 行：高度必须大于单行的 36.4dp
      expect(hint.height, greaterThan(26 * 1.4 + 0.5));
      expect(hintText(tester).maxLines, isNull);
      expect(hintText(tester).overflow, isNull);
      expect(
        find.descendant(
          of: find.byKey(_scrollKey),
          matching: find.byKey(welcomeDialogAiHintKey),
        ),
        findsOneWidget,
      );

      // 大字 + 长英文超出弹窗最大高度时由既有滚动容器承载
      final state = scrollState(tester);
      expect(state.position.maxScrollExtent, greaterThan(0));

      final buttonRect = tester.getRect(find.byKey(_startKey));
      expect(buttonRect.top, greaterThanOrEqualTo(0));
      expect(buttonRect.bottom, lessThanOrEqualTo(640));
      expect(buttonRect.height, greaterThanOrEqualTo(48));

      await tester.tap(find.byKey(_startKey));
      await tester.pumpAndSettle();
      expect(await closing, WelcomeDismissMethod.button);
    });

    testWidgets('AC-12：2 倍字号 360×640 内容可滚、主按钮完整可点', (tester) async {
      final closing = await openWelcome(
        tester,
        textScale: 2.0,
        logicalSize: const Size(360, 640),
      );

      expect(tester.takeException(), isNull);
      final state = scrollState(tester);
      expect(state.position.maxScrollExtent, greaterThan(0));

      final buttonRect = tester.getRect(find.byKey(_startKey));
      expect(buttonRect.top, greaterThanOrEqualTo(0));
      expect(buttonRect.bottom, lessThanOrEqualTo(640));
      expect(buttonRect.height, greaterThanOrEqualTo(48));

      await tester.tap(find.byKey(_startKey));
      await tester.pumpAndSettle();
      expect(await closing, WelcomeDismissMethod.button);
    });

    testWidgets('AC-2：滚动时说明行与主标题同步移动，不固定在底部', (tester) async {
      await openWelcome(tester, logicalSize: const Size(640, 400));

      final titleBefore = tester.getRect(find.byKey(_titleKey)).top;
      final hintBefore = hintRect(tester).top;

      // 滚到底（footer 加版本行后可视区变矮，滚动范围随之变大）
      await tester.drag(find.byKey(_scrollKey), const Offset(0, -600));
      await tester.pumpAndSettle();

      final titleDelta = tester.getRect(find.byKey(_titleKey)).top - titleBefore;
      final hintDelta = hintRect(tester).top - hintBefore;
      expect(titleDelta, lessThan(0));
      expect((titleDelta - hintDelta).abs(), lessThanOrEqualTo(1.0));

      final scrollRect = tester.getRect(find.byKey(_scrollKey));
      expect(hintRect(tester).bottom, lessThanOrEqualTo(scrollRect.bottom + 0.5));
      expect(
        find.descendant(
          of: find.byKey(_scrollKey),
          matching: find.byKey(welcomeDialogAiHintKey),
        ),
        findsOneWidget,
      );
    });

    testWidgets('AC-14/15：关闭时与主标题共享同一淡出，无新增动画段', (tester) async {
      await openWelcome(tester);

      List<FadeTransition> fadesOf(Element element) {
        final fades = <FadeTransition>[];
        element.visitAncestorElements((ancestor) {
          if (ancestor.widget is FadeTransition) {
            fades.add(ancestor.widget as FadeTransition);
          }
          return true;
        });
        return fades;
      }

      final titleElement = tester.element(find.byKey(_titleKey));
      final hintElement = tester.element(find.byKey(welcomeDialogAiHintKey));
      final titleFades = fadesOf(titleElement);
      final hintFades = fadesOf(hintElement);

      expect(hintFades, isNotEmpty, reason: '说明行不在路由过渡中');
      expect(hintFades.length, titleFades.length);
      for (var i = 0; i < hintFades.length; i++) {
        expect(identical(hintFades[i], titleFades[i]), isTrue);
      }
      // 弹窗自身不新增淡出节点
      expect(
        find.descendant(
          of: find.byType(WelcomeDialog),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );

      // 不再断言 Flutter DialogRoute 的默认时长：本仓库未声明该值，
      // 关键契约是说明行与主标题共享同一个路由过渡、弹窗内无新增淡出节点。
      // 关闭总时长仍由「同一路由 + 无新增动画段」保证与改动前一致。

      await tester.tap(find.byKey(_startKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // 动画中途两者透明度相同且处于过渡中
      final hintOpacity = fadesOf(
        tester.element(find.byKey(welcomeDialogAiHintKey)),
      ).first.opacity.value;
      final titleOpacity = fadesOf(
        tester.element(find.byKey(_titleKey)),
      ).first.opacity.value;
      expect(hintOpacity, titleOpacity);
      expect(hintOpacity, greaterThan(0));
      expect(hintOpacity, lessThan(1));

      await tester.pumpAndSettle();
      expect(find.byType(WelcomeDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AC-16：点击/长按说明行无交互，语义不是按钮', (tester) async {
      final handle = tester.ensureSemantics();
      final closing = await openWelcome(tester);
      final hintFinder = find.byKey(welcomeDialogAiHintKey);

      final data = tester.getSemantics(hintFinder).getSemanticsData();
      expect(data.label, '随时可以在设置里改 AI 配置');
      expect(data.flagsCollection.isButton, isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);

      await tester.tap(hintFinder);
      await tester.longPress(hintFinder);
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeDialog), findsOneWidget);
      expect(tester.takeException(), isNull);

      handle.dispose();
      // 清理：避免未完成的 closing 影响后续用例
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(await closing, isNull);
    });

    testWidgets('AC-21：无欢迎图时说明行仍显示且不与关闭按钮相交', (tester) async {
      await openWelcome(tester, heroAssetOverride: '');

      expect(tester.takeException(), isNull);
      expect(find.byKey(_heroKey), findsNothing);
      expect(find.byKey(welcomeDialogAiHintKey), findsOneWidget);

      final hint = hintRect(tester);
      final hit = closeHitRect(tester);
      final visual = closeVisualRect(tester);
      expect(hint.overlaps(hit), isFalse);
      expect(hint.overlaps(visual), isFalse);
      expect(hint.top, greaterThan(hit.bottom));
    });
  });

  group('版本行（REQ-1～REQ-6）', () {
    Rect versionRect(WidgetTester tester) =>
        tester.getRect(find.byKey(welcomeDialogVersionKey));

    Text versionText(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(welcomeDialogVersionKey));

    List<FadeTransition> fadesOf(Element element) {
      final fades = <FadeTransition>[];
      element.visitAncestorElements((ancestor) {
        if (ancestor.widget is FadeTransition) {
          fades.add(ancestor.widget as FadeTransition);
        }
        return true;
      });
      return fades;
    }

    /// AC-4/AC-5：居中、宽满内容区、上 8 下 20，且在滚动区之外。
    void expectVersionLayout(WidgetTester tester) {
      final card = dialogSurfaceRect(tester);
      final version = versionRect(tester);
      final primary = tester.getRect(find.byKey(_startKey));

      expect(version.center.dx, closeTo(card.center.dx, 1.0));
      expect(version.width, closeTo(card.width - 40, 0.5));
      expect(version.left, closeTo(card.left + 20, 0.5));
      expect(version.right, closeTo(card.right - 20, 0.5));
      expect(version.top - primary.bottom, closeTo(8, 1.0));
      expect(card.bottom - version.bottom, closeTo(20, 1.0));
      expect(version.top, greaterThan(primary.top));
      expect(version.overlaps(primary), isFalse);
      expect(
        find.descendant(
          of: find.byKey(_scrollKey),
          matching: find.byKey(welcomeDialogVersionKey),
        ),
        findsNothing,
        reason: '版本行不应进入可滚动内容区',
      );
      expect(tester.takeException(), isNull);
    }

    testWidgets('AC-1/AC-9：弹窗第一帧就显示完整版本号', (tester) async {
      final closing = await openWelcome(tester, settle: false);

      // 只推进一帧：路由过渡仍在进行，文本已就绪、非空、无占位符。
      final version = versionText(tester);
      expect(version.data, 'v0.1.0');
      expect(version.data, isNotEmpty);
      expect(find.text('v0.1.0'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('v0.1.0'), findsOneWidget);

      await tester.tap(find.byKey(_startKey));
      await tester.pumpAndSettle();
      expect(await closing, WelcomeDismissMethod.button);
    });

    testWidgets('AC-2：注入回退文本 v1.0.0 时弹窗正常展示且可关闭', (tester) async {
      final closing = await openWelcome(
        tester,
        versionLabel: fallbackAppVersionLabel,
      );

      expect(find.text('v1.0.0'), findsOneWidget);
      expect(find.byType(WelcomeDialog), findsOneWidget);
      expect(find.byKey(_startKey), findsOneWidget);

      await tester.tap(find.byKey(_startKey));
      await tester.pumpAndSettle();
      expect(await closing, WelcomeDismissMethod.button);
    });

    testWidgets('AC-3：中英文显示同一版本文本，无翻译缺失/占位符', (tester) async {
      await openWelcome(tester);
      expect(versionText(tester).data, 'v0.1.0');
      expect(find.text('welcomeDialogVersion'), findsNothing);

      await tester.tap(find.byKey(_startKey));
      await tester.pumpAndSettle();

      await openWelcome(tester, locale: const Locale('en'));
      expect(versionText(tester).data, 'v0.1.0');
      expect(find.text('v0.1.0'), findsOneWidget);
      expect(find.text('v'), findsNothing);
    });

    testWidgets('AC-4：已配置 AI（单按钮）时居中、宽满内容区、上 8 下 20',
        (tester) async {
      await openWelcome(tester, showConfigureAi: false);

      expect(find.byKey(_configureAiKey), findsNothing);
      expectVersionLayout(tester);
    });

    testWidgets('AC-5：未配置 AI（双按钮）时仍在主按钮下方最底部，不与按钮重叠',
        (tester) async {
      await openWelcome(tester, showConfigureAi: true);

      final version = versionRect(tester);
      final primary = tester.getRect(find.byKey(_startKey));
      final secondary = tester.getRect(find.byKey(_configureAiKey));

      expect(find.byKey(_configureAiKey), findsOneWidget);
      expect(version.overlaps(secondary), isFalse);
      expect(version.top, greaterThan(secondary.bottom));
      expect(version.top, greaterThan(primary.bottom));
      expectVersionLayout(tester);
    });

    testWidgets('AC-6：14sp / w400 / 行高 1.4，颜色取 onSurfaceVariant',
        (tester) async {
      await openWelcome(tester);

      final lightScheme = AppTheme.light().colorScheme;
      final text = versionText(tester);
      expect(text.style?.fontSize, 14);
      expect(text.style?.fontWeight, FontWeight.w400);
      expect(text.style?.height, 1.4);
      expect(text.textAlign, TextAlign.center);
      expect(text.style?.color, lightScheme.onSurfaceVariant);
      expect(text.style?.color, const Color(0xFF5B6270));
      expect(AppTypography.version.fontSize, 14);
      expect(AppTypography.version.fontWeight, FontWeight.w400);
      expect(AppTypography.version.height, 1.4);
      // 1.0 倍：行盒 = 14 × 1.4
      expect(versionRect(tester).height, closeTo(14 * 1.4, 0.5));

      await tester.tap(find.byKey(_startKey));
      await tester.pumpAndSettle();

      await openWelcome(tester, theme: AppTheme.dark());
      final darkScheme = AppTheme.dark().colorScheme;
      expect(versionText(tester).style?.color, darkScheme.onSurfaceVariant);
      expect(versionText(tester).style?.color, const Color(0xFFA6ADBB));
      expect(
        contrastRatio(darkScheme.onSurfaceVariant, darkScheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AC-7：2 倍字号渲染 28sp、行盒 39.2、单行不横向溢出',
        (tester) async {
      await openWelcome(tester, textScale: 2.0);

      final paragraph = tester.renderObject<RenderParagraph>(
        find.byKey(welcomeDialogVersionKey),
      );
      expect(paragraph.textScaler.scale(14), 28);
      expect(paragraph.preferredLineHeight, closeTo(28 * 1.4, 0.5));
      expect(versionRect(tester).height, closeTo(28 * 1.4, 0.5));
      expect(paragraph.didExceedMaxLines, isFalse);

      final card = dialogSurfaceRect(tester);
      final version = versionRect(tester);
      expect(version.width, closeTo(card.width - 40, 0.5));
      expect(version.left, greaterThanOrEqualTo(card.left));
      expect(version.right, lessThanOrEqualTo(card.right));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AC-8：320dp 超长版本号单行末尾省略，不撑破卡片', (tester) async {
      const longLabel =
          'v10.24.0-beta.20250612.22591.abcdefghijklmnopqrstuvwxyz';
      await openWelcome(
        tester,
        logicalSize: const Size(320, 640),
        versionLabel: longLabel,
      );

      expect(tester.takeException(), isNull);
      final text = versionText(tester);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.softWrap, isFalse);

      final paragraph = tester.renderObject<RenderParagraph>(
        find.byKey(welcomeDialogVersionKey),
      );
      expect(paragraph.didExceedMaxLines, isTrue);

      final card = dialogSurfaceRect(tester);
      final version = versionRect(tester);
      expect(card.width, closeTo(280, 1.0));
      expect(version.width, closeTo(card.width - 40, 0.5));
      expect(version.left, greaterThanOrEqualTo(card.left));
      expect(version.right, lessThanOrEqualTo(card.right));
      expect(version.height, closeTo(14 * 1.4, 0.5));
    });

    testWidgets('AC-10：小高度滚动时版本行固定在 footer，不随内容滚出', (tester) async {
      await openWelcome(tester, logicalSize: const Size(640, 400));

      final state = scrollState(tester);
      expect(state.position.maxScrollExtent, greaterThan(0));

      final card = dialogSurfaceRect(tester);
      final before = versionRect(tester);
      await tester.drag(find.byKey(_scrollKey), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(state.position.pixels, state.position.maxScrollExtent);
      final after = versionRect(tester);
      expect(after.top, closeTo(before.top, 0.5));
      expect(after.left, closeTo(before.left, 0.5));
      expect(after.bottom, closeTo(before.bottom, 0.5));
      expect(after.top, greaterThanOrEqualTo(card.top));
      expect(after.bottom, lessThanOrEqualTo(card.bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('AC-11：与主标题共享同一 FadeTransition，弹窗内无新增淡出节点',
        (tester) async {
      await openWelcome(tester);

      final titleFades = fadesOf(tester.element(find.byKey(_titleKey)));
      final versionFades = fadesOf(
        tester.element(find.byKey(welcomeDialogVersionKey)),
      );

      expect(versionFades, isNotEmpty, reason: '版本行不在路由过渡中');
      expect(versionFades.length, titleFades.length);
      for (var i = 0; i < versionFades.length; i++) {
        expect(identical(versionFades[i], titleFades[i]), isTrue);
      }
      expect(
        find.descendant(
          of: find.byType(WelcomeDialog),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(_startKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      final versionOpacity = fadesOf(
        tester.element(find.byKey(welcomeDialogVersionKey)),
      ).first.opacity.value;
      final titleOpacity = fadesOf(
        tester.element(find.byKey(_titleKey)),
      ).first.opacity.value;
      expect(versionOpacity, titleOpacity);
      expect(versionOpacity, greaterThan(0));
      expect(versionOpacity, lessThan(1));

      await tester.pumpAndSettle();
      expect(find.byType(WelcomeDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AC-12：四种关闭方式后版本行不残留', (tester) async {
      var closing = await openWelcome(tester);
      await tester.tap(find.byKey(_startKey));
      await tester.pumpAndSettle();
      expect(find.byKey(welcomeDialogVersionKey), findsNothing);
      expect(await closing, WelcomeDismissMethod.button);

      closing = await openWelcome(tester);
      await tester.tap(find.byKey(welcomeDialogCloseKey));
      await tester.pumpAndSettle();
      expect(find.byKey(welcomeDialogVersionKey), findsNothing);
      expect(await closing, WelcomeDismissMethod.closeButton);

      closing = await openWelcome(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(welcomeDialogVersionKey), findsNothing);
      expect(await closing, isNull);

      closing = await openWelcome(tester, showConfigureAi: true);
      await tester.tap(find.byKey(_configureAiKey));
      await tester.pumpAndSettle();
      expect(find.byKey(welcomeDialogVersionKey), findsNothing);
      expect(await closing, WelcomeDismissMethod.configureAi);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AC-13：语义为普通文本，读出完整版本号且不是按钮', (tester) async {
      final handle = tester.ensureSemantics();
      await openWelcome(tester);

      final data = tester
          .getSemantics(find.byKey(welcomeDialogVersionKey))
          .getSemanticsData();
      expect(data.label, 'v0.1.0');
      expect(data.flagsCollection.isButton, isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(data.hasAction(SemanticsAction.longPress), isFalse);

      handle.dispose();
    });

    testWidgets('AC-14：点击/长按版本行无操作，弹窗保持打开', (tester) async {
      final closing = await openWelcome(tester);

      await tester.tap(find.byKey(welcomeDialogVersionKey));
      await tester.longPress(find.byKey(welcomeDialogVersionKey));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeDialog), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(await closing, isNull);
    });

    testWidgets('AC-15：640×400 + 2 倍字号，版本行完整可见、单行、不与按钮重叠',
        (tester) async {
      await openWelcome(
        tester,
        logicalSize: const Size(640, 400),
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
      final card = dialogSurfaceRect(tester);
      final version = versionRect(tester);
      final primary = tester.getRect(find.byKey(_startKey));

      expect(card.height, lessThanOrEqualTo(400 * 0.8 + 0.5));
      expect(version.top, greaterThan(primary.bottom + 7));
      expect(version.overlaps(primary), isFalse);
      expect(version.left, greaterThanOrEqualTo(card.left));
      expect(version.right, lessThanOrEqualTo(card.right));
      expect(version.top, greaterThanOrEqualTo(card.top));
      expect(version.bottom, lessThanOrEqualTo(card.bottom + 0.5));
      expect(version.height, closeTo(28 * 1.4, 0.5));

      final paragraph = tester.renderObject<RenderParagraph>(
        find.byKey(welcomeDialogVersionKey),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(scrollState(tester).position.maxScrollExtent, greaterThan(0));
    });
  });

  test('两张欢迎图均为 1280×640（2:1）', () {
    for (final name in const [
      'welcome_hero_light.png',
      'welcome_hero_dark.png',
    ]) {
      final size = readPngSize('assets/images/$name');
      expect(size.width, 1280, reason: name);
      expect(size.height, 640, reason: name);
      expect(
        size.width / size.height,
        closeTo(welcomeHeroAspectRatio, 0.001),
        reason: name,
      );
    }
  });
}

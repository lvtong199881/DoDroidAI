import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

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
  String? heroAssetOverride,
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
  await tester.pumpAndSettle();
  expect(find.byType(WelcomeDialog), findsOneWidget);
  return closing!;
}

/// Dialog 自身的布局盒是全屏的，视觉弹窗矩形取内部 Material。
Rect dialogSurfaceRect(WidgetTester tester) {
  final material = find
      .descendant(of: find.byType(Dialog), matching: find.byType(Material))
      .first;
  return tester.getRect(material);
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

    // 没有右上角关闭按钮，底部按钮仍在
    expect(find.byIcon(Icons.close), findsNothing);
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

  testWidgets('欢迎图仅顶部 16dp 圆角，弹窗按圆角裁切', (tester) async {
    await openWelcome(tester);

    final clip = tester.widget<ClipRRect>(find.byKey(_heroKey));
    expect(
      clip.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(16)),
    );

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.clipBehavior, Clip.antiAlias);
    expect(dialog.shape, isA<RoundedRectangleBorder>());
    expect(
      (dialog.shape as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(16),
    );
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

  testWidgets('浅色主题弹窗背景为 #FFFFFF', (tester) async {
    await openWelcome(tester, theme: AppTheme.light());

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, const Color(0xFFFFFFFF));
    expect(dialog.shape, isA<RoundedRectangleBorder>());
  });

  testWidgets('深色主题弹窗背景为 #161920', (tester) async {
    await openWelcome(tester, theme: AppTheme.dark());

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, const Color(0xFF161920));
  });

  testWidgets('文字不设 maxLines/ellipsis，不覆盖系统字号', (tester) async {
    await openWelcome(tester, textScale: 2.0);

    final texts = tester.widgetList<Text>(
      find.descendant(
        of: find.byType(WelcomeDialog),
        matching: find.byType(Text),
      ),
    );
    expect(texts, isNotEmpty);
    for (final text in texts) {
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
    }
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
    expect(dialogRect.width, lessThanOrEqualTo(320));

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

    // footer 高度 = 上 12 + 48 + 8 + 48 + 下 20 = 136
    expect(footerHeight(tester), closeTo(136, 0.5));

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

  testWidgets('已配置：无次要按钮、无额外占位（footer 仍 80）', (tester) async {
    await openWelcome(tester, showConfigureAi: false);

    final dialogRect = dialogSurfaceRect(tester);
    final primaryRect = tester.getRect(find.byKey(_startKey));

    expect(find.byKey(_configureAiKey), findsNothing);
    expect(find.text('去配置AI'), findsNothing);
    // 未配置时 footer 为 136（多一个 48 按钮 + 8 间距），已配置必须回到 80
    expect(footerHeight(tester), closeTo(80, 0.5));
    // 主按钮贴底：48 + 下内边距 20
    expect(primaryRect.bottom, closeTo(dialogRect.bottom - 20, 0.5));
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

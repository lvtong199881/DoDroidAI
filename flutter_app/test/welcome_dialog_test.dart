import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/l10n/app_strings.dart';
import 'package:dodroidai/settings/welcome_contract.dart';
import 'package:dodroidai/theme/app_theme.dart';
import 'package:dodroidai/widgets/welcome_dialog.dart';

/// 打开弹窗并返回「关闭时才会完成」的 Future。
Future<Future<WelcomeDismissMethod?>> openWelcome(
  WidgetTester tester, {
  Locale locale = const Locale('zh'),
  ThemeData? theme,
  Size logicalSize = const Size(360, 800),
  double textScale = 1.0,
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
                  builder: (_) => const WelcomeDialog(),
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

void main() {
  testWidgets('中文展示全部定稿内容且没有右上角关闭按钮', (tester) async {
    await openWelcome(tester);

    final strings = AppStrings(const Locale('zh'));
    for (final key in const [
      'welcomeTitle',
      'welcomeIntro',
      'welcomeFeat1Title',
      'welcomeFeat1Desc',
      'welcomeFeat2Title',
      'welcomeFeat2Desc',
      'welcomeFeat3Title',
      'welcomeFeat3Desc',
      'welcomeStart',
    ]) {
      expect(find.text(strings.t(key)), findsOneWidget, reason: key);
    }
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('英文展示全部定稿内容', (tester) async {
    await openWelcome(tester, locale: const Locale('en'));

    final strings = AppStrings(const Locale('en'));
    expect(find.text('Welcome to DoDroidAI'), findsOneWidget);
    expect(find.text(strings.t('welcomeFeat1Desc')), findsOneWidget);
    expect(find.text(strings.t('welcomeStart')), findsOneWidget);
    expect(find.text('开始使用'), findsNothing);
  });

  testWidgets('遮罩点击不关闭，主按钮关闭并回到首页', (tester) async {
    final closing = await openWelcome(tester);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeDialog), findsOneWidget);

    // 模态遮罩不可 dismiss（AC-19）
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

  testWidgets('2.0 倍字号：内容可滚动、按钮固定可见、无溢出', (tester) async {
    final closing = await openWelcome(tester, textScale: 2.0);

    expect(tester.takeException(), isNull);

    final dialogRect = dialogSurfaceRect(tester);
    expect(dialogRect.height, lessThanOrEqualTo(800 * 0.8 + 0.5));

    final buttonRect = tester.getRect(
      find.widgetWithText(FilledButton, '开始使用'),
    );
    expect(buttonRect.top, greaterThanOrEqualTo(0));
    expect(buttonRect.bottom, lessThanOrEqualTo(800));

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      greaterThan(0),
    );

    // 第三条卖点在滚动后可见
    expect(find.text(AppStrings(const Locale('zh')).t('welcomeFeat3Title')),
        findsOneWidget);

    await tester.tap(find.text('开始使用'));
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

    final buttonRect = tester.getRect(
      find.widgetWithText(FilledButton, '开始使用'),
    );
    expect(buttonRect.left, greaterThanOrEqualTo(0));
    expect(buttonRect.right, lessThanOrEqualTo(320));
    expect(buttonRect.height, greaterThanOrEqualTo(48));

    await tester.tap(find.text('开始使用'));
    await tester.pumpAndSettle();
    expect(await closing, WelcomeDismissMethod.button);
  });
}

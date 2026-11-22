import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/settings/welcome_contract.dart';
import 'package:dodroidai/settings/welcome_launch_entry.dart';

void main() {
  test('小组件命中返回 widget', () async {
    final resolver = LaunchEntryResolver(
      widgetProbe: () async => Uri(),
      notificationProbe: () async => false,
    );

    expect(await resolver.resolve(), WelcomeEntry.widget);
  });

  test('仅通知命中返回 notification', () async {
    final resolver = LaunchEntryResolver(
      widgetProbe: () async => null,
      notificationProbe: () async => true,
    );

    expect(await resolver.resolve(), WelcomeEntry.notification);
  });

  test('两个探针正常且未命中返回 cold_start', () async {
    final resolver = LaunchEntryResolver(
      widgetProbe: () async => null,
      notificationProbe: () async => false,
    );

    expect(await resolver.resolve(), WelcomeEntry.coldStart);
  });

  test('小组件探针异常且无其他命中返回 other', () async {
    final resolver = LaunchEntryResolver(
      widgetProbe: () async => throw StateError('widget probe failed'),
      notificationProbe: () async => false,
    );

    expect(await resolver.resolve(), WelcomeEntry.other);
  });

  test('通知探针异常且无其他命中返回 other', () async {
    final resolver = LaunchEntryResolver(
      widgetProbe: () async => null,
      notificationProbe: () async => throw StateError('notification probe failed'),
    );

    expect(await resolver.resolve(), WelcomeEntry.other);
  });

  test('小组件命中优先于通知探针异常', () async {
    final resolver = LaunchEntryResolver(
      widgetProbe: () async => Uri.parse('dodroidai://widget'),
      notificationProbe: () async => throw StateError('notification probe failed'),
    );

    expect(await resolver.resolve(), WelcomeEntry.widget);
  });

  test('探针超时降级为 other', () async {
    final resolver = LaunchEntryResolver(
      widgetProbe: () =>
          Future<Uri?>.delayed(const Duration(milliseconds: 500), () => Uri()),
      notificationProbe: () async => false,
      timeout: const Duration(milliseconds: 20),
    );

    expect(await resolver.resolve(), WelcomeEntry.other);
  });

  test('通知探针超时降级为 other', () async {
    final resolver = LaunchEntryResolver(
      widgetProbe: () async => null,
      notificationProbe: () =>
          Future<bool>.delayed(const Duration(milliseconds: 500), () => true),
      timeout: const Duration(milliseconds: 20),
    );

    expect(await resolver.resolve(), WelcomeEntry.other);
  });
}

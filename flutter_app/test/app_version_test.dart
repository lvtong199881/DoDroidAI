import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/app_version.dart';

void main() {
  // 默认 loader 走 package_info_plus 平台通道，需要绑定才能拿到通道异常。
  TestWidgetsFlutterBinding.ensureInitialized();

  group('formatVersionLabel', () {
    test('正常版本号加小写 v 前缀，不拼接 buildNumber', () {
      expect(formatVersionLabel('0.1.0'), 'v0.1.0');
    });

    test('保留版本号原样：预发布后缀与多段版本不补零', () {
      expect(formatVersionLabel('10.24.0-beta.20250612'), 'v10.24.0-beta.20250612');
      expect(formatVersionLabel('1.2'), 'v1.2');
    });

    test('去除首尾空白后再加前缀', () {
      expect(formatVersionLabel('  0.1.0  '), 'v0.1.0');
    });

    test('null / 空串 / 纯空白统一回退 v1.0.0', () {
      expect(formatVersionLabel(null), fallbackAppVersionLabel);
      expect(formatVersionLabel(''), fallbackAppVersionLabel);
      expect(formatVersionLabel('   '), fallbackAppVersionLabel);
      expect(formatVersionLabel('\t\n'), fallbackAppVersionLabel);
      expect(fallbackAppVersionLabel, 'v1.0.0');
    });
  });

  group('AppVersionResolver', () {
    test('正常读取：只取 version，格式化为 v 前缀文本', () async {
      const resolver = AppVersionResolver(loader: _load0_1_0);
      expect(await resolver.resolve(), 'v0.1.0');
    });

    test('空值 / 空白：回退 v1.0.0', () async {
      expect(
        await const AppVersionResolver(loader: _loadNull).resolve(),
        fallbackAppVersionLabel,
      );
      expect(
        await const AppVersionResolver(loader: _loadEmpty).resolve(),
        fallbackAppVersionLabel,
      );
      expect(
        await const AppVersionResolver(loader: _loadBlank).resolve(),
        fallbackAppVersionLabel,
      );
    });

    test('同步 throw：吞掉异常并回退 v1.0.0', () async {
      final resolver = AppVersionResolver(
        loader: () => throw StateError('sync boom'),
      );
      expect(await resolver.resolve(), fallbackAppVersionLabel);
    });

    test('异步 throw：吞掉异常并回退 v1.0.0', () async {
      final resolver = AppVersionResolver(
        loader: () async => throw Exception('async boom'),
      );
      expect(await resolver.resolve(), fallbackAppVersionLabel);
    });

    test('超时：永不完成的 Future 在 timeout 后回退 v1.0.0', () async {
      final resolver = AppVersionResolver(
        loader: () => Completer<String?>().future,
        timeout: const Duration(milliseconds: 20),
      );
      expect(
        await resolver.resolve().timeout(const Duration(seconds: 2)),
        fallbackAppVersionLabel,
      );
    });

    test('默认 loader 在没有插件通道时仍返回非空 v 前缀文本（不抛异常）', () async {
      const resolver = AppVersionResolver(
        timeout: Duration(milliseconds: 100),
      );
      final label = await resolver.resolve().timeout(
            const Duration(seconds: 2),
          );
      expect(label, isNotEmpty);
      expect(label.startsWith('v'), isTrue);
    });
  });
}

Future<String?> _load0_1_0() async => '0.1.0';

Future<String?> _loadNull() async => null;

Future<String?> _loadEmpty() async => '';

Future<String?> _loadBlank() async => '   ';

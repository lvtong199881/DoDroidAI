import 'package:package_info_plus/package_info_plus.dart';

/// 读取失败、空值、空白时的统一回退值，与「关于」页回退值 1.0.0 对齐。
const String fallbackAppVersionLabel = 'v1.0.0';

/// 将原始 versionName 格式化为展示文本。
///
/// - 入参为 null、空串或纯空白：返回 [fallbackAppVersionLabel]；
/// - 其余情况：返回 'v' + 去除首尾空白后的原值；
/// - 不拼接 buildNumber，不做本地化，不补零。
String formatVersionLabel(String? versionName) {
  final trimmed = versionName?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return fallbackAppVersionLabel;
  }
  return 'v$trimmed';
}

/// 返回原始 versionName（不带 'v' 前缀、不含 buildNumber）。
///
/// 允许返回 null；允许抛异常（同步或异步）；允许永不完成（由 timeout 兜底）。
typedef AppVersionLoader = Future<String?> Function();

/// 版本号读取器：只负责「读 + 格式化 + 兜底」，不依赖 UI。
///
/// 契约：`resolve()` 永远以非空、以 'v' 开头的展示字符串成功完成；
/// 读取异常、空值、超时统一回退 [fallbackAppVersionLabel]，不抛异常、不写日志。
class AppVersionResolver {
  const AppVersionResolver({
    AppVersionLoader? loader,
    this.timeout = const Duration(milliseconds: 500),
  }) : _loader = loader;

  final AppVersionLoader? _loader;
  final Duration timeout;

  /// 永远成功完成：返回非空、以 'v' 开头的展示字符串。
  Future<String> resolve() async {
    try {
      final versionName = await _load().timeout(timeout);
      return formatVersionLabel(versionName);
    } catch (_) {
      // 平台通道异常、同步 throw、超时一律吞掉：版本号不应阻塞弹窗。
      return fallbackAppVersionLabel;
    }
  }

  Future<String?> _load() {
    final loader = _loader;
    if (loader == null) {
      return PackageInfo.fromPlatform().then((info) => info.version);
    }
    // Future.sync 把 loader 的同步 throw 也转成异步错误，统一走 catch。
    return Future<String?>.sync(loader);
  }
}

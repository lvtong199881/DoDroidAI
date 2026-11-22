import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 「欢迎弹窗已展示」标记的读写接口。
///
/// 实现约定：读取失败/内容损坏抛异常，由调用方按「未展示」处理；
/// 写入失败抛异常，由调用方记录后继续展示。
abstract interface class WelcomeFlagStore {
  /// true = 本安装已展示；false = 未展示（文件缺失或内容为 `0`）。
  Future<bool> read();

  /// 写入已展示标记；失败抛异常。
  Future<void> write();
}

/// 基于应用私有目录独立文件的标记实现。
///
/// 物理位置：`<getApplicationSupportDirectory()>/welcome/welcome_dialog_shown_v1`
/// （Android 上即 `filesDir`），内容为 UTF-8 字符 `1`。
///
/// 用独立文件而不是 `SharedPreferences`，是为了让 Android 备份规则能只排除
/// 这一个文件，不影响主题/语言/AI 配置等其他偏好。
class FileWelcomeFlagStore implements WelcomeFlagStore {
  FileWelcomeFlagStore({Future<Directory> Function()? supportDirectory})
      : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  /// 相对应用私有目录（applicationSupportDirectory）的标记路径。
  static const String flagRelativePath = 'welcome/welcome_dialog_shown_v1';

  final Future<Directory> Function() _supportDirectory;

  Future<File> _flagFile() async {
    final directory = await _supportDirectory();
    return File(p.join(directory.path, flagRelativePath));
  }

  @override
  Future<bool> read() async {
    final file = await _flagFile();
    if (!await file.exists()) return false;
    final content = (await file.readAsString()).trim();
    if (content == '1') return true;
    if (content == '0') return false;
    throw FormatException('欢迎标记内容非法（长度 ${content.length}）');
  }

  @override
  Future<void> write() async {
    final file = await _flagFile();
    await file.parent.create(recursive: true);
    await file.writeAsString('1', flush: true);
  }
}

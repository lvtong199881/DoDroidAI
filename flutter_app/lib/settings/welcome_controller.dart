import 'welcome_contract.dart';
import 'welcome_flag_store.dart';
import 'welcome_launch_entry.dart';
import 'welcome_log.dart';

/// 宿主提供的展示函数：push 弹窗后调用一次 [onShown]（用于打 `welcome_shown`），
/// 等弹窗关闭后返回关闭结果。
typedef WelcomePresenter = Future<WelcomeDismissResult> Function(
  void Function() onShown,
);

/// 欢迎弹窗门控：单飞、读标记 → 写标记 → 展示 → 记日志。
///
/// 同一实例只执行一次检查，并发调用复用同一个 Future；[runOnce] 永不向调用方
/// 抛异常，所有日志异常被吞掉，不阻塞首页。
class WelcomeController {
  WelcomeController({
    required WelcomeFlagStore store,
    required WelcomeLog log,
    required LaunchEntryResolver entryResolver,
  })  : _store = store,
        _log = log,
        _entryResolver = entryResolver;

  final WelcomeFlagStore _store;
  final WelcomeLog _log;
  final LaunchEntryResolver _entryResolver;

  Future<void>? _run;

  Future<void> runOnce({
    required String locale,
    required WelcomePresenter presenter,
  }) {
    final running = _run;
    if (running != null) return running;
    final future = _runInternal(locale: locale, presenter: presenter);
    _run = future;
    return future;
  }

  Future<void> _runInternal({
    required String locale,
    required WelcomePresenter presenter,
  }) async {
    try {
      final entry = await _entryResolver.resolve();

      var flagged = false;
      var readFailed = false;
      try {
        flagged = await _store.read();
      } catch (error) {
        readFailed = true;
        _safeLog(
          () => _log.error(
            stage: WelcomeErrorStage.read,
            error: welcomeErrorSummary(error),
          ),
        );
      }

      if (flagged) {
        _safeLog(
          () => _log.check(
            show: false,
            reason: WelcomeReason.flagged,
            entry: entry,
            locale: locale,
          ),
        );
        return;
      }

      _safeLog(
        () => _log.check(
          show: true,
          reason: readFailed ? WelcomeReason.readFailed : WelcomeReason.noFlag,
          entry: entry,
          locale: locale,
        ),
      );

      // 先写标记再展示：写失败也继续展示，只是下次可能重复。
      try {
        await _store.write();
        _safeLog(() => _log.mark(success: true));
      } catch (error) {
        final summary = welcomeErrorSummary(error);
        _safeLog(() => _log.mark(success: false, error: summary));
        _safeLog(
          () => _log.error(stage: WelcomeErrorStage.write, error: summary),
        );
      }

      var shownLogged = false;
      final result = await presenter(() {
        if (shownLogged) return;
        shownLogged = true;
        _safeLog(() => _log.shown(entry: entry, locale: locale));
      });
      _safeLog(
        () => _log.dismissed(
          method: result.method,
          visibleMs: result.visibleMs,
        ),
      );
    } catch (error) {
      // 展示/导航异常：本次不重试、不再展示第二次。
      _safeLog(
        () => _log.error(
          stage: WelcomeErrorStage.render,
          error: welcomeErrorSummary(error),
        ),
      );
    }
  }

  void _safeLog(void Function() action) {
    try {
      action();
    } catch (_) {
      // 日志失败不影响弹窗
    }
  }
}

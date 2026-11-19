import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'download_manager.dart';
import 'model_catalog.dart';
import 'model_manager.dart';
import 'sherpa_asr.dart';
import 'sherpa_tts.dart';

/// 语音模型自动准备阶段
enum VoiceBootstrapPhase { idle, checking, needsWifi, downloading, ready, failed }

class VoiceBootstrapState {
  const VoiceBootstrapState({
    this.phase = VoiceBootstrapPhase.idle,
    this.sttProgress = 0,
    this.ttsProgress = 0,
    this.error,
  });

  final VoiceBootstrapPhase phase;
  final double sttProgress;
  final double ttsProgress;
  final String? error;

  VoiceBootstrapState copyWith({
    VoiceBootstrapPhase? phase,
    double? sttProgress,
    double? ttsProgress,
    String? error,
  }) {
    return VoiceBootstrapState(
      phase: phase ?? this.phase,
      sttProgress: sttProgress ?? this.sttProgress,
      ttsProgress: ttsProgress ?? this.ttsProgress,
      error: error ?? this.error,
    );
  }
}

/// 下载判定结果（纯函数，便于单测）
class VoiceDownloadPlan {
  const VoiceDownloadPlan({
    this.downloadStt = false,
    this.downloadTts = false,
    this.blockedReason,
  });

  final bool downloadStt;
  final bool downloadTts;

  /// 'noNetwork' / 'cellular' / null
  final String? blockedReason;
}

/// 启动时决定要下载哪些模型：
/// - 都就绪 → 不下载；
/// - 无网 / 蜂窝 → 阻塞（避免首次启动消耗移动流量）；
/// - Wi-Fi / 以太网 → 下载缺失项。
VoiceDownloadPlan resolveVoiceDownloadPlan({
  required bool sttReady,
  required bool ttsReady,
  required bool onWifi,
  required bool hasNetwork,
}) {
  if (sttReady && ttsReady) return const VoiceDownloadPlan();
  if (!hasNetwork) return const VoiceDownloadPlan(blockedReason: 'noNetwork');
  if (!onWifi) return const VoiceDownloadPlan(blockedReason: 'cellular');
  return VoiceDownloadPlan(downloadStt: !sttReady, downloadTts: !ttsReady);
}

/// 语音优先的启动准备：已就绪直接预热；Wi-Fi 下自动下载缺失模型；
/// 蜂窝/无网时等待网络恢复（不会在移动网络下自动下载）。
class VoiceBootstrap {
  VoiceBootstrap._();

  static final VoiceBootstrap instance = VoiceBootstrap._();

  final ValueNotifier<VoiceBootstrapState> state =
      ValueNotifier(const VoiceBootstrapState());

  final ModelManager _sttManager = ModelManager('stt');
  final ModelManager _ttsManager = ModelManager('tts');

  Future<void>? _inflight;
  StreamSubscription<List<ConnectivityResult>>? _networkSub;
  VoidCallback? _downloadListener;
  bool _checkingReady = false;

  /// 幂等：并发调用复用同一次检查
  Future<void> ensureModels() {
    return _inflight ??= _ensure().whenComplete(() => _inflight = null);
  }

  Future<void> _ensure() async {
    final current = state.value.phase;
    if (current == VoiceBootstrapPhase.checking ||
        current == VoiceBootstrapPhase.downloading) {
      return;
    }
    state.value = state.value.copyWith(phase: VoiceBootstrapPhase.checking);

    final sttModel = SttModels.byId(await _sttManager.activeModelId());
    final ttsModel = TtsModels.byId(await _ttsManager.activeModelId());
    var sttReady = await _sttManager.isDownloaded(sttModel);
    var ttsReady = await _ttsManager.isDownloaded(ttsModel);

    if (sttReady && ttsReady) {
      await _warmUp();
      state.value = state.value.copyWith(phase: VoiceBootstrapPhase.ready);
      return;
    }

    final results = await Connectivity().checkConnectivity();
    final plan = resolveVoiceDownloadPlan(
      sttReady: sttReady,
      ttsReady: ttsReady,
      onWifi: _isWifi(results),
      hasNetwork: _hasNetwork(results),
    );

    if (plan.blockedReason != null) {
      state.value = state.value.copyWith(phase: VoiceBootstrapPhase.needsWifi);
      _watchNetwork();
      return;
    }

    state.value = state.value.copyWith(phase: VoiceBootstrapPhase.downloading);
    void onTasks() => _refreshProgress(sttModel.id, ttsModel.id);
    DownloadManager.instance.tasks.addListener(onTasks);
    try {
      await Future.wait([
        if (plan.downloadStt) DownloadManager.instance.start('stt', sttModel),
        if (plan.downloadTts) DownloadManager.instance.start('tts', ttsModel),
      ]);
    } catch (e) {
      debugPrint('VoiceBootstrap: 下载异常 $e');
    } finally {
      DownloadManager.instance.tasks.removeListener(onTasks);
    }

    sttReady = await _sttManager.isDownloaded(sttModel);
    ttsReady = await _ttsManager.isDownloaded(ttsModel);
    if (!sttReady || !ttsReady) {
      state.value = state.value.copyWith(
        phase: VoiceBootstrapPhase.failed,
        error: 'stt=${sttReady ? 'ok' : 'fail'} '
            'tts=${ttsReady ? 'ok' : 'fail'}',
      );
      // 用户可在语音设置页手动重试下载，完成后自动恢复
      _watchNetwork();
      return;
    }
    _refreshProgress(sttModel.id, ttsModel.id);
    await _warmUp();
    state.value = state.value.copyWith(phase: VoiceBootstrapPhase.ready);
  }

  void _refreshProgress(String sttId, String ttsId) {
    final tasks = DownloadManager.instance.tasks.value;
    double progressOf(String kind, String id) {
      final task = tasks['${kind}_$id'];
      if (task == null) return 0;
      if (task.success) return 1;
      return task.progress.clamp(0, 1);
    }

    state.value = state.value.copyWith(
      sttProgress: progressOf('stt', sttId),
      ttsProgress: progressOf('tts', ttsId),
    );
  }

  Future<void> _warmUp() async {
    try {
      await SherpaAsr.warmUp().timeout(const Duration(seconds: 60));
    } catch (e) {
      debugPrint('VoiceBootstrap: ASR 预热失败 $e');
    }
    try {
      await SherpaTts.warmUp().timeout(const Duration(seconds: 60));
    } catch (e) {
      debugPrint('VoiceBootstrap: TTS 预热失败 $e');
    }
  }

  void _watchNetwork() {
    _networkSub ??= Connectivity().onConnectivityChanged.listen((results) {
      if (!_isWifi(results)) return;
      unawaited(ensureModels());
    });
    // 用户可能手动在「设置 → 语音」下载：完成后自动切换到就绪
    if (_downloadListener == null) {
      void onTasks() => unawaited(_checkReadyAfterManualDownload());
      _downloadListener = onTasks;
      DownloadManager.instance.tasks.addListener(onTasks);
    }
  }

  Future<void> _checkReadyAfterManualDownload() async {
    final phase = state.value.phase;
    if (phase != VoiceBootstrapPhase.needsWifi &&
        phase != VoiceBootstrapPhase.failed) {
      return;
    }
    if (_checkingReady) return;
    _checkingReady = true;
    try {
      final sttModel = SttModels.byId(await _sttManager.activeModelId());
      final ttsModel = TtsModels.byId(await _ttsManager.activeModelId());
      if (await _sttManager.isDownloaded(sttModel) &&
          await _ttsManager.isDownloaded(ttsModel)) {
        await _warmUp();
        state.value = state.value.copyWith(phase: VoiceBootstrapPhase.ready);
      }
    } finally {
      _checkingReady = false;
    }
  }

  bool _isWifi(List<ConnectivityResult> results) =>
      results.contains(ConnectivityResult.wifi) ||
      results.contains(ConnectivityResult.ethernet);

  bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  /// 仅测试用：释放网络监听
  void dispose() {
    _networkSub?.cancel();
    _networkSub = null;
    final listener = _downloadListener;
    if (listener != null) {
      DownloadManager.instance.tasks.removeListener(listener);
      _downloadListener = null;
    }
    state.dispose();
  }
}

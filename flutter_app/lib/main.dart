import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'app_worker.dart';
import 'notifications.dart';
import 'quick_actions_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 先起 UI，避免插件初始化阻塞导致启动黑屏
  runApp(const ProviderScope(child: DoDroidApp()));
  unawaited(_initBackgroundServices());
}

/// 插件初始化放在首帧之后，各自 try/catch + 超时，单点失败不影响应用可用
Future<void> _initBackgroundServices() async {
  await Future<void>.delayed(const Duration(milliseconds: 300));

  try {
    await initNotifications().timeout(const Duration(seconds: 6));
  } catch (e) {
    debugPrint('initNotifications failed: $e');
  }

  try {
    await initQuickActions().timeout(const Duration(seconds: 6));
  } catch (e) {
    debugPrint('initQuickActions failed: $e');
  }

  try {
    await Workmanager()
        .initialize(callbackDispatcher)
        .timeout(const Duration(seconds: 8));
    await Workmanager().registerPeriodicTask(
      taskCheckName,
      taskCheckName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    ).timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('workmanager init failed: $e');
  }
}

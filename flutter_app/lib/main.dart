import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'app_worker.dart';
import 'notifications.dart';
import 'quick_actions_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initNotifications();
  await initQuickActions();
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    taskCheckName,
    taskCheckName,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
  runApp(const ProviderScope(child: DoDroidApp()));
}

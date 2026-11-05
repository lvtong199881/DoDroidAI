import 'package:workmanager/workmanager.dart';

import 'data/scheduled_task_database.dart';
import 'notifications.dart';

const String taskCheckName = 'dodroidai_check_tasks';

/// 每 15 分钟检查一次定时任务，到点发通知
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final tasks = await ScheduledTaskRepository.instance.list();
      final enabled = tasks.where((t) => t.enabled).toList();
      if (enabled.isEmpty) return true;
      await initNotifications();
      final now = DateTime.now();
      for (final item in enabled) {
        if (_isDue(item, now)) {
          await showTaskNotification(
            item.title,
            item.prompt.isEmpty ? '定时任务到点提醒' : item.prompt,
          );
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  });
}

bool _isDue(ScheduledTask task, DateTime now) {
  final schedule = task.schedule.trim();
  if (schedule.isEmpty) return false;
  // 支持 HH:mm 形式：在 15 分钟窗口内触发一次
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(schedule);
  if (match == null) return false;
  final hour = int.tryParse(match.group(1)!) ?? -1;
  final minute = int.tryParse(match.group(2)!) ?? -1;
  if (hour < 0 || minute < 0) return false;
  final due = DateTime(now.year, now.month, now.day, hour, minute);
  final diff = now.difference(due).inMinutes;
  return diff >= 0 && diff < 15;
}

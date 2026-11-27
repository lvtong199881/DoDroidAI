import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import '../../data/scheduled_task_database.dart';
import '../../widgets/prompt_dialog.dart';

class ScheduledTaskScreen extends StatefulWidget {
  const ScheduledTaskScreen({super.key});

  @override
  State<ScheduledTaskScreen> createState() => _ScheduledTaskScreenState();
}

class _ScheduledTaskScreenState extends State<ScheduledTaskScreen> {
  final ScheduledTaskRepository _repository = ScheduledTaskRepository.instance;
  List<ScheduledTask> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await _repository.list();
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _loading = false;
    });
  }

  Future<void> _createTask() async {
    final strings = AppStrings.of(context);
    final result = await PromptDialog.show(
      context,
      title: strings.t('newTask'),
      fields: [
        PromptField(label: strings.t('name')),
        PromptField(label: strings.t('prompt'), maxLines: 3),
        PromptField(label: strings.t('schedule'), hintText: strings.t('scheduleHint')),
      ],
      cancelLabel: strings.t('cancel'),
      saveLabel: strings.save,
    );
    if (result == null) return;
    final title = result[0];
    if (title.isNotEmpty) {
      await _repository.insert(
        title: title,
        prompt: result[1],
        schedule: result[2],
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).t('scheduledTasks'), style: const TextStyle(fontSize: 20)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTask,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? Center(child: Text(AppStrings.of(context).t('emptyTasks')))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    final scheme = Theme.of(context).colorScheme;
                    final time = DateTime.fromMillisecondsSinceEpoch(task.createdAt);
                    final timeText =
                        '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                    final statusColor =
                        task.enabled ? const Color(0xFF1E8E5A) : scheme.onSurfaceVariant;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: InkWell(
                        onLongPress: () async {
                          await _repository.delete(task.id);
                          await _load();
                        },
                        onTap: () async {
                          await _repository.setEnabled(task.id, !task.enabled);
                          await _load();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      task.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    task.enabled ? '已启用' : '已停用',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  timeText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  task.prompt.isEmpty
                                      ? (task.schedule.isEmpty
                                          ? AppStrings.of(context).t('noSchedule')
                                          : task.schedule)
                                      : task.prompt,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

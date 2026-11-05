import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import '../../data/scheduled_task_database.dart';

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
    final titleController = TextEditingController();
    final promptController = TextEditingController();
    final scheduleController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(context).t('newTask')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: AppStrings.of(context).t('name')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: promptController,
              maxLines: 3,
              decoration: InputDecoration(labelText: AppStrings.of(context).t('prompt')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: scheduleController,
              decoration: InputDecoration(
                labelText: AppStrings.of(context).t('schedule'),
                hintText: AppStrings.of(context).t('scheduleHint'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.of(context).t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppStrings.of(context).save),
          ),
        ],
      ),
    );
    if (saved == true && titleController.text.trim().isNotEmpty) {
      await _repository.insert(
        title: titleController.text.trim(),
        prompt: promptController.text.trim(),
        schedule: scheduleController.text.trim(),
      );
      await _load();
    }
    titleController.dispose();
    promptController.dispose();
    scheduleController.dispose();
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
              : ListView.separated(
                  itemCount: _tasks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    return ListTile(
                      title: Text(task.title),
                      subtitle: Text(
                        task.schedule.isEmpty ? AppStrings.of(context).t('noSchedule') : task.schedule,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: task.enabled,
                            onChanged: (value) async {
                              await _repository.setEnabled(task.id, value);
                              await _load();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await _repository.delete(task.id);
                              await _load();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

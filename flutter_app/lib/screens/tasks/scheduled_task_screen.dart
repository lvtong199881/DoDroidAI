import 'package:flutter/material.dart';

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
        title: const Text('新建定时任务'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: promptController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '执行内容'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: scheduleController,
              decoration: const InputDecoration(
                labelText: '时间/周期',
                hintText: '如 08:00 或 0 8 * * *',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('保存'),
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
        title: const Text('定时任务', style: TextStyle(fontSize: 20)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTask,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? const Center(child: Text('暂无定时任务'))
              : ListView.separated(
                  itemCount: _tasks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    return ListTile(
                      title: Text(task.title),
                      subtitle: Text(
                        task.schedule.isEmpty ? '未设置时间' : task.schedule,
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

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import '../../data/memory_database.dart';
import '../../widgets/prompt_dialog.dart';

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  final MemoryRepository _repository = MemoryRepository.instance;
  List<MemoryFact> _facts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final facts = await _repository.list();
    if (!mounted) return;
    setState(() {
      _facts = facts;
      _loading = false;
    });
  }

  Future<void> _addFact() async {
    final strings = AppStrings.of(context);
    final result = await PromptDialog.show(
      context,
      title: strings.t('newNote'),
      fields: [PromptField(maxLines: 3, label: strings.t('content'))],
      cancelLabel: strings.t('cancel'),
      saveLabel: strings.save,
    );
    if (result == null) return;
    final text = result[0];
    if (text.isNotEmpty) {
      await _repository.insert(text);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).memory, style: const TextStyle(fontSize: 20)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFact,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _facts.isEmpty
              ? Center(child: Text(AppStrings.of(context).t('emptyMemory')))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _facts.length,
                  itemBuilder: (context, index) {
                    final fact = _facts[index];
                    final scheme = Theme.of(context).colorScheme;
                    final time = DateTime.fromMillisecondsSinceEpoch(fact.createdAt);
                    final timeText =
                        '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: InkWell(
                        onLongPress: () async {
                          await _repository.delete(fact.id);
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
                              Text(
                                fact.content,
                                style: TextStyle(fontSize: 15, color: scheme.onSurface),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  timeText,
                                  style: TextStyle(
                                    fontSize: 12,
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

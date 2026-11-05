import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import '../../data/memory_database.dart';

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
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(context).t('newNote')),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(labelText: AppStrings.of(context).t('content')),
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
    if (saved == true && controller.text.trim().isNotEmpty) {
      await _repository.insert(controller.text.trim());
      await _load();
    }
    controller.dispose();
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
              : ListView.separated(
                  itemCount: _facts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final fact = _facts[index];
                    return ListTile(
                      title: Text(fact.content),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await _repository.delete(fact.id);
                          await _load();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

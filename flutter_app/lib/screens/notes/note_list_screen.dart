import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

import '../../data/note_database.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  final NoteRepository _repository = NoteRepository.instance;
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await _repository.list();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _createNote() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(context).t('newNote')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: AppStrings.of(context).t('title')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: contentController,
              maxLines: 4,
              decoration: InputDecoration(labelText: AppStrings.of(context).t('content')),
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
        titleController.text.trim(),
        contentController.text.trim(),
      );
      await _load();
    }
    titleController.dispose();
    contentController.dispose();
  }

  Future<void> _deleteNote(Note note) async {
    await _repository.delete(note.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).notes, style: const TextStyle(fontSize: 20)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNote,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(child: Text(AppStrings.of(context).t('emptyNotes')))
              : ListView.separated(
                  itemCount: _notes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return ListTile(
                      title: Text(note.title),
                      subtitle: note.content.isEmpty
                          ? null
                          : Text(
                              note.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteNote(note),
                      ),
                    );
                  },
                ),
    );
  }
}

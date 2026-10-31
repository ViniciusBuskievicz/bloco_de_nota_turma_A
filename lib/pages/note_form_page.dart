import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/note.dart';
import '../services/note_sync_service.dart';

class NoteFormPage extends StatefulWidget {
  final Note? note;
  const NoteFormPage({super.key, this.note});
  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  final categoryController = TextEditingController();
  final database = DatabaseHelper.instance;
  final syncService = NoteSyncService();
  bool saving = false;
  bool get isEditing => widget.note != null;
  static const categories = ['Geral', 'Estudos', 'Trabalho', 'Pessoal'];

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    if (note != null) {
      titleController.text = note.title;
      contentController.text = note.content;
      categoryController.text = note.category;
    } else {
      categoryController.text = 'Geral';
    }
  }

  Future<void> saveNote() async {
    final user = FirebaseAuth.instance.currentUser;
    final title = titleController.text.trim();
    final content = contentController.text.trim();
    if (user == null || title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o título e o conteúdo da nota.')));
      return;
    }
    setState(() => saving = true);
    final now = DateTime.now();
    final date = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final previous = widget.note;
    final note = Note(
      id: previous?.id,
      cloudId: previous?.cloudId ?? '${user.uid}_${now.microsecondsSinceEpoch}',
      uid: user.uid,
      title: title,
      content: content,
      category: categoryController.text.trim().isEmpty ? 'Geral' : categoryController.text.trim(),
      updatedAt: now.millisecondsSinceEpoch,
      date: date,
    );
    try {
      final saved = await database.saveNote(note);
      var synced = true;
      try {
        await syncService.save(saved);
      } catch (_) {
        synced = false;
      }
      if (!mounted) return;
      Navigator.pop(context);
      if (!synced) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nota salva no aparelho. A sincronização ocorrerá quando houver conexão.')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Editar nota' : 'Nova nota', style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [IconButton(onPressed: saving ? null : saveNote, icon: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded)), const SizedBox(width: 8)],
        ),
        body: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(children: [
            TextField(controller: titleController, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), decoration: const InputDecoration(hintText: 'Título', border: InputBorder.none, filled: false)),
            const Divider(),
            DropdownButtonFormField<String>(
              value: categories.contains(categoryController.text) ? categoryController.text : 'custom',
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: [...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))), const DropdownMenuItem(value: 'custom', child: Text('Outra (digitar)'))],
              onChanged: (value) => setState(() => categoryController.text = value == 'custom' ? '' : value ?? 'Geral'),
            ),
            if (!categories.contains(categoryController.text)) ...[
              const SizedBox(height: 10),
              TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Nome da categoria')),
            ],
            const SizedBox(height: 12),
            Expanded(child: TextField(controller: contentController, maxLines: null, expands: true, textAlignVertical: TextAlignVertical.top, style: const TextStyle(fontSize: 17, height: 1.5), decoration: const InputDecoration(hintText: 'Comece a escrever...', border: InputBorder.none, filled: false))),
          ]),
        ),
      );
}

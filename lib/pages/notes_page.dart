import 'package:bloco_de_nota_turma_a/database/database_helper.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/pages/login_page.dart';
import 'package:bloco_de_nota_turma_a/pages/note_form_page.dart';
import 'package:bloco_de_nota_turma_a/services/auth_service.dart';
import 'package:bloco_de_nota_turma_a/services/note_sync_service.dart';
import 'package:bloco_de_nota_turma_a/widgets/note_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final database = DatabaseHelper.instance;
  final authService = AuthService();
  final syncService = NoteSyncService();
  final searchController = TextEditingController();
  List<Note> notes = [];
  String categoryFilter = 'Todas';
  String? syncMessage;

  @override
  void initState() {
    super.initState();
    searchController.addListener(() => setState(() {}));
    loadNotes();
  }

  Future<void> loadNotes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final localNotes = await database.getNotes(user.uid);
    if (mounted) setState(() => notes = localNotes);
    try {
      await syncService.sync(user.uid);
      syncMessage = null;
    } catch (_) {
      syncMessage = 'Sem conexão com a nuvem. Exibindo as notas deste aparelho.';
    }
    final result = await database.getNotes(user.uid);
    if (mounted) setState(() => notes = result);
  }

  Future<void> deleteNote(Note note) async {
    await database.deleteNote(note);
    try {
      await syncService.delete(note);
      await database.clearPendingDelete(note.cloudId);
    } catch (_) {
      if (mounted) setState(() => syncMessage = 'Exclusão salva; será sincronizada quando houver conexão.');
    }
    await loadNotes();
  }

  Future<void> logout() async {
    await authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
  }

  Future<void> openForm([Note? note]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => NoteFormPage(note: note)));
    await loadNotes();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final availableCategories = notes.map((note) => note.category).toSet().toList()..sort();
    final categories = ['Todas', ...availableCategories];
    final query = searchController.text.trim().toLowerCase();
    final filtered = notes.where((note) =>
      (categoryFilter == 'Todas' || note.category == categoryFilter) &&
      (query.isEmpty || note.title.toLowerCase().contains(query) || note.content.toLowerCase().contains(query))
    ).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas notas', style: TextStyle(fontWeight: FontWeight.bold)), actions: [IconButton(tooltip: 'Sincronizar', onPressed: loadNotes, icon: const Icon(Icons.sync_rounded)), IconButton(tooltip: 'Sair', onPressed: logout, icon: const Icon(Icons.logout_rounded)), const SizedBox(width: 8)]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => openForm(), backgroundColor: const Color(0xff6c4ab6), foregroundColor: Colors.white, icon: const Icon(Icons.add_rounded), label: const Text('Nova Nota', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user?.email ?? '', style: const TextStyle(color: Color(0xFF77717f), fontSize: 13)),
          if (syncMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(syncMessage!, style: const TextStyle(color: Colors.deepOrange, fontSize: 12))),
          const SizedBox(height: 14),
          TextField(controller: searchController, decoration: InputDecoration(hintText: 'Pesquisar título ou conteúdo', prefixIcon: const Icon(Icons.search), suffixIcon: searchController.text.isEmpty ? null : IconButton(onPressed: searchController.clear, icon: const Icon(Icons.clear)))),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(value: categories.contains(categoryFilter) ? categoryFilter : 'Todas', decoration: const InputDecoration(labelText: 'Filtrar categoria'), items: categories.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => categoryFilter = value ?? 'Todas')),
          const SizedBox(height: 12),
          Expanded(child: filtered.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 100, height: 100, decoration: const BoxDecoration(color: Color(0xffede5fa), shape: BoxShape.circle), child: const Icon(Icons.sticky_note_2_rounded, color: Color(0xff6c4ab6), size: 42)), const SizedBox(height: 20), Text(notes.isEmpty ? 'Nenhuma nota ainda' : 'Nenhuma nota encontrada'), const SizedBox(height: 8), Text(notes.isEmpty ? 'Crie sua primeira nota.' : 'Tente outro termo ou categoria.')]))
            : ListView.builder(itemCount: filtered.length, itemBuilder: (context, index) { final note = filtered[index]; return NoteCard(note: note, onTap: () => openForm(note), onDelete: () => deleteNote(note)); })),
        ]),
      ),
    );
  }
}

import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async => _database ??= await _initDB('notes.db');

  Future<Database> _initDB(String fileName) async {
    if (kIsWeb) {
      // sqflite has no native web driver. This factory stores the SQLite file
      // in IndexedDB and runs sqlite3 WebAssembly in the browser's main thread.
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
      return openDatabase(
        fileName,
        version: 2,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    }
    final path = join(await getDatabasesPath(), fileName);
    return openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''CREATE TABLE notes(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cloudId TEXT NOT NULL UNIQUE,
      uid TEXT NOT NULL,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'Geral',
      updatedAt INTEGER NOT NULL DEFAULT 0,
      date TEXT NOT NULL
    )''');
    await db.execute('CREATE TABLE deleted_notes(cloudId TEXT PRIMARY KEY, uid TEXT NOT NULL)');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE notes ADD COLUMN cloudId TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE notes ADD COLUMN category TEXT NOT NULL DEFAULT 'Geral'");
      await db.execute('ALTER TABLE notes ADD COLUMN updatedAt INTEGER NOT NULL DEFAULT 0');
      await db.execute("UPDATE notes SET cloudId = 'legacy_' || id");
      await db.execute('CREATE TABLE deleted_notes(cloudId TEXT PRIMARY KEY, uid TEXT NOT NULL)');
    }
  }

  Future<Note> saveNote(Note note) async {
    final db = await database;
    if (note.id == null) {
      final id = await db.insert('notes', note.toMap()..remove('id'));
      return note.withId(id);
    }
    await db.update('notes', note.toMap(), where: 'id = ? AND uid = ?', whereArgs: [note.id, note.uid]);
    return note;
  }

  Future<List<Note>> getNotes(String uid) async {
    final rows = await (await database).query('notes', where: 'uid = ?', whereArgs: [uid], orderBy: 'updatedAt DESC, id DESC');
    return rows.map(Note.fromMap).toList();
  }

  Future<void> upsertCloudNote(Note note) async {
    final db = await database;
    final rows = await db.query('notes', where: 'cloudId = ? AND uid = ?', whereArgs: [note.cloudId, note.uid], limit: 1);
    if (rows.isEmpty) {
      await db.insert('notes', note.toMap()..remove('id'), conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      final local = Note.fromMap(rows.first);
      final useCloud = note.updatedAt >= local.updatedAt;
      final chosen = useCloud ? note : local;
      await db.update('notes', chosen.toMap()..['id'] = local.id, where: 'id = ?', whereArgs: [local.id]);
    }
  }

  Future<void> removeCloudNote(String cloudId, String uid) async =>
      (await database).delete('notes', where: 'cloudId = ? AND uid = ?', whereArgs: [cloudId, uid]);

  Future<void> deleteNote(Note note) async {
    final db = await database;
    await db.insert('deleted_notes', {'cloudId': note.cloudId, 'uid': note.uid}, conflictAlgorithm: ConflictAlgorithm.replace);
    if (note.id != null) await db.delete('notes', where: 'id = ? AND uid = ?', whereArgs: [note.id, note.uid]);
  }

  Future<List<Map<String, Object?>>> getPendingDeletes(String uid) async =>
      (await database).query('deleted_notes', where: 'uid = ?', whereArgs: [uid]);

  Future<void> clearPendingDelete(String cloudId) async =>
      (await database).delete('deleted_notes', where: 'cloudId = ?', whereArgs: [cloudId]);
}

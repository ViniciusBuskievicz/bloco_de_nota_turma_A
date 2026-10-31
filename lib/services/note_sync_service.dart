import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bloco_de_nota_turma_a/database/database_helper.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';

class NoteSyncService {
  NoteSyncService({FirebaseFirestore? firestore, DatabaseHelper? database})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _database = database ?? DatabaseHelper.instance;

  final FirebaseFirestore _firestore;
  final DatabaseHelper _database;

  CollectionReference<Map<String, dynamic>> _userNotes(String uid) =>
      _firestore.collection('users').doc(uid).collection('notes');

  Future<void> sync(String uid) async {
    // Remove queued deletions first, so an old cloud copy cannot reappear.
    for (final deletion in await _database.getPendingDeletes(uid)) {
      await _userNotes(uid).doc(deletion['cloudId'] as String).set({
        'uid': uid,
        'deleted': true,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      await _database.clearPendingDelete(deletion['cloudId'] as String);
    }

    final localNotes = await _database.getNotes(uid);
    final remoteSnapshot = await _userNotes(uid).get();
    final remote = <String, Note>{};
    final deletedCloudIds = <String>{};
    for (final document in remoteSnapshot.docs) {
      final data = document.data();
      if (data['uid'] != uid) continue;
      if (data['deleted'] == true) {
        deletedCloudIds.add(document.id);
        await _database.removeCloudNote(document.id, uid);
        continue;
      }
      final note = Note.fromCloud(document.id, data);
      remote[document.id] = note;
      await _database.upsertCloudNote(note);
    }

    // New or newer local notes are uploaded; newer remote copies were already
    // applied by upsertCloudNote and will be reflected on the next read.
    for (final local in localNotes) {
      if (deletedCloudIds.contains(local.cloudId)) continue;
      final cloud = remote[local.cloudId];
      if (cloud == null || local.updatedAt > cloud.updatedAt) {
        await _userNotes(uid).doc(local.cloudId).set(local.toCloudMap());
      }
    }
  }

  Future<void> save(Note note) async {
    await _userNotes(note.uid).doc(note.cloudId).set(note.toCloudMap());
  }

  Future<void> delete(Note note) async {
    await _userNotes(note.uid).doc(note.cloudId).set({
      'uid': note.uid,
      'deleted': true,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }
}

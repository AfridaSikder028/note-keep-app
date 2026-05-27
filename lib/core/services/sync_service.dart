import '../../data/models/note.dart';
import '../../data/database/database_helper.dart';
import 'firestore_service.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _db = DatabaseHelper.instance;
  final _fs = FirestoreService.instance;

    Future<void> syncOnAppOpen() async {
      print('🔄 SYNC STARTED');
      try {
        final remoteNotes = await _fs.fetchAllNotes();
        print('📡 Remote notes: ${remoteNotes.length}');

        for (final remote in remoteNotes) {
          final existing = await _db.getNoteById(remote.id);

          if (existing == null) {
            // Not in local DB — insert it
            await _db.insertNote(remote);
            print('✅ Inserted from remote: ${remote.title} '
                '(isDeleted=${remote.isDeleted})');
          } else {
            // Both exist — keep newest version
            if (remote.updatedAt > existing.updatedAt) {
              await _db.updateNote(remote);
              print('🔁 Updated from remote: ${remote.title}');
            }
          }
        }

        print('✅ Sync completed');
      } catch (e) {
        print('❌ Sync failed: $e');
      }
    }

Future<void> saveAndSync(Note note) async {
  // 1. Save locally FIRST (fast)
  try {
    final existing = await _db.getNoteById(note.id);
    if (existing != null) {
      await _db.updateNote(note);
    } else {
      await _db.insertNote(note);
    }
  } catch (e) {
    print('❌ Local save failed: $e');
    return;
  }

  // 2. Sync to Firestore in background (don't await)
  _fs.saveNote(note).then((_) {
    print('✅ Saved & synced: ${note.title} | '
        'isDeleted=${note.isDeleted} | isArchived=${note.isArchived}');
  }).catchError((e) {
    print('❌ Firestore sync failed (note saved locally): $e');
  });
}

Future<void> deleteAndSync(String noteId) async {
  // Delete locally first (fast)
  try {
    await _db.deleteNotePermanently(noteId);
    print('✅ Permanently deleted locally: $noteId');
  } catch (e) {
    print('❌ Local permanent delete failed: $e');
  }

  // Firestore delete in background
  _fs.deleteNote(noteId).then((_) {
    print('✅ Permanently deleted from Firestore: $noteId');
  }).catchError((e) {
    print('❌ Firestore permanent delete failed: $e');
  });
}
}
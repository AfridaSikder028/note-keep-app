import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/note.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final _firestore = FirebaseFirestore.instance;

  Future<void> init() async {
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    print('🔵 Firestore Service initialized');
  }

  CollectionReference<Map<String, dynamic>> _getNotesRef() {
    return _firestore.collection('all_notes');
  }

Future<void> saveNote(Note note) async {
  try {
    final ref = _getNotesRef();
    // Always save to Firestore regardless of deleted state.
    // Firestore is the backup — local DB handles filtering.
    // Only deleteNote() should permanently remove from Firestore.
    await ref.doc(note.id).set(_toFirestore(note));
    print('✅ Note saved to Firestore: ${note.id} '
        '(isDeleted=${note.isDeleted})');
  } catch (e) {
    print('❌ Save error: $e');
    rethrow;
  }
}

  Future<List<Note>> fetchAllNotes() async {
    try {
      final ref = _getNotesRef();
      final snapshot = await ref.get();
      print('🔵 Snapshot size: ${snapshot.docs.length}');

      final notes = <Note>[];
      for (final doc in snapshot.docs) {
        try {
          final note = _fromFirestore(doc.id, doc.data());
          // Only fetch active and archived notes from Firestore.
          // Deleted notes are stored locally only.
          // Include ALL notes — deleted ones show in trash
          notes.add(note);
        } catch (e) {
          print('❌ Error parsing note ${doc.id}: $e');
        }
      }

      print('✅ Fetched ${notes.length} notes');
      return notes;
    } catch (e) {
      print('❌ Fetch error: $e');
      return [];
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      final ref = _getNotesRef();
      await ref.doc(noteId).delete();
      print('✅ Note permanently deleted from Firestore: $noteId');
    } catch (e) {
      print('❌ Delete error: $e');
    }
  }

  Map<String, dynamic> _toFirestore(Note note) => {
        'title': note.title,
        'content': note.content,
        'colorValue': note.colorValue,
        'isPinned': note.isPinned,
        'isArchived': note.isArchived,
        'isDeleted': note.isDeleted,
        'isLocked': note.isLocked,
        'noteType': note.noteType,
        'folderId': note.folderId,
        'reminderTime': note.reminderTime,
        'backgroundTheme': note.backgroundTheme,
        'imagePaths': note.imagePaths
            ?.split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        'drawingPaths': note.drawingPaths
            ?.split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        'blocksJson': note.blocksJson,
        'syncStatus': 'SYNCED',
        'createdAt': note.createdAt,
        'updatedAt': note.updatedAt,
      };

  Note _fromFirestore(String id, Map<String, dynamic> data) {
    String? listToString(dynamic value) {
      if (value == null) return null;
      if (value is List) return value.join(',');
      if (value is String) return value;
      return null;
    }

    return Note(
      id: id,
      title: data['title']?.toString() ?? '',
      content: data['content']?.toString() ?? '',
      colorValue: (data['colorValue'] as int?) ?? 0xFF1E1E1E,
      isPinned: data['isPinned'] ?? false,
      isArchived: data['isArchived'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
      isLocked: data['isLocked'] ?? false,
      noteType: data['noteType']?.toString() ?? 'TEXT',
      folderId: data['folderId']?.toString(),
      reminderTime: data['reminderTime'] as int?,
      backgroundTheme: data['backgroundTheme']?.toString(),
      imagePaths: listToString(data['imagePaths']),
      drawingPaths: listToString(data['drawingPaths']),
      blocksJson: data['blocksJson']?.toString(),
      syncStatus: data['syncStatus']?.toString() ?? 'SYNCED',
      createdAt: (data['createdAt'] as int?) ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAt: (data['updatedAt'] as int?) ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}
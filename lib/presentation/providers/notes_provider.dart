import 'package:flutter/material.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/note.dart';
import '../../core/services/sync_service.dart';

class NotesProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final SyncService _sync = SyncService.instance;
  List<Note> _notes = [];
  String _sortOrder = 'updatedAt';

  // Returns only active notes (not deleted, not archived)
  List<Note> get notes =>
      _notes.where((n) => !n.isDeleted && !n.isArchived).toList();

  List<Note> _sorted(List<Note> input) {
    final list = [...input];
    switch (_sortOrder) {
      case 'title':
        list.sort((a, b) => (a.title).toLowerCase()
            .compareTo((b.title).toLowerCase()));
        break;
      case 'createdAt':
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'updatedAt':
      default:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
    }
    return list;
  }

  List<Note> get pinned =>
      _sorted(notes.where((n) => n.isPinned).toList());
  List<Note> get unpinned =>
      _sorted(notes.where((n) => !n.isPinned).toList());

  void applySort(String sortOrder) {
    _sortOrder = sortOrder;
    notifyListeners();
  }

  // Load ALL notes (active + archived + deleted) into _notes
  // The getters filter them as needed
  Future<void> load() async {
    print('📱 Loading all notes from local DB...');
    final active = await _db.getAllNotes();
    final archived = await _db.getArchived();
    final deleted = await _db.getDeleted();

    // Merge all, deduplicate by id
    final Map<String, Note> map = {};
    for (final n in [...active, ...archived, ...deleted]) {
      map[n.id] = n;
    }
    _notes = map.values.toList();

    print('📱 Total notes in memory: ${_notes.length} '
        '(active: ${active.length}, '
        'archived: ${archived.length}, '
        'deleted: ${deleted.length})');
    notifyListeners();
  }

  Future<void> add(Note note) async {
    await _sync.saveAndSync(note);
    await load();
  }

  Future<void> update(Note note) async {
    await _sync.saveAndSync(note);
    await load();
  }

    Future<void> softDelete(String id) async {
      final note = _notes.firstWhere((n) => n.id == id);
      print('🔵 Soft deleting: ${note.title}');
      
      // শুধুমাত্র if note is not already deleted
      if (note.isDeleted) {
        print('⚠️ Note already deleted, skipping');
        return;
      }
      
      final updatedNote = note.copyWith(isDeleted: true);
      await _sync.saveAndSync(updatedNote);
      
      // Direct local update without calling load()
      final index = _notes.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notes[index] = updatedNote;
        notifyListeners();
      }
      
      print('✅ Soft deleted: ${note.title}');
    }

  Future<void> togglePin(Note note) async {
    await update(note.copyWith(isPinned: !note.isPinned));
  }

  Future<void> toggleArchive(Note note) async {
    await update(note.copyWith(isArchived: !note.isArchived));
  }

  Future<void> permanentlyDelete(String id) async {
    print('💀 Permanently deleting: $id');
    await _sync.deleteAndSync(id);
    await load();
  }

  Future<List<Note>> search(String query) async {
    return await _db.search(query);
  }
}
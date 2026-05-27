import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/note.dart';
import '../../core/services/sync_service.dart';


class NotesProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final SyncService _sync = SyncService.instance;
  List<Note> _notes = [];
  String _sortOrder = 'updatedAt'; // ✅ এটা যোগ করো

  List<Note> get notes =>
      _notes.where((n) => !n.isDeleted && !n.isArchived).toList();

  List<Note> _sorted(List<Note> input) { // ✅ এটা যোগ করো
    final list = [...input];
    switch (_sortOrder) {
      case 'title':
        list.sort((a, b) => (a.title ?? '').toLowerCase().compareTo((b.title ?? '').toLowerCase()));
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

  List<Note> get pinned => _sorted(notes.where((n) => n.isPinned).toList()); // ✅ _sorted যোগ
  List<Note> get unpinned => _sorted(notes.where((n) => !n.isPinned).toList()); // ✅ _sorted যোগ

  void applySort(String sortOrder) { // ✅ পুরো method টা যোগ করো
    _sortOrder = sortOrder;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  Future<void> load() async {
    print('📱 Loading notes from local database...');
    _notes = await _db.getAllNotes();
    print('📱 Loaded ${_notes.length} notes locally');
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
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
  
  if (note.isDeleted) {
    print('⚠️ Note already deleted, skipping');
    return;
  }
  
  final updatedNote = note.copyWith(isDeleted: true);
  
  // Save to Firestore and local DB
  await _sync.saveAndSync(updatedNote);
  
  // Force reload to update all providers
  await load();
  
  print('✅ Soft deleted: ${note.title}');
}

  Future<void> togglePin(Note note) async {
    await update(note.copyWith(isPinned: !note.isPinned));
  }

  Future<void> toggleArchive(Note note) async {
    await update(note.copyWith(isArchived: !note.isArchived));
  }

  Future<void> permanentlyDelete(String id) async {
    await _sync.deleteAndSync(id);
    await load();
  }

  Future<List<Note>> search(String query) async {
    return await _db.search(query);
  }
}
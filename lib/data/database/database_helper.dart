import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';
import '../models/checklist_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  DatabaseHelper._();

  // ── Web storage via SharedPreferences ─────────────────────
  static const _notesKey = 'notes_data';

  Future<void> _webInsert(Note note) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _webGetAll();
    all.removeWhere((n) => n.id == note.id);
    all.add(note);
    final encoded = jsonEncode(all.map((n) => n.toMap()).toList());
    await prefs.setString(_notesKey, encoded);
  }

  Future<List<Note>> _webGetAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_notesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((m) => Note.fromMap(m as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _webUpdate(Note note) async {
    await _webInsert(note); // same logic — upsert
  }

  Future<void> _webDelete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _webGetAll();
    all.removeWhere((n) => n.id == id);
    final encoded = jsonEncode(all.map((n) => n.toMap()).toList());
    await prefs.setString(_notesKey, encoded);
  }

  // ── SQLite (mobile/desktop) ────────────────────────────────
  Future<Database> get database async => _db ??= await _initDB();

  Future<Database> _initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'notes_v1.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        colorValue INTEGER NOT NULL DEFAULT -1315861,
        isPinned INTEGER NOT NULL DEFAULT 0,
        isArchived INTEGER NOT NULL DEFAULT 0,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        isLocked INTEGER NOT NULL DEFAULT 0,
        noteType TEXT NOT NULL DEFAULT 'TEXT',
        folderId TEXT,
        reminderTime INTEGER,
        backgroundTheme TEXT,
        imagePaths TEXT,
        checklistJson TEXT,
        syncStatus TEXT NOT NULL DEFAULT 'LOCAL_ONLY',
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE checklist_items (
        id TEXT PRIMARY KEY,
        noteId TEXT NOT NULL,
        text TEXT NOT NULL,
        isChecked INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // ── Public API — auto routes to web or mobile ─────────────

  Future<void> insertNote(Note note) async {
    if (kIsWeb) {
      await _webInsert(note);
    } else {
      final db = await database;
      await db.insert('notes', note.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<Note>> getAllNotes() async {
    if (kIsWeb) {
      final all = await _webGetAll();
      return all
          .where((n) => !n.isDeleted && !n.isArchived)
          .toList()
        ..sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });
    } else {
      final db = await database;
      final rows = await db.query('notes',
          where: 'isDeleted=0 AND isArchived=0',
          orderBy: 'isPinned DESC, updatedAt DESC');
      return rows.map(Note.fromMap).toList();
    }
  }

  Future<List<Note>> getArchived() async {
    if (kIsWeb) {
      final all = await _webGetAll();
      return all.where((n) => n.isArchived && !n.isDeleted).toList();
    } else {
      final db = await database;
      final rows = await db.query('notes',
          where: 'isArchived=1 AND isDeleted=0',
          orderBy: 'updatedAt DESC');
      return rows.map(Note.fromMap).toList();
    }
  }

  Future<List<Note>> getDeleted() async {
    if (kIsWeb) {
      final all = await _webGetAll();
      final deleted = all.where((n) => n.isDeleted).toList();
      print('🔵 Web getDeleted: found ${deleted.length} deleted notes');
      return deleted;
    } else {
      final db = await database;
      final rows = await db.query('notes',
          where: 'isDeleted = ?', whereArgs: [1],
          orderBy: 'updatedAt DESC');
      print('🔵 SQLite getDeleted: found ${rows.length} deleted notes');
      return rows.map((row) => Note.fromMap(row)).toList();
    }
  }

  Future<Note?> getNoteById(String id) async {
    if (kIsWeb) {
      final all = await _webGetAll();
      try {
        return all.firstWhere((n) => n.id == id);
      } catch (_) {
        return null;
      }
    } else {
      final db = await database;
      final rows =
          await db.query('notes', where: 'id=?', whereArgs: [id]);
      if (rows.isEmpty) return null;
      return Note.fromMap(rows.first);
    }
  }

  Future<void> updateNote(Note note) async {
    if (kIsWeb) {
      await _webUpdate(note);
    } else {
      final db = await database;
      await db.update('notes', note.toMap(),
          where: 'id=?', whereArgs: [note.id]);
    }
  }

  Future<void> deleteNotePermanently(String id) async {
    if (kIsWeb) {
      await _webDelete(id);
    } else {
      final db = await database;
      await db.delete('notes', where: 'id=?', whereArgs: [id]);
    }
  }

  Future<List<Note>> search(String q) async {
    if (kIsWeb) {
      final all = await _webGetAll();
      final lower = q.toLowerCase();
      return all
          .where((n) =>
              !n.isDeleted &&
              (n.title.toLowerCase().contains(lower) ||
                  n.content.toLowerCase().contains(lower)))
          .toList();
    } else {
      final db = await database;
      final rows = await db.rawQuery(
          "SELECT * FROM notes WHERE isDeleted=0 AND (title LIKE ? OR content LIKE ?)",
          ['%$q%', '%$q%']);
      return rows.map(Note.fromMap).toList();
    }
  }

  Future<List<Note>> getNotesByLabel(String labelId) async {
    if (kIsWeb) return [];
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT n.* FROM notes n
      INNER JOIN note_labels nl ON n.id = nl.noteId
      WHERE nl.labelId = ? AND n.isDeleted = 0
    ''', [labelId]);
    return rows.map(Note.fromMap).toList();
  }

  Future<void> purgeOldDeleted() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final all = await _webGetAll();
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 30))
          .millisecondsSinceEpoch;
      all.removeWhere((n) => n.isDeleted && n.updatedAt < cutoff);
      await prefs.setString(
          _notesKey, jsonEncode(all.map((n) => n.toMap()).toList()));
    } else {
      final db = await database;
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 30))
          .millisecondsSinceEpoch;
      await db.delete('notes',
          where: 'isDeleted=1 AND updatedAt<?', whereArgs: [cutoff]);
    }
  }

// ADD this method after purgeOldDeleted():
Future<void> purgeAllDeleted() async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    final all = await _webGetAll();
    all.removeWhere((n) => n.isDeleted);
    await prefs.setString(
        _notesKey, jsonEncode(all.map((n) => n.toMap()).toList()));
  } else {
    final db = await database;
    await db.delete('notes', where: 'isDeleted=1');
  }
}
  // ── Checklist Items ────────────────────────────────────────
  Future<List<ChecklistItem>> getChecklistItems(String noteId) async {
    if (kIsWeb) return [];
    final db = await database;
    final rows = await db.query('checklist_items',
        where: 'noteId=?',
        whereArgs: [noteId],
        orderBy: 'sortOrder ASC');
    return rows.map(ChecklistItem.fromMap).toList();
  }

  Future<void> insertChecklistItem(ChecklistItem item) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert('checklist_items', item.toMap());
  }

  Future<void> updateChecklistItem(ChecklistItem item) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update('checklist_items', item.toMap(),
        where: 'id=?', whereArgs: [item.id]);
  }

  Future<void> deleteChecklistItem(String id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.delete('checklist_items', where: 'id=?', whereArgs: [id]);
  }
}

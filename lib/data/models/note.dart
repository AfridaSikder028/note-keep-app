import 'dart:convert';
import 'package:uuid/uuid.dart';

class Note {
  final String id;
  final String title;
  final String content;
  final int colorValue;
  final bool isPinned;
  final bool isArchived;
  final bool isDeleted;
  final bool isLocked;
  final String noteType;
  final String? folderId;
  final int? reminderTime;
  final String? backgroundTheme;
  final String? imagePaths;
  final String? drawingPaths;
  final String? blocksJson;
  final String syncStatus;
  final int createdAt;
  final int updatedAt;
  final String? checklistJson;
  const Note({
    required this.id,
    this.title = '',
    this.content = '',
    this.colorValue = 0xFF1E1E1E,
    this.isPinned = false,
    this.isArchived = false,
    this.isDeleted = false,
    this.isLocked = false,
    this.noteType = 'TEXT',
    this.folderId,
    this.reminderTime,
    this.backgroundTheme,
    this.imagePaths,
    this.drawingPaths,
    this.blocksJson,
    this.checklistJson,
    this.syncStatus = 'LOCAL_ONLY',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.create({
    String title = '',
    String content = '',
    String noteType = 'TEXT',
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Note(
      id: const Uuid().v4(),
      title: title,
      content: content,
      noteType: noteType,
      createdAt: now,
      updatedAt: now,
    );
  }

  List<String> get imagePathsList {
    if (imagePaths == null || imagePaths!.isEmpty) return [];
    try {
      final list = jsonDecode(imagePaths!) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  List<String> get drawingPathsList {
    if (drawingPaths == null || drawingPaths!.isEmpty) return [];
    try {
      final list = jsonDecode(drawingPaths!) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

Note copyWith({
  String? title,
  String? content,
  int? colorValue,
  bool? isPinned,
  bool? isArchived,
  bool? isDeleted,
  bool? isLocked,
  String? noteType,
  String? folderId,
  int? reminderTime,
  bool clearReminder = false,  // pass true to explicitly set to null
  String? backgroundTheme,
  String? imagePaths,
  String? drawingPaths,
  String? blocksJson,
  String? syncStatus,
  String? checklistJson,
}) {
  return Note(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    colorValue: colorValue ?? this.colorValue,
    isPinned: isPinned ?? this.isPinned,
    isArchived: isArchived ?? this.isArchived,
    isDeleted: isDeleted ?? this.isDeleted,
    isLocked: isLocked ?? this.isLocked,
    noteType: noteType ?? this.noteType,
    folderId: folderId ?? this.folderId,
    reminderTime: clearReminder ? null : (reminderTime ?? this.reminderTime),
    backgroundTheme: backgroundTheme ?? this.backgroundTheme,
    imagePaths: imagePaths ?? this.imagePaths,
    drawingPaths: drawingPaths ?? this.drawingPaths,
    blocksJson: blocksJson ?? this.blocksJson,
    syncStatus: syncStatus ?? 'PENDING_UPLOAD',
    createdAt: createdAt,
    updatedAt: DateTime.now().millisecondsSinceEpoch,
    // in return:
    checklistJson: checklistJson ?? this.checklistJson,
  );
}

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'colorValue': colorValue,
    'isPinned': isPinned ? 1 : 0,
    'isArchived': isArchived ? 1 : 0,
    'isDeleted': isDeleted ? 1 : 0,
    'isLocked': isLocked ? 1 : 0,
    'noteType': noteType,
    'folderId': folderId,
    'reminderTime': reminderTime,
    'backgroundTheme': backgroundTheme,
    'imagePaths': imagePaths,
    'drawingPaths': drawingPaths,
    'blocksJson': blocksJson,
    'syncStatus': syncStatus,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'checklistJson': checklistJson,
  };

  factory Note.fromMap(Map<String, dynamic> m) => Note(
    id: m['id'],
    title: m['title'] ?? '',
    content: m['content'] ?? '',
    colorValue: m['colorValue'] ?? 0xFF1E1E1E,
    isPinned: m['isPinned'] == 1,
    isArchived: m['isArchived'] == 1,
    isDeleted: m['isDeleted'] == 1,
    isLocked: m['isLocked'] == 1,
    noteType: m['noteType'] ?? 'TEXT',
    folderId: m['folderId'],
    reminderTime: m['reminderTime'],
    backgroundTheme: m['backgroundTheme'],
    imagePaths: m['imagePaths'],
    drawingPaths: m['drawingPaths'],
    blocksJson: m['blocksJson'],
    syncStatus: m['syncStatus'] ?? 'LOCAL_ONLY',
    createdAt: m['createdAt'],
    updatedAt: m['updatedAt'],
    checklistJson: m['checklistJson'],
  );
}
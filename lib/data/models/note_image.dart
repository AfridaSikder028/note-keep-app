import 'package:uuid/uuid.dart';

class NoteImage {
  final String id;
  final String noteId;
  final String localPath;
  final String? cloudUrl;
  final int sortOrder;

  const NoteImage({
    required this.id,
    required this.noteId,
    required this.localPath,
    this.cloudUrl,
    this.sortOrder = 0,
  });

  factory NoteImage.create({required String noteId, required String localPath}) {
    return NoteImage(
      id: const Uuid().v4(),
      noteId: noteId,
      localPath: localPath,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'noteId': noteId,
    'localPath': localPath,
    'cloudUrl': cloudUrl,
    'sortOrder': sortOrder,
  };

  factory NoteImage.fromMap(Map<String, dynamic> m) => NoteImage(
    id: m['id'],
    noteId: m['noteId'],
    localPath: m['localPath'],
    cloudUrl: m['cloudUrl'],
    sortOrder: m['sortOrder'] ?? 0,
  );
}
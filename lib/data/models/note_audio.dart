import 'package:uuid/uuid.dart';

class NoteAudio {
  final String id;
  final String noteId;
  final String localPath;
  final String? cloudUrl;
  final int durationMs;

  const NoteAudio({
    required this.id,
    required this.noteId,
    required this.localPath,
    this.cloudUrl,
    this.durationMs = 0,
  });

  factory NoteAudio.create({required String noteId, required String localPath}) {
    return NoteAudio(
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
    'durationMs': durationMs,
  };

  factory NoteAudio.fromMap(Map<String, dynamic> m) => NoteAudio(
    id: m['id'],
    noteId: m['noteId'],
    localPath: m['localPath'],
    cloudUrl: m['cloudUrl'],
    durationMs: m['durationMs'] ?? 0,
  );
}
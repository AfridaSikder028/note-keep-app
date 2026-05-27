import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/note_themes.dart';
import '../../data/models/note.dart';
import '../providers/notes_provider.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final double fontSize;

  const NoteCard({
    super.key,
    required this.note,
    this.fontSize = 14.0, // default so other screens (archive, trash) still work
  });

  String _getPreviewText() {
    if (note.content.isEmpty) return '';
    try {
      final delta = jsonDecode(note.content) as List;
      final buffer = StringBuffer();
      for (final op in delta) {
        if (op is Map && op['insert'] is String) {
          buffer.write(op['insert']);
        }
      }
      return buffer.toString().trim();
    } catch (_) {
      return note.content;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = note.backgroundTheme != null &&
            note.backgroundTheme!.isNotEmpty
        ? NoteThemes.getById(note.backgroundTheme!)
        : null;

    // For 'default' theme, follow the app's light/dark setting
final bool isDefaultTheme = theme != null && NoteThemes.isDefault(theme);
final bool appIsDark = Theme.of(context).brightness == Brightness.dark;

final bgColor = isDefaultTheme
    ? (appIsDark ? const Color(0xFF2C2C2C) : const Color(0xFFFFFFFF))
    : (theme != null ? theme.backgroundColor : Color(note.colorValue));

final isDark = isDefaultTheme
    ? appIsDark
    : (theme != null ? NoteThemes.isDark(theme) : true);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    final previewText = _getPreviewText();

    // Scale title relative to body: always 2pt larger than body
    final titleSize = fontSize + 2;

    return GestureDetector(
      onTap: () async {
        await context.push('/note/${note.id}');
        if (context.mounted) {
          await context.read<NotesProvider>().load();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pin and lock icons
            if (note.isPinned || note.isLocked)
              Align(
                alignment: Alignment.topRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (note.isPinned)
                      Icon(Icons.push_pin, size: 16, color: subTextColor),
                    if (note.isLocked)
                      Icon(Icons.lock, size: 16, color: subTextColor),
                  ],
                ),
              ),

            // Title
            if (note.title.isNotEmpty)
              Text(
                note.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: titleSize,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

            if (note.title.isNotEmpty && previewText.isNotEmpty)
              const SizedBox(height: 4),

            // Body preview
            if (previewText.isNotEmpty)
              Text(
                previewText,
                style: TextStyle(fontSize: fontSize, color: subTextColor),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
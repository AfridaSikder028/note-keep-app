import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../../core/constants/note_themes.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/note.dart';
import '../providers/notes_provider.dart';
import '../widgets/note_card.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await DatabaseHelper.instance.getDeleted();
    print('🔵 Trash screen - getDeleted returned: ${notes.length} notes');
    if (mounted) {
      setState(() {
        _notes = notes;
        _loading = false;
      });
    }
  }

  Future<void> _restore(Note note) async {
    await context
        .read<NotesProvider>()
        .update(note.copyWith(isDeleted: false));
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Note restored'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _deletePermanent(Note note) async {
    await context.read<NotesProvider>().permanentlyDelete(note.id);
    await _load();
  }

  Future<void> _emptyTrash() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final dialogText = isDark ? Colors.white : Colors.black87;
    final dialogSub = isDark ? Colors.white70 : Colors.black54;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text('Empty Trash?', style: TextStyle(color: dialogText)),
        content: Text(
          'All notes in trash will be permanently deleted.',
          style: TextStyle(color: dialogSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: dialogSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Empty',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await DatabaseHelper.instance.purgeAllDeleted();
      await context.read<NotesProvider>().load();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8);
    final iconColor = isDark ? Colors.white : Colors.black87;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final emptyColor = isDark ? Colors.white54 : Colors.black45;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        title: Text('Trash', style: TextStyle(color: titleColor)),
        iconTheme: IconThemeData(color: iconColor),
        actions: [
          if (_notes.isNotEmpty)
            TextButton(
              onPressed: _emptyTrash,
              child: const Text('Empty',
                  style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline,
                          size: 72,
                          color: emptyColor.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text('Trash is empty',
                          style: TextStyle(
                              color: emptyColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text(
                        'Deleted notes appear here',
                        style: TextStyle(
                            color: emptyColor.withOpacity(0.7),
                            fontSize: 14),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: MasonryGridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    itemCount: _notes.length,
                    itemBuilder: (_, i) {
                      final note = _notes[i];
                      return Stack(
                        children: [
                          // ── Same NoteCard as home screen ──
                          NoteCard(note: note),

                          // ── Restore / Delete buttons ───────
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () => _restore(note),
                                      child: const Text(
                                        'Restore',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                      width: 1,
                                      height: 20,
                                      color: Colors.white24),
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () =>
                                          _deletePermanent(note),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
    );
  }
}
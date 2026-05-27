import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/note.dart';
import '../../data/database/database_helper.dart';
import '../providers/notes_provider.dart';
import '../widgets/note_card.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Note> _archivedNotes = [];
  bool _isLoading = true;
  String _selectedSort = 'Date modified';

  final List<String> _sortOptions = [
    'Date modified',
    'Date created',
    'Title',
    'Color',
  ];

  @override
  void initState() {
    super.initState();
    _loadArchivedNotes();
  }

  Future<void> _loadArchivedNotes() async {
    setState(() => _isLoading = true);
    final notes = await _db.getArchived();
    if (mounted) {
      setState(() {
        _archivedNotes = _sortNotes(notes);
        _isLoading = false;
      });
    }
  }

  List<Note> _sortNotes(List<Note> notes) {
    switch (_selectedSort) {
      case 'Date modified':
        return List.from(notes)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case 'Date created':
        return List.from(notes)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case 'Title':
        return List.from(notes)
          ..sort((a, b) => a.title.compareTo(b.title));
      case 'Color':
        return List.from(notes)
          ..sort((a, b) => a.colorValue.compareTo(b.colorValue));
      default:
        return notes;
    }
  }

Future<void> _unarchiveNote(Note note) async {
  final provider = context.read<NotesProvider>();
  await provider.toggleArchive(note);
  await _loadArchivedNotes();
}

Future<void> _deleteNote(Note note) async {
  final provider = context.read<NotesProvider>();
  await provider.softDelete(note.id);
  await _loadArchivedNotes();
}

  void _showSortBottomSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white70 : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Sort by',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w500)),
            ),
            Divider(color: isDark ? Colors.white24 : Colors.black12),
            ..._sortOptions.map((option) => ListTile(
                  leading: Icon(_getSortIcon(option),
                      color: _selectedSort == option
                          ? const Color(0xFFE53935)
                          : subColor),
                  title: Text(option,
                      style: TextStyle(
                          color: _selectedSort == option
                              ? const Color(0xFFE53935)
                              : textColor)),
                  trailing: _selectedSort == option
                      ? const Icon(Icons.check, color: Color(0xFFE53935))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedSort = option;
                      _archivedNotes = _sortNotes(_archivedNotes);
                    });
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  IconData _getSortIcon(String option) {
    switch (option) {
      case 'Date modified':
        return Icons.update;
      case 'Date created':
        return Icons.create;
      case 'Title':
        return Icons.sort_by_alpha;
      case 'Color':
        return Icons.color_lens;
      default:
        return Icons.sort;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8);
    final appBarBg =
        isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8);
    final iconColor = isDark ? Colors.white : Colors.black87;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final dialogBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final dialogText = isDark ? Colors.white : Colors.black87;
    final dialogSub = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: appBarBg,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: iconColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Archive',
                style: TextStyle(
                    color: titleColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w500)),
            actions: [
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: iconColor),
                color: dialogBg,
                onSelected: (value) async {
                  if (value == 'empty') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: dialogBg,
                        title: Text('Empty archive?',
                            style: TextStyle(color: dialogText)),
                        content: Text(
                          'This will permanently delete all archived notes.',
                          style: TextStyle(color: dialogSub),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('Cancel',
                                style: TextStyle(color: dialogSub)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Empty',
                                style:
                                    TextStyle(color: Color.fromARGB(255, 242, 31, 133))),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      for (var note in _archivedNotes) {
                        await context
                            .read<NotesProvider>()
                            .softDelete(note.id);
                      }
                      await _loadArchivedNotes();
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'empty',
                    child: Text('Empty archive',
                        style: TextStyle(color: dialogText)),
                  ),
                ],
              ),
            ],
          ),
          if (_isLoading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
          else if (_archivedNotes.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverToBoxAdapter(
                child: MasonryGridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  itemCount: _archivedNotes.length,
                  itemBuilder: (context, index) {
                    final note = _archivedNotes[index];
                    return Stack(
                      children: [
                        NoteCard(note: note),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.unarchive_outlined,
                                      color: Colors.white, size: 18),
                                  onPressed: () => _unarchiveNote(note),
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                  padding: EdgeInsets.zero,
                                  splashRadius: 20,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.white, size: 18),
                                  onPressed: () => _deleteNote(note),
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                  padding: EdgeInsets.zero,
                                  splashRadius: 20,
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
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black45;
    final circleBg =
        isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);
    final iconColor = isDark ? Colors.white38 : Colors.black26;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration:
                BoxDecoration(color: circleBg, shape: BoxShape.circle),
            child:
                Icon(Icons.archive_outlined, size: 60, color: iconColor),
          ),
          const SizedBox(height: 24),
          Text('Archive is empty',
              style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Notes you archive will appear here.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: subColor, fontSize: 14, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home_outlined),
            label: const Text('Go to Home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 248, 57, 127),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }
}
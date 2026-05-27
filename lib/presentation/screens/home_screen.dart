import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/note_card.dart';
import '../widgets/expandable_fab.dart';
import '../widgets/app_drawer.dart';
import '../../core/services/sync_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SyncService.instance.syncOnAppOpen();
      await context.read<NotesProvider>().load();
    });
  }

  Future<void> _manualSync() async {
    setState(() {
      _isSyncing = true;
    });
    
    try {
      await SyncService.instance.syncOnAppOpen();
      await context.read<NotesProvider>().load();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notes synced from cloud'),
            duration: Duration(seconds: 2),
            )
          
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sortOrder = context.read<SettingsProvider>().sortOrder;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotesProvider>().applySort(sortOrder);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    final isGrid = settings.isGridView;
    final fontSize = settings.fontSize;

    return Scaffold(
      drawer: const AppDrawer(),
      body: CustomScrollView(
        slivers: [
          _SearchAppBar(
            isGrid: isGrid,
            onSync: _manualSync,
            isSyncing: _isSyncing,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: Consumer<NotesProvider>(
              builder: (ctx, provider, _) {
                if (provider.notes.isEmpty && !_isSyncing) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.note_outlined, size: 80),
                          SizedBox(height: 16),
                          Text('No notes yet'),
                          SizedBox(height: 8),
                          Text('Tap + to create your first note'),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildListDelegate([
                    if (provider.pinned.isNotEmpty) ...[
                      const _SectionLabel('PINNED'),
                      _NoteGrid(
                        notes: provider.pinned,
                        isGrid: isGrid,
                        fontSize: fontSize,
                      ),
                      const SizedBox(height: 16),
                      const _SectionLabel('OTHERS'),
                    ],
                    _NoteGrid(
                      notes: provider.unpinned,
                      isGrid: isGrid,
                      fontSize: fontSize,
                    ),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: const ExpandableFab(),
    );
  }
}

// ── Search app bar ──────────────────────────────────

class _SearchAppBar extends StatelessWidget {
  final bool isGrid;
  final VoidCallback onSync;
  final bool isSyncing;

  const _SearchAppBar({
    required this.isGrid,
    required this.onSync,
    required this.isSyncing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final barBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8);
    final searchBg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);
    final hintColor = isDark ? Colors.white54 : Colors.black45;
    final iconColor = isDark ? Colors.white : Colors.black87;

    return SliverAppBar(
      pinned: true,
      floating: true,
      backgroundColor: barBg,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: Icon(Icons.menu, color: iconColor),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: GestureDetector(
        onTap: () => context.push('/search'),
        child: Container(
          height: 45,
          decoration: BoxDecoration(
            color: searchBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.search, color: hintColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Search your notes...',
                style: TextStyle(color: hintColor, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.sync, color: iconColor),
          onPressed: onSync,
        ),
        IconButton(
          icon: Icon(
            isGrid ? Icons.grid_view : Icons.view_agenda_outlined,
            color: iconColor,
          ),
          onPressed: () {
            context.read<SettingsProvider>().setGridView(!isGrid);
          },
        ),
      ],
    );
  }
}

// ── Note grid / list ──────────────────────────────────────────────

class _NoteGrid extends StatelessWidget {
  final List<Note> notes;
  final bool isGrid;
  final double fontSize;

  const _NoteGrid({
    required this.notes,
    required this.isGrid,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    if (isGrid) {
      return MasonryGridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        itemCount: notes.length,
        itemBuilder: (_, i) => NoteCard(note: notes[i], fontSize: fontSize),
      );
    } else {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: notes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => NoteCard(note: notes[i], fontSize: fontSize),
      );
    }
  }
}

// ── Section label ────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white54
              : Colors.black45,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
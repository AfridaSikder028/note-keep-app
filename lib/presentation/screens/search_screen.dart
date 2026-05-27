import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/note.dart';
import '../providers/notes_provider.dart';
import '../widgets/note_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Note> _searchResults = [];
  bool _isSearching = false;
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All', 'Text', 'Checklist', 'Audio', 'Drawing', 'Images', 'Locked',
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.isNotEmpty) {
      _performSearch(query);
    } else {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    final provider = context.read<NotesProvider>();
    final results = await provider.search(query);
    var filtered = results;
    if (_selectedFilter != 'All') {
      filtered = results.where((note) {
        switch (_selectedFilter) {
          case 'Text':       return note.noteType == 'TEXT';
          case 'Checklist':  return note.noteType == 'CHECKLIST';
          case 'Audio':      return note.noteType == 'AUDIO';
          case 'Drawing':    return note.noteType == 'DRAWING';
          case 'Images':     return note.noteType == 'IMAGE';
          case 'Locked':     return note.isLocked;
          default:           return true;
        }
      }).toList();
    }
    if (mounted) {
      setState(() {
        _searchResults = filtered;
        _isSearching = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final scaffoldBg =
        isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8);
    final appBarBg =
        isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8);
    final searchBoxBg =
        isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);
    final iconColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white38 : Colors.black38;
    final textColor = isDark ? Colors.white : Colors.black87;

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
            title: Container(
              height: 45,
              decoration: BoxDecoration(
                  color: searchBoxBg,
                  borderRadius: BorderRadius.circular(8)),
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                style: TextStyle(color: textColor, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  hintStyle: TextStyle(color: hintColor),
                  border: InputBorder.none,
                  prefixIcon:
                      Icon(Icons.search, color: hintColor, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              color: hintColor, size: 20),
                          onPressed: _clearSearch,
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            actions: const [],
          ),


          if (_isSearching)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
          else if (_searchController.text.isNotEmpty &&
              _searchResults.isEmpty)
            SliverFillRemaining(
                child: _buildEmptyState(isDark))
          else if (_searchResults.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.9,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      NoteCard(note: _searchResults[index]),
                  childCount: _searchResults.length,
                ),
              ),
            )
          else
            SliverFillRemaining(
                child: _buildRecentSearches(isDark)),
        ],
      ),
    );
  }


  Widget _buildEmptyState(bool isDark) {
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
            width: 80,
            height: 80,
            decoration:
                BoxDecoration(color: circleBg, shape: BoxShape.circle),
            child: Icon(Icons.search_off, size: 40, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text('No results found',
              style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Try different keywords or filters',
              style: TextStyle(color: subColor, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildRecentSearches(bool isDark) {
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
            width: 80,
            height: 80,
            decoration:
                BoxDecoration(color: circleBg, shape: BoxShape.circle),
            child: Icon(Icons.search, size: 40, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text('Search your notes',
              style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Find notes by title or content',
              style: TextStyle(color: subColor, fontSize: 14)),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white70 : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Filter by',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w500)),
            ),
            Divider(
                color: isDark ? Colors.white24 : Colors.black12),
            ..._filters.map((filter) => ListTile(
                  leading: Icon(_getFilterIcon(filter),
                      color: _selectedFilter == filter
                          ? const Color(0xFFE53935)
                          : subColor),
                  title: Text(filter,
                      style: TextStyle(
                          color: _selectedFilter == filter
                              ? const Color(0xFFE53935)
                              : textColor)),
                  trailing: _selectedFilter == filter
                      ? const Icon(Icons.check,
                          color: Color(0xFFE53935))
                      : null,
                  onTap: () {
                    setState(() => _selectedFilter = filter);
                    Navigator.pop(ctx);
                    if (_searchController.text.isNotEmpty) {
                      _performSearch(_searchController.text);
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'Text':      return Icons.text_fields;
      case 'Checklist': return Icons.check_box;
      case 'Audio':     return Icons.mic;
      case 'Drawing':   return Icons.brush;
      case 'Images':    return Icons.image;
      case 'Locked':    return Icons.lock;
      default:          return Icons.filter_list;
    }
  }
}
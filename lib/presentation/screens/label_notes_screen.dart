import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/note.dart';
//import '../../data/models/label.dart';
import '../widgets/note_card.dart';

class LabelNotesScreen extends StatefulWidget {
  final String labelId;
  final String labelName;

  const LabelNotesScreen({
    super.key,
    required this.labelId,
    required this.labelName,
  });

  @override
  State<LabelNotesScreen> createState() => _LabelNotesScreenState();
}

class _LabelNotesScreenState extends State<LabelNotesScreen> {
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await DatabaseHelper.instance.getNotesByLabel(widget.labelId);
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          widget.labelName,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Center(
                  child: Text(
                    'No notes with this label',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: MasonryGridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    itemCount: _notes.length,
                    itemBuilder: (_, i) => NoteCard(note: _notes[i]),
                  ),
                ),
    );
  }
}
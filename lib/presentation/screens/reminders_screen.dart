import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/note.dart';
import '../../data/database/database_helper.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Note> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await DatabaseHelper.instance.getAllNotes();
    if (mounted) {
      setState(() {
        _reminders = all
            .where((n) => n.reminderTime != null && !n.isDeleted)
            .toList()
          ..sort((a, b) => a.reminderTime!.compareTo(b.reminderTime!));
        _loading = false;
      });
    }
  }

  Future<void> _removeReminder(Note note) async {
    final provider = context.read<NotesProvider>();
    await provider.update(note.copyWith(clearReminder: true));
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder removed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatReminder(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('EEE, d MMM • h:mm a').format(dt);
  }

  bool _isOverdue(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms).isBefore(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8);
    final appBarBg =
        isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8);
    final iconColor = isDark ? Colors.white : Colors.black87;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final cardBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final noteTitleColor = isDark ? Colors.white : Colors.black87;
    final noteSubColor = isDark ? Colors.white54 : Colors.black45;
    final emptyColor = isDark ? Colors.white54 : Colors.black45;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Reminders',
            style: TextStyle(
                color: titleColor,
                fontSize: 20,
                fontWeight: FontWeight.w500)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 72,
                          color: emptyColor.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text('No reminders set',
                          style: TextStyle(
                              color: emptyColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text(
                        'Open a note and tap the bell icon\nto set a reminder',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: emptyColor.withOpacity(0.7),
                            fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _reminders.length,
                  itemBuilder: (_, i) {
                    final note = _reminders[i];
                    final overdue = _isOverdue(note.reminderTime!);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: overdue
                              ? Colors.redAccent.withOpacity(0.5)
                              : isDark
                                  ? Colors.white12
                                  : Colors.black12,
                          width: overdue ? 1.5 : 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: overdue
                                ? Colors.redAccent.withOpacity(0.15)
                                : const Color(0xFFFA337C).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            overdue
                                ? Icons.notifications_off_outlined
                                : Icons.notifications_active_outlined,
                            color: overdue
                                ? Colors.redAccent
                                : const Color(0xFFFA337C),
                            size: 22,
                          ),
                        ),
                        title: Text(
                          note.title.isNotEmpty ? note.title : 'Untitled',
                          style: TextStyle(
                              color: noteTitleColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.access_time,
                                    size: 13,
                                    color: overdue
                                        ? Colors.redAccent
                                        : noteSubColor),
                                const SizedBox(width: 4),
                                Text(
                                  _formatReminder(note.reminderTime!),
                                  style: TextStyle(
                                      color: overdue
                                          ? Colors.redAccent
                                          : noteSubColor,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                            if (overdue) ...[
                              const SizedBox(height: 2),
                              Text('Overdue',
                                  style: TextStyle(
                                      color: Colors.redAccent.withOpacity(0.8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Edit reminder
                            IconButton(
                              icon: Icon(Icons.edit_outlined,
                                  size: 20, color: noteSubColor),
                              tooltip: 'Edit reminder',
                              onPressed: () async {
                                await context.push('/note/${note.id}');
                                await _load();
                              },
                            ),
                            // Remove reminder
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 20, color: Colors.redAccent),
                              tooltip: 'Remove reminder',
                              onPressed: () => _removeReminder(note),
                            ),
                          ],
                        ),
                        onTap: () async {
                          await context.push('/note/${note.id}');
                          await _load();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
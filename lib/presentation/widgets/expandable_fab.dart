import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../providers/notes_provider.dart';

class ExpandableFab extends StatelessWidget {
  const ExpandableFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () async {
        await context.push('/note/new?type=text');
        if (context.mounted) {
          await context.read<NotesProvider>().load();
        }
      },
      backgroundColor: kBrandOrange,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }
}
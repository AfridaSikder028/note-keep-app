import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/notes_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/search_screen.dart';
import 'presentation/screens/archive_screen.dart';
import 'presentation/screens/trash_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/reminders_screen.dart';
import 'presentation/screens/note_editor_screen.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
    GoRoute(path: '/archive', builder: (_, __) => const ArchiveScreen()),
    GoRoute(path: '/trash', builder: (_, __) => const TrashScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/reminders', builder: (_, __) => const RemindersScreen()),
    GoRoute(
      path: '/note/new',
      builder: (_, state) {
        final type = state.uri.queryParameters['type'] ?? 'text';
        return NoteEditorScreen(noteType: type);
      },
    ),
    GoRoute(
      path: '/note/:id',
      builder: (_, state) => NoteEditorScreen(
        noteId: state.pathParameters['id'],
      ),
    ),
  ],
);

class NoteKeepApp extends StatelessWidget {
  const NoteKeepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotesProvider()..load()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (_, settings, __) => MaterialApp.router(
          title: 'NoteKeep',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

class NoteTheme {
  final String id;
  final String name;
  final Color backgroundColor;
  final Color? patternColor;
  final String? patternType;
  final String? imagePath;

  const NoteTheme({
    required this.id,
    required this.name,
    required this.backgroundColor,
    this.patternColor,
    this.patternType,
    this.imagePath,
  });
}

class NoteThemes {
  static const List<NoteTheme> all = [
    // 'default' background is a placeholder — the editor and note card
    // both override this with the app's current light/dark color at runtime.
    NoteTheme(id: 'default',     name: 'Default',  backgroundColor: Color(0xFF1E1E1E)),
    NoteTheme(id: 'cream',       name: 'Cream',    backgroundColor: Color(0xFFFFF8E7), patternType: 'lines', patternColor: Color(0xFFE8D5A3)),
    NoteTheme(id: 'blue_lines',  name: 'Blue',     backgroundColor: Color(0xFFE8F4FD), patternType: 'lines', patternColor: Color(0xFFADD8F0)),
    NoteTheme(id: 'green_lines', name: 'Green',    backgroundColor: Color(0xFFEDF7EE), patternType: 'lines', patternColor: Color(0xFFA8D5AA)),
    NoteTheme(id: 'pink_lines',  name: 'Pink',     backgroundColor: Color(0xFFFDEEEE), patternType: 'lines', patternColor: Color(0xFFF0AAAA)),
    NoteTheme(id: 'yellow',      name: 'Yellow',   backgroundColor: Color(0xFFFFFDE7), patternType: 'lines', patternColor: Color(0xFFE8D44D)),
    NoteTheme(id: 'purple',      name: 'Purple',   backgroundColor: Color(0xFFF3E5F5), patternType: 'lines', patternColor: Color(0xFFCE93D8)),
    NoteTheme(id: 'dark_blue',   name: 'Navy',     backgroundColor: Color(0xFF1A237E)),
    NoteTheme(id: 'dark_green',  name: 'Forest',   backgroundColor: Color(0xFF1B5E20)),
    NoteTheme(id: 'charcoal',    name: 'Charcoal', backgroundColor: Color(0xFF37474F)),
    NoteTheme(id: 'rose',        name: 'Rose',     backgroundColor: Color(0xFFFFCDD2)),
    NoteTheme(id: 'dots',        name: 'Dots',     backgroundColor: Color(0xFFFFFFFF), patternType: 'dots', patternColor: Color(0xFFCCCCCC)),
  ];

  static NoteTheme getById(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);

  static bool isDark(NoteTheme theme) =>
      theme.backgroundColor.computeLuminance() < 0.4;

  /// Returns true if this theme uses the app's own background color
  /// (i.e. should follow light/dark mode instead of its own fixed color).
  static bool isDefault(NoteTheme theme) => theme.id == 'default';
}
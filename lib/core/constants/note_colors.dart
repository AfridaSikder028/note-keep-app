import 'package:flutter/material.dart';

class NoteColors {
  static const List<Color> palette = [
    Color(0xFF1E1E1E), // Default dark
    Color(0xFF77172E), // Red
    Color(0xFF692B17), // Orange/Brown
    Color(0xFF7C4A03), // Gold/Yellow
    Color(0xFF264D3B), // Green
    Color(0xFF0C625D), // Teal
    Color(0xFF256377), // Cyan
    Color(0xFF284255), // Dark Blue
    Color(0xFF472E5B), // Purple
    Color(0xFF6C394F), // Pink
  ];
  
  static const Color defaultColor = Color(0xFF1E1E1E);
  
  static Color getColor(int index) {
    if (index >= 0 && index < palette.length) {
      return palette[index];
    }
    return defaultColor;
  }
}
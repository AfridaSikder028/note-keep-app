import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_service.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  String _sortOrder = 'updatedAt';
  bool _isGridView = true;
  double _fontSize = 14.0;
  bool _highPrioritySound = false;
  String? _reminderSound;

  String? get reminderSound => _reminderSound;

  String get reminderSoundLabel {
    if (_reminderSound == null) return 'Default';
    final match = NotificationService.ringtones
        .firstWhere((r) => r['sound'] == _reminderSound,
            orElse: () => {'label': 'Default', 'sound': null});
    return match['label'] ?? 'Default';
  }
  ThemeMode get themeMode => _themeMode;
  String get sortOrder => _sortOrder;
  bool get isGridView => _isGridView;
  double get fontSize => _fontSize;
  bool get highPrioritySound => _highPrioritySound;

  String get themeLabel {
    switch (_themeMode) {
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.system:
        return 'Default';
    }
  }

  String get fontSizeLabel {
    if (_fontSize <= 12.0) return 'Small';
    if (_fontSize <= 14.0) return 'Medium';
    return 'Large';
  }

  String get sortLabel {
    switch (_sortOrder) {
      case 'updatedAt':
        return 'By modification date';
      case 'createdAt':
        return 'By creation date';
      case 'title':
        return 'By title';
      default:
        return 'By modification date';
    }
  }
Future<void> setReminderSound(String? value) async {
  _reminderSound = value;
  final prefs = await SharedPreferences.getInstance();
  if (value == null) {
    await prefs.remove('reminderSound');
  } else {
    await prefs.setString('reminderSound', value);
  }
  notifyListeners();
}

  String get layoutLabel => _isGridView ? 'Grid view' : 'List view';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[prefs.getInt('themeMode') ?? 1];
    _sortOrder = prefs.getString('sortOrder') ?? 'updatedAt';
    _isGridView = prefs.getBool('isGridView') ?? true;
    _fontSize = prefs.getDouble('fontSize') ?? 14.0;
    _highPrioritySound = prefs.getBool('highPrioritySound') ?? false;
    _reminderSound = prefs.getString('reminderSound');
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }

  Future<void> setGridView(bool value) async {
    _isGridView = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isGridView', value);
    notifyListeners();
  }

  Future<void> setSortOrder(String value) async {
    _sortOrder = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sortOrder', value);
    notifyListeners();
  }

  Future<void> setFontSize(double value) async {
    _fontSize = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fontSize', value);
    notifyListeners();
  }

  Future<void> setHighPrioritySound(bool value) async {
    _highPrioritySound = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('highPrioritySound', value);
    notifyListeners();
  }
}
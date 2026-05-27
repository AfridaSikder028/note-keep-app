import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../../core/services/notification_service.dart';

const Color _kPink = Color(0xFFFA337C);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8);
    final appBarBg =
        isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8);
    final titleColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        title: Text('Settings', style: TextStyle(color: titleColor)),
        iconTheme: IconThemeData(color: iconColor),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            children: [
              const _SectionHeader('Style'),

              _SettingsTile(
                title: 'Theme',
                subtitle: settings.themeLabel,
                onTap: () => _showThemeDialog(context, settings),
              ),
              _SettingsTile(
                title: 'Font size',
                subtitle: settings.fontSizeLabel,
                onTap: () => _showFontSizeDialog(context, settings),
              ),
              _SettingsTile(
                title: 'Sort',
                subtitle: settings.sortLabel,
                onTap: () => _showSortDialog(context, settings),
              ),
              _SettingsTile(
                title: 'Layout',
                subtitle: settings.layoutLabel,
                onTap: () => _showLayoutDialog(context, settings),
              ),

              const _SectionHeader('Reminders'),

              Builder(builder: (context) {
                final isDark =
                    Theme.of(context).brightness == Brightness.dark;
                final titleColor = isDark ? Colors.white : Colors.black87;
                final subtitleColor =
                    isDark ? Colors.white54 : Colors.black45;
                return SwitchListTile(
                  tileColor: Colors.transparent,
                  title: Text(
                    'High-priority reminders',
                    style: TextStyle(color: titleColor),
                  ),
                  subtitle: Text(
                    'Play sound even in Silent mode',
                    style: TextStyle(color: subtitleColor),
                  ),
                  value: settings.highPrioritySound,
                  activeColor: _kPink,
                  onChanged: (val) => settings.setHighPrioritySound(val),
                );
              }),

              _SettingsTile(
                title: 'Reminder ringtone',
                subtitle: settings.reminderSoundLabel,
                onTap: () => _showRingtoneDialog(context, settings),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Ringtone dialog ───────────────────────────────────────
  void _showRingtoneDialog(
      BuildContext context, SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: dialogBg,
        title:
            Text('Reminder ringtone', style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: NotificationService.ringtones.map((r) {
            final sound = r['sound'];
            final label = r['label'] ?? 'Default';
            return RadioListTile<String?>(
              title: Text(label, style: TextStyle(color: textColor)),
              value: sound,
              groupValue: settings.reminderSound,
              activeColor: _kPink,
              onChanged: (val) {
                settings.setReminderSound(val);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: _kPink)),
          ),
        ],
      ),
    );
  }

  // ── Theme dialog ──────────────────────────────────────────
  void _showThemeDialog(
      BuildContext context, SettingsProvider settings) {
    _showOptionsDialog<ThemeMode>(
      context: context,
      title: 'Theme',
      options: const [
        _Option(label: 'Dark', value: ThemeMode.dark),
        _Option(label: 'Light', value: ThemeMode.light),
        _Option(label: 'Default (system)', value: ThemeMode.system),
      ],
      current: settings.themeMode,
      onSelect: (val) => settings.setTheme(val),
    );
  }

  // ── Font size dialog ──────────────────────────────────────
  void _showFontSizeDialog(
      BuildContext context, SettingsProvider settings) {
    _showOptionsDialog<double>(
      context: context,
      title: 'Font size',
      options: const [
        _Option(label: 'Small', value: 12.0),
        _Option(label: 'Medium', value: 14.0),
        _Option(label: 'Large', value: 18.0),
      ],
      current: settings.fontSize,
      onSelect: (val) => settings.setFontSize(val),
    );
  }

  // ── Sort dialog ───────────────────────────────────────────
  void _showSortDialog(
      BuildContext context, SettingsProvider settings) {
    _showOptionsDialog<String>(
      context: context,
      title: 'Sort notes by',
      options: const [
        _Option(label: 'By modification date', value: 'updatedAt'),
        _Option(label: 'By creation date', value: 'createdAt'),
        _Option(label: 'By title', value: 'title'),
      ],
      current: settings.sortOrder,
      onSelect: (val) => settings.setSortOrder(val),
    );
  }

  // ── Layout dialog ─────────────────────────────────────────
  void _showLayoutDialog(
      BuildContext context, SettingsProvider settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text('Layout', style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LayoutOption(
              label: 'Grid view',
              selected: settings.isGridView,
              icon: Icons.grid_view_rounded,
              description: 'Small card boxes',
              onTap: () {
                settings.setGridView(true);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _LayoutOption(
              label: 'List view',
              selected: !settings.isGridView,
              icon: Icons.view_agenda_outlined,
              description: 'Full-width rows',
              onTap: () {
                settings.setGridView(false);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: _kPink)),
          ),
        ],
      ),
    );
  }

  // ── Generic radio dialog ──────────────────────────────────
  void _showOptionsDialog<T>({
    required BuildContext context,
    required String title,
    required List<_Option<T>> options,
    required T current,
    required void Function(T) onSelect,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text(title, style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map((opt) => RadioListTile<T>(
                    title: Text(opt.label,
                        style: TextStyle(color: textColor)),
                    value: opt.value,
                    groupValue: current,
                    activeColor: _kPink,
                    onChanged: (val) {
                      if (val != null) onSelect(val);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: _kPink)),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────

class _Option<T> {
  final String label;
  final T value;
  const _Option({required this.label, required this.value});
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: _kPink,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingsTile(
      {required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white54 : Colors.black45;
    final trailingColor = isDark ? Colors.white38 : Colors.black26;

    return ListTile(
      title: Text(title, style: TextStyle(color: titleColor)),
      subtitle: Text(subtitle, style: TextStyle(color: subtitleColor)),
      trailing: Icon(Icons.chevron_right, color: trailingColor),
      onTap: onTap,
    );
  }
}

class _LayoutOption extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _LayoutOption({
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedBg =
        isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0);
    final unselectedText = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? _kPink.withOpacity(0.12)
              : unselectedBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? _kPink : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? _kPink : unselectedText, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: selected ? _kPink : unselectedText,
                        fontWeight: FontWeight.w600)),
                Text(description,
                    style: TextStyle(
                        color:
                            isDark ? Colors.white54 : Colors.black45,
                        fontSize: 12)),
              ],
            ),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle, color: _kPink, size: 20),
          ],
        ),
      ),
    );
  }
}
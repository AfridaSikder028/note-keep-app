import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final iconColor = isDark ? Colors.white70 : Colors.black54;
    final textColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = isDark ? Colors.white24 : Colors.black12;

    return Drawer(
      backgroundColor: drawerBg,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _AppHeader(),
          _buildTile(context,
              icon: Icons.lightbulb_outline,
              label: 'Notes',
              iconColor: iconColor,
              textColor: textColor,
              onTap: () {
                Navigator.pop(context);
                context.go('/');
              }),
          _buildTile(context,
              icon: Icons.notifications_none,
              label: 'Reminders',
              iconColor: iconColor,
              textColor: textColor,
              onTap: () {
                Navigator.pop(context);
                context.push('/reminders');
              }),
          _buildTile(context,
              icon: Icons.archive,
              label: 'Archive',
              iconColor: iconColor,
              textColor: textColor,
              onTap: () {
                Navigator.pop(context);
                context.push('/archive');
              }),
          _buildTile(context,
              icon: Icons.delete_outline,
              label: 'Trash',
              iconColor: iconColor,
              textColor: textColor,
              onTap: () {
                Navigator.pop(context);
                context.push('/trash');
              }),
          Divider(color: dividerColor),
          _buildTile(context,
              icon: Icons.settings,
              label: 'Settings',
              iconColor: iconColor,
              textColor: textColor,
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              }),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label, style: TextStyle(color: textColor)),
      onTap: onTap,
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFFFF8F4);
    const brand = Color.fromARGB(255, 250, 51, 124);
    final subtitleColor = isDark ? Colors.white54 : Colors.black45;

    return Container(
      width: double.infinity,
      color: headerBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 48),

          // Orange icon box
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: brand,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: brand.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Lined paper effect
                Positioned(
                  top: 22,
                  left: 14,
                  right: 14,
                  child: Column(
                    children: List.generate(
                      4,
                      (i) => Container(
                        margin: const EdgeInsets.only(bottom: 7),
                        height: 1.5,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ),
                const Center(
                  child: Icon(Icons.edit,
                      color: Colors.white, size: 36),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'NoteKeep',
            style: TextStyle(
              color: brand,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Your notes, everywhere',
            style: TextStyle(
              color: subtitleColor,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
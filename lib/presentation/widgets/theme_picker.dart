import 'package:flutter/material.dart';
import '../../core/constants/note_themes.dart';

class ThemePicker extends StatelessWidget {
  final String currentThemeId;
  final Function(NoteTheme) onThemeSelected;

  const ThemePicker({
    super.key,
    required this.currentThemeId,
    required this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scrollCtrl = ScrollController();

    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Note theme',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Scrollable row — uses Scrollbar so user can see it's scrollable
          Scrollbar(
            controller: scrollCtrl,
            thumbVisibility: true,
            thickness: 3,
            radius: const Radius.circular(4),
            child: SizedBox(
              height: 140,
              child: NotificationListener<ScrollNotification>(
                // Block scroll notifications from bubbling up to bottom sheet
                onNotification: (_) => true,
                child: ListView.builder(
                  controller: scrollCtrl,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: NoteThemes.all.length,
                  itemBuilder: (_, i) {
                    final theme = NoteThemes.all[i];
                    final isSelected = theme.id == currentThemeId;
                    return GestureDetector(
                      onTap: () {
                        onThemeSelected(theme);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 85,
                        margin: const EdgeInsets.only(right: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Card
                            Container(
                              width: 85,
                              height: 105,
                              decoration: BoxDecoration(
                                color: theme.backgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(
                                        color: const Color(0xFFFFA000),
                                        width: 3,
                                      )
                                    : Border.all(
                                        color: Colors.white24,
                                        width: 1,
                                      ),
                              ),
                              child: isSelected
                                  ? const Center(
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Color(0xFFFFA000),
                                        size: 26,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              theme.name,
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFFFFA000)
                                    : Colors.white54,
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

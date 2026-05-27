import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class NoteImageViewer extends StatefulWidget {
  final List<String> imagePaths;
  final Function(int index) onDelete;
  final Function(int index) onToggleSize;
  final List<bool> isMinimized;

  const NoteImageViewer({
    super.key,
    required this.imagePaths,
    required this.onDelete,
    required this.onToggleSize,
    required this.isMinimized,
  });

  @override
  State<NoteImageViewer> createState() => _NoteImageViewerState();
}

class _NoteImageViewerState extends State<NoteImageViewer> {
  Widget _buildImage(String path) {
    if (path.startsWith('data:image')) {
      final bytes = base64Decode(path.split(',').last);
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true,
          width: double.infinity, height: double.infinity);
    }
    if (kIsWeb) {
      return Image.network(path, fit: BoxFit.cover,
          width: double.infinity, height: double.infinity);
    }
    return Image.file(File(path), fit: BoxFit.cover,
        width: double.infinity, height: double.infinity);
  }

  void _showImageOptions(BuildContext context, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                widget.isMinimized[index] ? Icons.zoom_out_map : Icons.photo_size_select_small,
                color: Colors.white70,
              ),
              title: Text(
                widget.isMinimized[index] ? 'Expand image' : 'Minimize image',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onToggleSize(index);
              },
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete image', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                widget.onDelete(index);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imagePaths.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(widget.imagePaths.length, (i) {
              final mini = widget.isMinimized[i];
              // Always explicit pixel values — never double.infinity in AnimatedContainer
              final double imgW = mini ? fullWidth * 0.45 : fullWidth;
              final double imgH = mini ? 90.0 : 200.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => _showImageOptions(context, i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    width: imgW,
                    height: imgH,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildImage(widget.imagePaths[i]),
                          Positioned(
                            top: 4, right: 4,
                            child: GestureDetector(
                              onTap: () => widget.onToggleSize(i),
                              child: Container(
                                width: 26, height: 26,
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  mini ? Icons.fullscreen : Icons.fullscreen_exit,
                                  color: Colors.white, size: 15,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4, right: 36,
                            child: GestureDetector(
                              onTap: () => widget.onDelete(i),
                              child: Container(
                                width: 26, height: 26,
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
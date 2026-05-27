import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../core/constants/note_themes.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/note.dart';
import '../providers/notes_provider.dart';
import '../widgets/checklist_widget.dart';
import '../widgets/note_toolbar.dart';
import 'drawing_screen.dart';
import '../providers/settings_provider.dart';
import 'package:flutter/gestures.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/cloudinary_service.dart';
enum _BlockType { text, image, drawing }

class _ContentBlock {
  final _BlockType type;
  QuillController? quillCtrl;
  FocusNode? focusNode;
  String? mediaPath;
  bool isMinimized;

  _ContentBlock.text()
      : type = _BlockType.text,
        isMinimized = false {
    quillCtrl = QuillController.basic();
    focusNode = FocusNode();
  }

  _ContentBlock.image(String path)
      : type = _BlockType.image,
        mediaPath = path,
        isMinimized = false;

  _ContentBlock.drawing(String path)
      : type = _BlockType.drawing,
        mediaPath = path,
        isMinimized = false;

  void dispose() {
    quillCtrl?.dispose();
    focusNode?.dispose();
  }
}

class NoteEditorScreen extends StatefulWidget {
  final String? noteId;
  final String noteType;

  const NoteEditorScreen({
    super.key,
    this.noteId,
    this.noteType = 'TEXT',
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}


class _NoteEditorScreenState extends State<NoteEditorScreen> {
  // Checklist state
  bool _isBeingDeleted = false;
  ChecklistItem? _focusedChecklistItem;
  bool _lastFocusWasChecklist = false;

  final _titleCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Note? _note;
  bool _isNew = true;
  DateTime _lastEdited = DateTime.now();
  final _charCount = ValueNotifier<int>(0);
  String? _activePanel;
  String _themeId = 'default';
  int _focusedBlockIndex = 0;

  final List<_ContentBlock> _blocks = [];
  final _picker = ImagePicker();

  final List<ChecklistItem> _checklistItems = [];
  bool _showChecklist = false;
NoteTheme get _currentTheme => NoteThemes.getById(_themeId);

// When the note is using the 'default' theme, follow the app's
// light/dark setting instead of always using a hardcoded dark color.
bool get _noteIsDefault => _themeId == 'default';

Color _bgColor(BuildContext context) {
  if (_noteIsDefault) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8);
  }
  return _currentTheme.backgroundColor;
}

Color _textColor(BuildContext context) {
  if (_noteIsDefault) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : Colors.black87;
  }
  return NoteThemes.isDark(_currentTheme) ? Colors.white : Colors.black87;
}

Color _hintColor(BuildContext context) {
  if (_noteIsDefault) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white38 : Colors.black38;
  }
  return NoteThemes.isDark(_currentTheme) ? Colors.white38 : Colors.black38;
}

Color _dividerColor(BuildContext context) {
  if (_noteIsDefault) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white12 : Colors.black12;
  }
  return NoteThemes.isDark(_currentTheme) ? Colors.white12 : Colors.black12;
}

  @override
  void initState() {
    super.initState();
    _init();
  }

  // ADDED: Clear formatting on current line method
  void _clearFormattingOnCurrentLine() {
    if (_focusedBlockIndex < _blocks.length &&
        _blocks[_focusedBlockIndex].type == _BlockType.text) {
      final ctrl = _blocks[_focusedBlockIndex].quillCtrl!;
      final selection = ctrl.selection;
      
      if (selection.isValid) {
        // Select current line
        final text = ctrl.document.toPlainText();
        int lineStart = selection.start;
        while (lineStart > 0 && text[lineStart - 1] != '\n') lineStart--;
        int lineEnd = selection.end;
        while (lineEnd < text.length && text[lineEnd] != '\n') lineEnd++;
        
        ctrl.updateSelection(
          TextSelection(baseOffset: lineStart, extentOffset: lineEnd),
          ChangeSource.local,
        );
        
        // Clear all formatting
        ctrl.formatSelection(Attribute.clone(Attribute.bold, null));
        ctrl.formatSelection(Attribute.clone(Attribute.italic, null));
        ctrl.formatSelection(Attribute.clone(Attribute.underline, null));
        ctrl.formatSelection(Attribute.clone(Attribute.strikeThrough, null));
        ctrl.formatSelection(ColorAttribute(null));
        ctrl.formatSelection(BackgroundAttribute(null));
        ctrl.formatSelection(const SizeAttribute(null));
        
        // Move cursor to end
        ctrl.updateSelection(
          TextSelection.collapsed(offset: lineEnd),
          ChangeSource.local,
        );
      }
    }
  }

_ContentBlock _makeTextBlock({String deltaJson = ''}) {
  final block = _ContentBlock.text();
  
  if (deltaJson.isNotEmpty) {
    try {
      final deltaList = jsonDecode(deltaJson) as List;
      final delta = Delta.fromJson(deltaList);
      block.quillCtrl = QuillController(
        document: Document.fromDelta(delta),
        selection: const TextSelection.collapsed(offset: 0),
        keepStyleOnNewLine: false,
      );
    } catch (_) {}
  }
  
  if (block.quillCtrl == null) {
    block.quillCtrl = QuillController(
      document: Document(),
      selection: const TextSelection.collapsed(offset: 0),
      keepStyleOnNewLine: false,
    );
  }
  
  block.focusNode = FocusNode();
  
  // Track previous plain text to detect when a newline was just inserted
  String _prevText = block.quillCtrl!.document.toPlainText();
  
  block.quillCtrl!.addListener(() {
    _onAnyTextChanged();
    
    final currentText = block.quillCtrl!.document.toPlainText();
    final selection = block.quillCtrl!.selection;
    
    // Detect a newline was just typed (not pasted, not deletion)
    final newlineJustTyped = currentText.length == _prevText.length + 1 &&
        selection.isCollapsed &&
        selection.start > 0 &&
        currentText[selection.start - 1] == '\n';
    
    _prevText = currentText;
    
    if (newlineJustTyped) {
      // Strip all inline formatting at the new cursor position
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctrl = block.quillCtrl!;
        
        // Only act if cursor is still in same spot (user didn't move)
        if (!ctrl.selection.isCollapsed) return;
        
        final inlineAttrs = [
          Attribute.bold,
          Attribute.italic,
          Attribute.underline,
          Attribute.strikeThrough,
        ];
        
        for (final attr in inlineAttrs) {
          final style = ctrl.getSelectionStyle();
          if (style.attributes.containsKey(attr.key)) {
            ctrl.formatSelection(Attribute.clone(attr, null));
          }
        }
        
        // Clear text color and highlight
        final style = ctrl.getSelectionStyle();
        if (style.attributes.containsKey(Attribute.color.key)) {
          ctrl.formatSelection(const ColorAttribute(null));
        }
        if (style.attributes.containsKey(Attribute.background.key)) {
          ctrl.formatSelection(const BackgroundAttribute(null));
        }
        // Clear heading size
        if (style.attributes.containsKey(Attribute.size.key)) {
          ctrl.formatSelection(const SizeAttribute(null));
        }
      });
    }
  });
  
  return block;
}

  void _onAnyTextChanged() {
    int total = 0;
    for (final b in _blocks) {
      if (b.type == _BlockType.text) {
        total += b.quillCtrl!.document.toPlainText().trim().length;
      }
    }
    _charCount.value = total;
  }

void _clearInlineFormattingAtCursor(QuillController ctrl) {
  final inlineAttrs = [
    Attribute.bold,
    Attribute.italic,
    Attribute.underline,
    Attribute.strikeThrough,
  ];
  
  for (final attr in inlineAttrs) {
    final style = ctrl.getSelectionStyle();
    if (style.attributes.containsKey(attr.key)) {
      ctrl.formatSelection(Attribute.clone(attr, null));
    }
  }
  
  final style = ctrl.getSelectionStyle();
  if (style.attributes.containsKey(Attribute.color.key)) {
    ctrl.formatSelection(ColorAttribute(null));
  }
  
  if (style.attributes.containsKey(Attribute.background.key)) {
    ctrl.formatSelection(BackgroundAttribute(null));
  }
  
  if (style.attributes.containsKey(Attribute.size.key)) {
    ctrl.formatSelection(const SizeAttribute(null));
  }
  
  if (style.attributes.containsKey(Attribute.font.key)) {
    ctrl.formatSelection(Attribute.clone(Attribute.font, null));
  }
  
  if (style.attributes.containsKey(Attribute.align.key)) {
    ctrl.formatSelection(Attribute.clone(Attribute.align, null));
  }
}

  Future<void> _init() async {
    if (widget.noteId != null) {
      final all = await DatabaseHelper.instance.getAllNotes();
      final found = all.where((n) => n.id == widget.noteId).toList();
      if (found.isNotEmpty) {
        _note = found.first;
        _titleCtrl.text = _note!.title;
        _isNew = false;
        _lastEdited = DateTime.fromMillisecondsSinceEpoch(_note!.updatedAt);

        if (_note!.backgroundTheme != null &&
            _note!.backgroundTheme!.isNotEmpty) {
          _themeId = _note!.backgroundTheme!;
        }

        final blocksJson = _note!.blocksJson;
        if (blocksJson != null && blocksJson.isNotEmpty) {
          try {
            final list = jsonDecode(blocksJson) as List;
            for (final item in list) {
              final map = item as Map<String, dynamic>;
              final type = map['type'] as String;
              if (type == 'text') {
                _blocks.add(_makeTextBlock(deltaJson: map['delta'] ?? ''));
              } else if (type == 'image') {
                _blocks.add(_ContentBlock.image(map['path'] as String));
              } else if (type == 'drawing') {
                _blocks.add(_ContentBlock.drawing(map['path'] as String));
              }
            }
          } catch (_) {}
        }

        if (_blocks.isEmpty) {
          _blocks.add(_makeTextBlock(deltaJson: _note!.content));
          for (final p in _note!.imagePathsList) {
            _blocks.add(_ContentBlock.image(p));
          }
          for (final p in _note!.drawingPathsList) {
            _blocks.add(_ContentBlock.drawing(p));
          }
        }
        
        // Load checklist items
final cJson = _note!.checklistJson;
if (cJson != null && cJson.isNotEmpty) {
  try {
    final list = jsonDecode(cJson) as List;
    _checklistItems.clear();
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      _checklistItems.add(ChecklistItem(
        id: m['id'],
        text: m['text'] ?? '',
        isChecked: m['isChecked'] ?? false,
        isBold: m['isBold'] ?? false,
        isItalic: m['isItalic'] ?? false,
        isUnderline: m['isUnderline'] ?? false,
        textColor: m['textColor'] != null
            ? Color(m['textColor'])
            : null,
        highlightColor: m['highlightColor'] != null
            ? Color(m['highlightColor'])
            : null,
      ));
    }
    if (_checklistItems.isNotEmpty) {
      _showChecklist = true;
    }
  } catch (_) {}
}

        if (mounted) setState(() {});
      }
    } else {
      _note = Note.create(noteType: widget.noteType);
      _lastEdited = DateTime.now();
    }

    if (_blocks.isEmpty) _blocks.add(_makeTextBlock());
    if (mounted) setState(() {});
  }

  String _serializeBlocks() {
    final list = _blocks.map((b) {
      if (b.type == _BlockType.text) {
        return {
          'type': 'text',
          'delta': jsonEncode(b.quillCtrl!.document.toDelta().toJson()),
        };
      } else if (b.type == _BlockType.image) {
        return {'type': 'image', 'path': b.mediaPath};
      } else {
        return {'type': 'drawing', 'path': b.mediaPath};
      }
    }).toList();
    return jsonEncode(list);
  }

  String _getPlainText() {
    return _blocks
        .where((b) => b.type == _BlockType.text)
        .map((b) => b.quillCtrl!.document.toPlainText().trim())
        .where((t) => t.isNotEmpty)
        .join('\n');
  }

  Future<void> _save() async {
  if (_isBeingDeleted || (_note != null && _note!.isDeleted)) {
    print('⚠️ SKIP SAVE - Note is being deleted');
    return;
  }
    //debug code
     print('🔵 SAVING - Total blocks: ${_blocks.length}');
  for (int i = 0; i < _blocks.length; i++) {
    final b = _blocks[i];
    if (b.type == _BlockType.image) {
      print('🔵 Image block $i: path = ${b.mediaPath}');
    }
  }

    final title = _titleCtrl.text.trim();
    final plainText = _getPlainText();
    final hasMedia = _blocks.any((b) => b.type != _BlockType.text);

    if (title.isEmpty && plainText.isEmpty && !hasMedia && _checklistItems.isEmpty) return;

    final provider = context.read<NotesProvider>();
final checklistJson = _checklistItems.isEmpty
    ? null
    : jsonEncode(_checklistItems.map((item) => {
        'id': item.id,
        'text': item.text,
        'isChecked': item.isChecked,
        'isBold': item.isBold,
        'isItalic': item.isItalic,
        'isUnderline': item.isUnderline,
        'textColor': item.textColor?.value,
        'highlightColor': item.highlightColor?.value,
      }).toList());

final updated = (_note ?? Note.create()).copyWith(
  title: title,
  content: plainText,
  backgroundTheme: _themeId,
  blocksJson: _serializeBlocks(),
  checklistJson: checklistJson,
);

    if (_isNew) {
      await provider.add(updated);
      _isNew = false;
      _note = updated;
    } else {
      await provider.update(updated);
      _note = updated;
    }

    _lastEdited = DateTime.now();
    if (mounted) setState(() {});
  }

  void _insertImageBlock(String path) {
    setState(() {
      final insertAt = _focusedBlockIndex + 1;
      _blocks.insert(insertAt, _ContentBlock.image(path));
      if (insertAt + 1 >= _blocks.length ||
          _blocks[insertAt + 1].type != _BlockType.text) {
        _blocks.insert(insertAt + 1, _makeTextBlock());
      }
      _focusedBlockIndex = insertAt + 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final idx = _focusedBlockIndex;
      if (idx < _blocks.length && _blocks[idx].type == _BlockType.text) {
        _blocks[idx].focusNode?.requestFocus();
      }
    });
  }

  void _insertDrawingBlock(String path) {
    setState(() {
      final insertAt = _focusedBlockIndex + 1;
      _blocks.insert(insertAt, _ContentBlock.drawing(path));
      if (insertAt + 1 >= _blocks.length ||
          _blocks[insertAt + 1].type != _BlockType.text) {
        _blocks.insert(insertAt + 1, _makeTextBlock());
      }
      _focusedBlockIndex = insertAt + 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final idx = _focusedBlockIndex;
      if (idx < _blocks.length && _blocks[idx].type == _BlockType.text) {
        _blocks[idx].focusNode?.requestFocus();
      }
    });
  }

  void _deleteBlock(int index) {
    setState(() {
      _blocks[index].dispose();
      _blocks.removeAt(index);
      if (_blocks.isEmpty) _blocks.add(_makeTextBlock());
      _focusedBlockIndex = (index - 1).clamp(0, _blocks.length - 1);
    });
  }

  void _showThemePicker() {
    setState(() => _activePanel = _activePanel == 'theme' ? null : 'theme');
  }

Future<void> _pickFromFilePicker() async {
  print('🔵🔵🔵 _pickFromFilePicker CALLED 🔵🔵🔵');
  try {
    final imageFile = await CloudinaryService().pickImage();
    print('🔵 After pickImage, file: ${imageFile?.name}');
    if (imageFile == null) return;
    
    print('🔵 Starting upload...');
    final imageUrl = await CloudinaryService().uploadImage(imageFile);
    print('🔵 Upload complete, URL: $imageUrl');
    _insertImageBlock(imageUrl);
  } catch (e) {
    print('❌ ERROR: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not upload image: $e'),
        backgroundColor: Colors.redAccent,
      ));
    }
  }
}

Future<void> _pickFromCamera() async {
  try {
    final imageFile = await CloudinaryService().pickImage();
    if (imageFile == null) return;
    
    final imageUrl = await CloudinaryService().uploadImage(imageFile);
    _insertImageBlock(imageUrl);
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Camera not available'),
        backgroundColor: Color(0xFF2C2C2C),
      ));
    }
  }
}

void _showImageSourceSheet() {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final sheetBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
  final textColor = isDark ? Colors.white : Colors.black87;
  final iconColor = isDark ? Colors.white70 : Colors.black54;

  showModalBottomSheet(
    context: context,
    backgroundColor: sheetBg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.photo_library, color: iconColor),
            title: Text('Choose from gallery',
                style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.pop(context);
              _pickFromFilePicker();
            },
          ),
          ListTile(
            leading: Icon(Icons.camera_alt, color: iconColor),
            title:
                Text('Take a photo', style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.pop(context);
              _pickFromCamera();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ── Reminder picker ───────────────────────────────────────────
Future<void> _showReminderPicker() async {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  DateTime selectedDate = _note?.reminderTime != null &&
          _note!.reminderTime! > 0
      ? DateTime.fromMillisecondsSinceEpoch(_note!.reminderTime!)
      : DateTime.now().add(const Duration(hours: 1));

  final minutes = (selectedDate.minute / 5).ceil() * 5;
  selectedDate = DateTime(selectedDate.year, selectedDate.month,
      selectedDate.day, selectedDate.hour, minutes % 60);

  final result = await showDialog<DateTime>(
    context: context,
    builder: (ctx) => _ReminderPickerDialog(
      initial: selectedDate,
      isDark: isDark,
    ),
  );

  if (result == null) return;

  // result == DateTime(0) means user tapped Remove
  final removing = result.year == 0;

  await _save();
  final provider = context.read<NotesProvider>();
  final settings = context.read<SettingsProvider>();

  if (removing) {
    // Cancel notification and clear reminderTime
    if (_note != null) {
      await NotificationService.instance.cancelReminder(_note!.id);
      final updated = _note!.copyWith(clearReminder: true);
      await provider.update(updated);
      _note = updated;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Reminder removed'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  } else {
    // Save reminder time
    final updated = (_note ?? Note.create()).copyWith(
      title: _titleCtrl.text.trim(),
      reminderTime: result.millisecondsSinceEpoch,
    );
    if (_isNew) {
      await provider.add(updated);
      _isNew = false;
    } else {
      await provider.update(updated);
    }
    _note = updated;

    // Schedule notification
    await NotificationService.instance.requestPermissions();
    await NotificationService.instance.scheduleReminder(
      noteId: _note!.id,
      noteTitle:
          _titleCtrl.text.trim().isEmpty ? 'Note' : _titleCtrl.text.trim(),
      scheduledTime: result,
      highPriority: settings.highPrioritySound,
      soundFile: settings.reminderSound,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Reminder set for ${DateFormat('EEE, d MMM • HH:mm').format(result)}',
        ),
        backgroundColor:
            isDark ? const Color(0xFF2C2C2C) : Colors.black87,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
  setState(() {});
}

  String _formatDate(DateTime dt) => DateFormat('d MMMM h:mm a').format(dt);

void _showComingSoon(String feature) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text('$feature — coming soon'),
    duration: const Duration(seconds: 2),
    backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.black87,
  ));
}

  @override
  void dispose() {
    for (final b in _blocks) b.dispose();
    _titleCtrl.dispose();
    _charCount.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

Widget _buildTextBlock(BuildContext context, int index, _ContentBlock block) {
  block.focusNode!.onKeyEvent = (node, event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        final isEmpty = block.quillCtrl!.document.toPlainText().trim().isEmpty;
        if (isEmpty && index > 0) {
          setState(() {
            block.dispose();
            _blocks.removeAt(index);
            _focusedBlockIndex = (index - 1).clamp(0, _blocks.length - 1);
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final prev = _focusedBlockIndex;
            if (prev < _blocks.length && _blocks[prev].type == _BlockType.text) {
              _blocks[prev].focusNode?.requestFocus();
            }
          });
          return KeyEventResult.handled;
        }
      }

      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        Future.delayed(const Duration(milliseconds: 10), () {
          final ctrl = block.quillCtrl!;
          final selection = ctrl.selection;
          
          if (selection.isValid) {
            final pos = selection.baseOffset;
            
            ctrl.updateSelection(
              TextSelection(baseOffset: pos, extentOffset: pos + 1),
              ChangeSource.local,
            );
            
            ctrl.formatSelection(Attribute.clone(Attribute.bold, null));
            ctrl.formatSelection(Attribute.clone(Attribute.italic, null));
            ctrl.formatSelection(Attribute.clone(Attribute.underline, null));
            ctrl.formatSelection(Attribute.clone(Attribute.strikeThrough, null));
            ctrl.formatSelection(ColorAttribute(null));
            ctrl.formatSelection(BackgroundAttribute(null));
            ctrl.formatSelection(const SizeAttribute(null));
            
            ctrl.updateSelection(
              TextSelection.collapsed(offset: pos),
              ChangeSource.local,
            );
          }
        });
        return KeyEventResult.ignored;
      }
    }
    return KeyEventResult.ignored;
  };

  final isEmpty = block.quillCtrl!.document.toPlainText().trim().isEmpty;

  return Container(
    width: double.infinity,
    constraints: BoxConstraints(minHeight: isEmpty ? 44 : 0),
    child: Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Focus(
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              setState(() {
                _focusedBlockIndex = index;
                _lastFocusWasChecklist = false; // text block took focus
                _focusedChecklistItem = null;
              });
            }
          },
            child: DefaultTextStyle(
              style: TextStyle(
                color: _textColor(context), 
                fontSize: 15, 
                height: 1.6
              ),
              child: QuillEditor(
                controller: block.quillCtrl!,
                focusNode: block.focusNode!,
                scrollController: ScrollController(),
                config: QuillEditorConfig(
                  scrollable: false,
                  autoFocus: false,
                  expands: false,
                  placeholder: index == 0 ? 'Start writing...' : '',
                  customStyles: DefaultStyles(
                    paragraph: DefaultTextBlockStyle(
                      TextStyle(
                        color: _textColor(context),
                        fontSize: 15,
                        height: 1.6,
                      ),
                      HorizontalSpacing.zero,
                      VerticalSpacing.zero,
                      VerticalSpacing.zero,
                      null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isEmpty)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() => _focusedBlockIndex = index);
                block.focusNode?.requestFocus();
              },
            ),
          ),
      ],
    ),
  );
}
  Widget _buildImageBlock(int index, _ContentBlock block) {
    final path = block.mediaPath!;
    final mini = block.isMinimized;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fullW = constraints.maxWidth;
        final imgW = mini ? fullW * 0.45 : fullW;
        final imgH = mini ? 90.0 : 200.0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
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
                  _buildImageWidget(path),
                  Positioned(
                    top: 4, right: 36,
                    child: GestureDetector(
                      onTap: () => setState(
                          () => block.isMinimized = !block.isMinimized),
                      child: Container(
                        width: 26, height: 26,
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: Icon(
                            mini ? Icons.fullscreen : Icons.fullscreen_exit,
                            color: Colors.white, size: 15),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => _deleteBlock(index),
                      child: Container(
                        width: 26, height: 26,
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageWidget(String path) {
    if (path.startsWith('data:image')) {
      final bytes = base64Decode(path.split(',').last);
      return Image.memory(bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true);
    }
    if (kIsWeb) {
      return Image.network(path,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity);
    }
    return Image.file(File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity);
  }

  Widget _buildDrawingBlock(int index, _ContentBlock block) {
    final path = block.mediaPath!;
    Widget img;
    try {
      final bytes = base64Decode(
          path.contains(',') ? path.split(',').last : path);
      img = Image.memory(bytes, width: double.infinity, fit: BoxFit.contain);
    } catch (_) {
      if (!kIsWeb && File(path).existsSync()) {
        img = Image.file(File(path),
            width: double.infinity, fit: BoxFit.contain);
      } else {
        img = const SizedBox.shrink();
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Stack(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: img),
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: () => _deleteBlock(index),
              child: Container(
                width: 24, height: 24,
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildBlock(BuildContext context, int index, _ContentBlock block) {
  switch (block.type) {
    case _BlockType.text:
      return _buildTextBlock(context, index, block);
      case _BlockType.image:
        return _buildImageBlock(index, block);
      case _BlockType.drawing:
        return _buildDrawingBlock(index, block);
    }
  }

  Widget _buildBottomPanel() {
    QuillController? activeCtrl;
    FocusNode? activeFocusNode;
    if (_focusedBlockIndex < _blocks.length &&
        _blocks[_focusedBlockIndex].type == _BlockType.text) {
      activeCtrl = _blocks[_focusedBlockIndex].quillCtrl;
      activeFocusNode = _blocks[_focusedBlockIndex].focusNode;
    } else {
      for (int i = _blocks.length - 1; i >= 0; i--) {
        if (_blocks[i].type == _BlockType.text) {
          activeCtrl = _blocks[i].quillCtrl;
          activeFocusNode = _blocks[i].focusNode;
          break;
        }
      }
    }

    return Listener(
      onPointerDown: (event) {},
      behavior: HitTestBehavior.translucent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
  builder: (context) => Divider(color: _dividerColor(context), height: 1),
),

          if (_activePanel == 'format' && activeCtrl != null)
            ExcludeFocus(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PanelHeader(
                    title: 'Text formatting',
                    onClose: () => setState(() => _activePanel = null),
                  ),
// FIND the entire NoteToolbar(...) call and REPLACE WITH:
// FIND the Builder that builds NoteToolbar and REPLACE WITH:
// FIND the entire Builder(...) block and REPLACE WITH:
          Builder(
            builder: (context) {
              final QuillController activeCtrl;
              final FocusNode activeFocus;

              if (_focusedBlockIndex < _blocks.length &&
                  _blocks[_focusedBlockIndex].type == _BlockType.text) {
                activeCtrl = _blocks[_focusedBlockIndex].quillCtrl!;
                activeFocus = _lastFocusWasChecklist
                    ? FocusNode()
                    : _blocks[_focusedBlockIndex].focusNode!;
              } else {
                final textBlock = _blocks.firstWhere(
                  (b) => b.type == _BlockType.text,
                  orElse: () => _blocks.first,
                );
                activeCtrl = textBlock.quillCtrl!;
                activeFocus = _lastFocusWasChecklist
                    ? FocusNode()
                    : textBlock.focusNode!;
              }

              // Use _focusedChecklistItem directly — don't rely on _lastFocusWasChecklist
              final isChecklist = _focusedChecklistItem != null && _lastFocusWasChecklist;

              return NoteToolbar(
                controller: activeCtrl,
                editorFocusNode: activeFocus,
                isChecklistMode: isChecklist,
                onBoldChanged: isChecklist ? (v) {
                  if (_focusedChecklistItem == null) return;
                  _focusedChecklistItem!.isBold = v;
                  setState(() {});
                  _save();
                } : null,
                onItalicChanged: isChecklist ? (v) {
                  if (_focusedChecklistItem == null) return;
                  _focusedChecklistItem!.isItalic = v;
                  setState(() {});
                  _save();
                } : null,
                onUnderlineChanged: isChecklist ? (v) {
                  if (_focusedChecklistItem == null) return;
                  _focusedChecklistItem!.isUnderline = v;
                  setState(() {});
                  _save();
                } : null,
                onColorChanged: isChecklist ? (c) {
                  if (_focusedChecklistItem == null) return;
                  _focusedChecklistItem!.textColor = c;
                  setState(() {});
                  _save();
                } : null,
                onHighlightChanged: isChecklist ? (c) {
                  if (_focusedChecklistItem == null) return;
                  _focusedChecklistItem!.highlightColor = c;
                  setState(() {});
                  _save();
                } : null,
              );
            },
          ),
                ],
              ),
            ),

          if (_activePanel == 'theme')
            _ThemeScrollRow(
              currentThemeId: _themeId,
              onThemeSelected: (theme) =>
                  setState(() => _themeId = theme.id),
              onClose: () => setState(() => _activePanel = null),
            ),

          _BottomActionBar(
            activePanel: _activePanel,
            onImage: () {
              setState(() => _activePanel = null);
              _showImageSourceSheet();
            },
            onDrawing: () async {
              setState(() => _activePanel = null);
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => const DrawingScreen()),
              );
              if (result != null && result.isNotEmpty) {
                _insertDrawingBlock(result);
              }
            },
            onChecklist: () {
              final isActive = _activePanel == 'checklist';
              setState(() {
                _activePanel = isActive ? null : 'checklist';
                if (!isActive) {
                  _showChecklist = true;
                  if (_checklistItems.isEmpty) {
                    _checklistItems.add(ChecklistItem());
                  }
                } else {
                  _showChecklist = false;
                }
              });
              // Scroll down so checklist is visible after text blocks
              if (!isActive) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.animateTo(
                      _scrollCtrl.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });
              }
            },
            onText: () {
              setState(() {
                _activePanel = _activePanel == 'format' ? null : 'format';
                if (_activePanel == 'format' && _focusedChecklistItem == null) {
                  _lastFocusWasChecklist = false;
                }
              });
              // Re-focus the active text block so headings work
              if (_activePanel == 'format' && !_lastFocusWasChecklist) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_focusedBlockIndex < _blocks.length &&
                      _blocks[_focusedBlockIndex].type == _BlockType.text) {
                    _blocks[_focusedBlockIndex].focusNode?.requestFocus();
                  }
                });
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ADDED: Wrap with CallbackShortcuts and Focus for keyboard shortcut
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true): 
          _clearFormattingOnCurrentLine,
      },
      child: Focus(
        autofocus: true,
        canRequestFocus: true,
        child: PopScope(
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop && !_isBeingDeleted) {
            await _save();
          }
        },
          child: Scaffold(
          backgroundColor: _bgColor(context),
          appBar: AppBar(
          backgroundColor: _bgColor(context),
              elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _textColor(context)),
            onPressed: () async {
              if (!_isBeingDeleted) {
                await _save();
              }
              ScaffoldMessenger.of(context).clearSnackBars();
              if (context.mounted) context.go('/');
            },
          ),
              iconTheme: IconThemeData(color: _textColor(context)),
              actions: [
                // ADDED: Clear Format button
                // IconButton(
                //   icon: Icon(Icons.format_clear, color: _textColor(context)),
                //   tooltip: 'Clear line formatting (Ctrl+Shift+C)',
                //   onPressed: _clearFormattingOnCurrentLine,
                // ),
                IconButton(
                  icon: Icon(Icons.checkroom, color: _textColor(context)),
                  tooltip: 'Theme',
                  onPressed: _showThemePicker,
                ),
                IconButton(
                  icon: Icon(Icons.check, color: _textColor(context)),
                  tooltip: 'Save',
                  onPressed: () async {
                    await _save();
                    if (context.mounted) context.go('/');
                  },
                ),

                // Reminder button
                IconButton(
                  icon: Icon(
                    _note?.reminderTime != null
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                    color: _note?.reminderTime != null
                        ? const Color(0xFFFA337C)
                        : _textColor(context),
                  ),
                  tooltip: 'Set reminder',
                  onPressed: _showReminderPicker,
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: _textColor(context)),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2C2C2C)
                      : Colors.white,
                  onSelected: (val) async {
                    if (val == 'delete') {
                      if (!_isNew && _note != null) {
                        _isBeingDeleted = true; // set flag BEFORE softDelete
                        await context.read<NotesProvider>().softDelete(_note!.id);
                      }
                      if (context.mounted) context.go('/');
                      } else if (val == 'archive') {
                        if (!_isNew && _note != null) {
                          _isBeingDeleted = true; // prevent save on pop for archive too
                          await context.read<NotesProvider>().toggleArchive(_note!);
                        }
                        if (context.mounted) context.go('/');
                      } else if (val == 'pin') {
                      if (_note != null) {
                        setState(() =>
                            _note = _note!.copyWith(isPinned: !_note!.isPinned));
                      }
                    }
                  },
                  itemBuilder: (menuContext) {
                    final menuIsDark = Theme.of(menuContext).brightness == Brightness.dark;
                    final menuTextColor = menuIsDark ? Colors.white : Colors.black87;
                    final menuIconColor = menuIsDark ? Colors.white70 : Colors.black54;
                    return [
                      PopupMenuItem(
                        value: 'pin',
                        child: Row(children: [
                          Icon(
                              _note?.isPinned == true
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                              color: menuIconColor, size: 18),
                          const SizedBox(width: 8),
                          Text(_note?.isPinned == true ? 'Unpin' : 'Pin',
                              style: TextStyle(color: menuTextColor)),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'archive',
                        child: Row(children: [
                          Icon(Icons.archive, color: menuIconColor, size: 18),
                          const SizedBox(width: 8),
                          Text('Archive', style: TextStyle(color: menuTextColor)),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          const Text('Delete',
                              style: TextStyle(color: Colors.redAccent)),
                        ]),
                      ),
                    ];
                  },
                ),
              ],
            ),
            body: CustomPaint(
  painter: _NoteBgPainter(_currentTheme, _bgColor(context)),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: TextField(
                      controller: _titleCtrl,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) {
                        if (_blocks.isNotEmpty &&
                            _blocks[0].type == _BlockType.text) {
                          _blocks[0].focusNode?.requestFocus();
                        }
                      },
                      style: TextStyle(
                          color: _textColor(context),
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Title',
                        hintStyle: TextStyle(
                            color: _hintColor(context),
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                      Text(_formatDate(_lastEdited),
                          style: TextStyle(color: _hintColor(context), fontSize: 12)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('|',
                            style: TextStyle(color: _dividerColor(context), fontSize: 12)),
                      ),
                        ValueListenableBuilder<int>(
                          valueListenable: _charCount,
                          builder: (_, count, __) => Text('$count characters',
                              style:
                                  TextStyle(color: _hintColor(context), fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: _dividerColor(context), height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollCtrl,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.manual,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < _blocks.length; i++)
                           _buildBlock(context, i, _blocks[i]),
                        if (_showChecklist)
                          ChecklistWidget(
                            key: ValueKey(_checklistItems
                                .map((i) => '${i.id}${i.isBold}${i.isItalic}${i.isUnderline}${i.textColor}${i.highlightColor}')
                                .join()),
                            items: _checklistItems,
                            onChanged: _save,
                            textColor: _textColor(context),
                            hintColor: _hintColor(context),
                            checkColor: const Color(0xFFFA337C),
                            borderColor: _textColor(context).withOpacity(0.4),
                            onFocusedItemChanged: (item) {
                              
                              if (item != null) {
                                _focusedChecklistItem = item;
                                _lastFocusWasChecklist = true;
                              }
                            },
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomPanel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Background painter ────────────────────────────────────────
class _NoteBgPainter extends CustomPainter {
  final NoteTheme theme;
  final Color bgColor;
  _NoteBgPainter(this.theme, this.bgColor);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = bgColor);
    if (theme.patternType == 'lines') {
      final paint = Paint()
        ..color = theme.patternColor ?? Colors.grey.withOpacity(0.3)
        ..strokeWidth = 1;
      for (double y = 40; y < size.height; y += 28) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    } else if (theme.patternType == 'dots') {
      final paint = Paint()
        ..color = theme.patternColor ?? Colors.grey.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      for (double y = 24; y < size.height; y += 24) {
        for (double x = 24; x < size.width; x += 24) {
          canvas.drawCircle(Offset(x, y), 1.5, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_NoteBgPainter old) => old.theme.id != theme.id;
}

// ── Panel header ──────────────────────────────────────────────
class _PanelHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  const _PanelHeader({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);
    final textColor = isDark ? Colors.white54 : Colors.black45;
    final borderColor = isDark ? Colors.white24 : Colors.black12;
    final closeColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5)),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 1),
                  borderRadius: BorderRadius.circular(6)),
              child: Center(
                child: Text('×',
                    style: TextStyle(
                        color: closeColor,
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w300)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────
class _BottomActionBar extends StatelessWidget {
  final String? activePanel;
  final VoidCallback onImage, onDrawing, onChecklist, onText;

  const _BottomActionBar({
    required this.activePanel,
    //required this.onAudio,
    required this.onImage,
    required this.onDrawing,
    required this.onChecklist,
    required this.onText,
  });

@override
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEEEEEE);
  final iconColor = isDark ? Colors.white54 : Colors.black45;
  final activeIconColor = isDark ? Colors.white : Colors.black87;
  final labelColor = isDark ? Colors.white38 : Colors.black38;
  final activeLabelColor = isDark ? Colors.white : Colors.black87;
  final activeBg = isDark
      ? Colors.white.withOpacity(0.1)
      : Colors.black.withOpacity(0.08);

  return Container(
    color: bg,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Row(
      children: [
        _ActionBtn(icon: Icons.image_outlined, label: 'Image',
            isActive: activePanel == 'image', onTap: onImage,
            iconColor: iconColor, activeIconColor: activeIconColor,
            labelColor: labelColor, activeLabelColor: activeLabelColor,
            activeBg: activeBg),
        _ActionBtn(icon: Icons.draw_outlined, label: 'Drawing',
            isActive: activePanel == 'drawing', onTap: onDrawing,
            iconColor: iconColor, activeIconColor: activeIconColor,
            labelColor: labelColor, activeLabelColor: activeLabelColor,
            activeBg: activeBg),
        _ActionBtn(icon: Icons.check_box_outlined, label: 'List',
            isActive: activePanel == 'checklist', onTap: onChecklist,
            iconColor: iconColor, activeIconColor: activeIconColor,
            labelColor: labelColor, activeLabelColor: activeLabelColor,
            activeBg: activeBg),
        _ActionBtn(icon: Icons.text_format, label: 'Text',
            isActive: activePanel == 'format', onTap: onText,
            iconColor: iconColor, activeIconColor: activeIconColor,
            labelColor: labelColor, activeLabelColor: activeLabelColor,
            activeBg: activeBg),
      ],
    ),
  );
}
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color iconColor;
  final Color activeIconColor;
  final Color labelColor;
  final Color activeLabelColor;
  final Color activeBg;

  const _ActionBtn({
    required this.icon, required this.label,
    required this.isActive, required this.onTap,
    required this.iconColor, required this.activeIconColor,
    required this.labelColor, required this.activeLabelColor,
    required this.activeBg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: isActive ? activeIconColor : iconColor,
                  size: 22),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      color: isActive ? activeLabelColor : labelColor,
                      fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Theme scroll row ──────────────────────────────────────────
class _ThemeScrollRow extends StatefulWidget {
  final String currentThemeId;
  final Function(NoteTheme) onThemeSelected;
  final VoidCallback onClose;

  const _ThemeScrollRow({
      required this.currentThemeId,
      required this.onThemeSelected,
      required this.onClose});

  @override
  State<_ThemeScrollRow> createState() => _ThemeScrollRowState();
}

class _ThemeScrollRowState extends State<_ThemeScrollRow> {
  final ScrollController _scrollCtrl = ScrollController();
  bool _isDragging = false;
  double _dragStartX = 0;
  double _scrollStartOffset = 0;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _isReady = true);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEEEEEE);
    final thumbColor = const Color(0xFFFFA000);
    final borderColor = isDark ? Colors.white24 : Colors.black12;
    final closeColor = isDark ? Colors.white70 : Colors.black54;
    final themeNameSelected = const Color(0xFFFFA000);
    final themeNameUnselected = isDark ? Colors.white54 : Colors.black45;
    final scrollTrackColor = isDark ? Colors.white10 : Colors.black12;

    return Container(
      color: bg,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 44, 6),
            child: LayoutBuilder(builder: (context, constraints) {
              return GestureDetector(
                onHorizontalDragUpdate: (details) {
                  if (!_isReady || !_scrollCtrl.hasClients) return;
                  final maxScroll = _scrollCtrl.position.maxScrollExtent;
                  if (maxScroll <= 0) return;
                  final ratio =
                      details.localPosition.dx / constraints.maxWidth;
                  _scrollCtrl
                      .jumpTo((ratio * maxScroll).clamp(0.0, maxScroll));
                },
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                      color: scrollTrackColor,
                      borderRadius: BorderRadius.circular(9)),
                  child: !_isReady
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                              widthFactor: 0.3,
                              child: Container(
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFFFA000),
                                      borderRadius:
                                          BorderRadius.circular(9)))))
                      : AnimatedBuilder(
                          animation: _scrollCtrl,
                          builder: (_, __) {
                            if (!_scrollCtrl.hasClients) {
                              return Container(
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFFFA000),
                                      borderRadius: BorderRadius.circular(9)));
                            }
                            final maxScroll =
                                _scrollCtrl.position.maxScrollExtent;
                            if (maxScroll <= 0) {
                              return Container(
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFFFA000),
                                      borderRadius: BorderRadius.circular(9)));
                            }
                            final thumbFraction = (constraints.maxWidth /
                                    (maxScroll + constraints.maxWidth))
                                .clamp(0.1, 1.0);
                            final thumbLeft =
                                (_scrollCtrl.offset / maxScroll) *
                                    constraints.maxWidth *
                                    (1 - thumbFraction);
                            return Stack(children: [
                              Positioned(
                                  left: thumbLeft,
                                  top: 2,
                                  bottom: 2,
                                  width: constraints.maxWidth * thumbFraction,
                                  child: Container(
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFFFA000),
                                          borderRadius:
                                              BorderRadius.circular(9)))),
                            ]);
                          }),
                ),
              );
            }),
          ),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 115,
                child: Listener(
                  onPointerDown: (e) {
                    _isDragging = true;
                    _dragStartX = e.position.dx;
                    _scrollStartOffset = _scrollCtrl.offset;
                  },
                  onPointerMove: (e) {
                    if (!_isDragging) return;
                    final delta = _dragStartX - e.position.dx;
                    _scrollCtrl.jumpTo((_scrollStartOffset + delta).clamp(
                        0.0, _scrollCtrl.position.maxScrollExtent));
                  },
                  onPointerUp: (_) => _isDragging = false,
                  onPointerCancel: (_) => _isDragging = false,
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                    itemCount: NoteThemes.all.length,
                    itemBuilder: (_, i) {
                      final theme = NoteThemes.all[i];
                      final isSelected = theme.id == widget.currentThemeId;
                      return GestureDetector(
                        onTap: () => widget.onThemeSelected(theme),
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 10),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 80, height: 88,
                                  decoration: BoxDecoration(
                                    color: theme.backgroundColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSelected
                                        ? Border.all(
                                            color: const Color(0xFFFFA000),
                                            width: 3)
                                        : Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 1),
                                  ),
                                  child: isSelected
                                      ? const Center(
                                          child: Icon(Icons.check_circle,
                                              color: Color(0xFFFFA000),
                                              size: 24))
                                      : null,
                                ),
                                const SizedBox(height: 5),
                                SizedBox(
                                    height: 14,
                                    child: Text(theme.name,
                                      style: TextStyle(
                                      color: isSelected ? themeNameSelected : themeNameUnselected,
                                        fontSize: 10,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    )),
                              ]),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: widget.onClose,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                width: 28, height: 28,
                decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 1),
                    borderRadius: BorderRadius.circular(6)),
                child:  Center(
                    child: Text('×',
                        style: TextStyle(
                            color: closeColor,
                            fontSize: 20,
                            height: 1))),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Reminder picker dialog ────────────────────────────────────
class _ReminderPickerDialog extends StatefulWidget {
  final DateTime initial;
  final bool isDark;

  const _ReminderPickerDialog({
    required this.initial,
    required this.isDark,
  });

  @override
  State<_ReminderPickerDialog> createState() => _ReminderPickerDialogState();
}

class _ReminderPickerDialogState extends State<_ReminderPickerDialog> {
  late DateTime _selected;
  late final List<DateTime> _days;

  // Current index state for each column
  late int _dayIndex;
  late int _hourIndex;
  late int _minuteIndex;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;

    final today = DateTime.now();
    _days = List.generate(
        365, (i) => DateTime(today.year, today.month, today.day + i));

    final dayIdx = _days.indexWhere((d) =>
        d.year == _selected.year &&
        d.month == _selected.month &&
        d.day == _selected.day);

    _dayIndex = dayIdx < 0 ? 0 : dayIdx;
    _hourIndex = _selected.hour;
    _minuteIndex = _selected.minute;
  }

  void _setDay(int i) {
    if (i < 0 || i >= _days.length) return;
    setState(() {
      _dayIndex = i;
      final d = _days[i];
      _selected = DateTime(
          d.year, d.month, d.day, _selected.hour, _selected.minute);
    });
  }

  void _setHour(int i) {
    if (i < 0 || i >= 24) return;
    setState(() {
      _hourIndex = i;
      _selected = DateTime(_selected.year, _selected.month,
          _selected.day, i, _selected.minute);
    });
  }

  void _setMinute(int i) {
    if (i < 0 || i >= 60) return;
    setState(() {
      _minuteIndex = i;
      _selected = DateTime(_selected.year, _selected.month,
          _selected.day, _selected.hour, i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black45;
    final selectedColor = const Color(0xFFFA337C);
    final dividerColor = isDark ? Colors.white12 : Colors.black12;
    final cancelBg =
        isDark ? const Color(0xFF3A3A3A) : const Color(0xFFEEEEEE);

    return Dialog(
      backgroundColor: bg,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Set reminder',
                style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              DateFormat('EEE, d MMM • HH:mm').format(_selected),
              style: TextStyle(color: selectedColor, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // ── Picker row ────────────────────────────────
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  // Day
                  Expanded(
                    flex: 5,
                    child: _WheelPicker(
                      itemCount: _days.length,
                      selectedIndex: _dayIndex,
                      onChanged: _setDay,
                      itemLabel: (i) {
                        final d = _days[i];
                        return i == 0
                            ? 'Today'
                            : DateFormat('EEE, d MMM').format(d);
                      },
                      textColor: textColor,
                      selectedColor: selectedColor,
                      dividerColor: dividerColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Hour
                  Expanded(
                    flex: 2,
                    child: _WheelPicker(
                      itemCount: 24,
                      selectedIndex: _hourIndex,
                      onChanged: _setHour,
                      itemLabel: (i) => i.toString().padLeft(2, '0'),
                      textColor: textColor,
                      selectedColor: selectedColor,
                      dividerColor: dividerColor,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(':',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                  ),
                  // Minute
                  Expanded(
                    flex: 2,
                    child: _WheelPicker(
                      itemCount: 60,
                      selectedIndex: _minuteIndex,
                      onChanged: _setMinute,
                      itemLabel: (i) => i.toString().padLeft(2, '0'),
                      textColor: textColor,
                      selectedColor: selectedColor,
                      dividerColor: dividerColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Divider(color: dividerColor, height: 1),
            const SizedBox(height: 12),

            // ── Buttons ───────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, DateTime(0)),
                    child: const Text('Remove',
                        style: TextStyle(
                            color: Colors.redAccent, fontSize: 14)),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          color: cancelBg,
                          borderRadius: BorderRadius.circular(10)),
                      child: Center(
                        child: Text('Cancel',
                            style:
                                TextStyle(color: subColor, fontSize: 14)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, _selected),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          color: selectedColor,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Center(
                        child: Text('OK',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom wheel picker — works on mouse + touch ──────────────
class _WheelPicker extends StatefulWidget {
  final int itemCount;
  final int selectedIndex;
  final void Function(int) onChanged;
  final String Function(int) itemLabel;
  final Color textColor;
  final Color selectedColor;
  final Color dividerColor;

  const _WheelPicker({
    required this.itemCount,
    required this.selectedIndex,
    required this.onChanged,
    required this.itemLabel,
    required this.textColor,
    required this.selectedColor,
    required this.dividerColor,
  });

  @override
  State<_WheelPicker> createState() => _WheelPickerState();
}

class _WheelPickerState extends State<_WheelPicker> {
  static const double _itemH = 44.0;
  late ScrollController _ctrl;
  int _current = 0;

  // Drag tracking
  double _dragStartY = 0;
  int _dragStartIndex = 0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _current = widget.selectedIndex;
    _ctrl = ScrollController(
        initialScrollOffset: _current * _itemH);
  }

  @override
  void didUpdateWidget(_WheelPicker old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      _current = widget.selectedIndex;
      _scrollTo(_current, animate: false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _scrollTo(int index, {bool animate = true}) {
    final target = index.clamp(0, widget.itemCount - 1) * _itemH;
    if (animate) {
      _ctrl.animateTo(target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut);
    } else {
      if (_ctrl.hasClients) _ctrl.jumpTo(target);
    }
  }

  void _select(int index) {
    final clamped = index.clamp(0, widget.itemCount - 1);
    if (clamped == _current) return;
    setState(() => _current = clamped);
    _scrollTo(clamped);
    widget.onChanged(clamped);
  }

  // ── Pointer (mouse wheel) ─────────────────────────────────
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Each notch of mouse wheel scrolls exactly 1 item
      if (event.scrollDelta.dy > 0) {
        _select(_current + 1);
      } else if (event.scrollDelta.dy < 0) {
        _select(_current - 1);
      }
    }
  }

  // ── Drag (touch + mouse drag) ─────────────────────────────
  void _onDragStart(DragStartDetails d) {
    _dragStartY = d.globalPosition.dy;
    _dragStartIndex = _current;
    _dragging = true;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    final dy = _dragStartY - d.globalPosition.dy;
    // 1 item per _itemH pixels dragged
    final delta = (dy / _itemH).round();
    final target = (_dragStartIndex + delta).clamp(0, widget.itemCount - 1);
    if (target != _current) {
      setState(() => _current = target);
      _scrollTo(target);
      widget.onChanged(target);
    }
  }

  void _onDragEnd(DragEndDetails _) {
    _dragging = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        onVerticalDragStart: _onDragStart,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: ClipRect(
          child: Stack(
            children: [
              // ── Item list (non-scrollable — we drive it manually) ──
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false),
                child: ListView.builder(
                  controller: _ctrl,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                      vertical: (_itemH * 2)), // 2-item top/bottom padding
                  itemCount: widget.itemCount,
                  itemExtent: _itemH,
                  itemBuilder: (_, i) {
                    final isSel = i == _current;
                    return GestureDetector(
                      onTap: () => _select(i),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          color: isSel
                              ? widget.selectedColor
                              : widget.textColor.withOpacity(0.35),
                          fontSize: isSel ? 17 : 14,
                          fontWeight: isSel
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: Text(widget.itemLabel(i)),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Selection highlight lines ──────────────────
              IgnorePointer(
                child: Center(
                  child: Container(
                    height: _itemH,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                            color: widget.dividerColor, width: 1),
                        bottom: BorderSide(
                            color: widget.dividerColor, width: 1),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChecklistItem {
  final String id;
  String text;
  bool isChecked;
  // Per-item formatting
  bool isBold;
  bool isItalic;
  bool isUnderline;
  Color? textColor;
  Color? highlightColor;

  ChecklistItem({
    String? id,
    this.text = '',
    this.isChecked = false,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.textColor,
    this.highlightColor,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();
}

class ChecklistWidget extends StatefulWidget {
  final List<ChecklistItem> items;
  final VoidCallback onChanged;
  final Color textColor;
  final Color hintColor;
  final Color checkColor;
  final Color borderColor;
  final double fontSize;
  // Called when focused item changes — null means no checklist item focused
  final ValueChanged<ChecklistItem?>? onFocusedItemChanged;

  const ChecklistWidget({
    super.key,
    required this.items,
    required this.onChanged,
    this.textColor = Colors.white,
    this.hintColor = Colors.white38,
    this.checkColor = const Color(0xFF54C5F8),
    this.borderColor = Colors.white38,
    this.fontSize = 15,
    this.onFocusedItemChanged,
  });

  @override
  State<ChecklistWidget> createState() => _ChecklistWidgetState();
}

class _ChecklistWidgetState extends State<ChecklistWidget> {
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, FocusNode> _nodes = {};
  String? _focusedId;

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      _ensureControllers(item);
    }
  }

  void _ensureControllers(ChecklistItem item) {
    if (!_ctrls.containsKey(item.id)) {
      final ctrl = TextEditingController(text: item.text);
      ctrl.addListener(() {
        item.text = ctrl.text;
        widget.onChanged();
      });
      _ctrls[item.id] = ctrl;
    }
    if (!_nodes.containsKey(item.id)) {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          _focusedId = item.id;
          widget.onFocusedItemChanged?.call(item);
        }
        // REMOVED the else block entirely
        // Never call onFocusedItemChanged(null) — parent keeps last focused item
        // until a text block explicitly takes focus
      });
      _nodes[item.id] = node;
    }
  }

  void _cleanup() {
    final ids = widget.items.map((e) => e.id).toSet();
    for (final id in _ctrls.keys.toList()) {
      if (!ids.contains(id)) {
        _ctrls.remove(id)?.dispose();
      }
    }
    for (final id in _nodes.keys.toList()) {
      if (!ids.contains(id)) {
        _nodes.remove(id)?.dispose();
      }
    }
  }

  void _addItem(int afterIndex) {
    final newItem = ChecklistItem(); // always default formatting
    if (afterIndex < 0 || afterIndex >= widget.items.length) {
      widget.items.add(newItem);
    } else {
      widget.items.insert(afterIndex + 1, newItem);
    }
    _ensureControllers(newItem);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes[newItem.id]?.requestFocus();
    });
    widget.onChanged();
  }

  void _removeItem(int index) {
    if (widget.items.isEmpty) return;
    final item = widget.items[index];
    final prevItem = index > 0 ? widget.items[index - 1] : null;

    _ctrls.remove(item.id)?.dispose();
    _nodes.remove(item.id)?.dispose();
    widget.items.removeAt(index);

    if (widget.items.isEmpty) {
      widget.onFocusedItemChanged?.call(null);
      setState(() {});
      widget.onChanged();
      return;
    }

    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && prevItem != null) {
        _nodes[prevItem.id]?.requestFocus();
      }
    });
    widget.onChanged();
  }

  /// Called from parent to apply formatting to the focused item
  void applyFormatting({
    bool? bold,
    bool? italic,
    bool? underline,
    Color? textColor,
    bool clearColor = false,
    Color? highlight,
    bool clearHighlight = false,
  }) {
    if (_focusedId == null) return;
    final item = widget.items.firstWhere(
      (i) => i.id == _focusedId,
      orElse: () => widget.items.first,
    );
    setState(() {
      if (bold != null) item.isBold = bold;
      if (italic != null) item.isItalic = italic;
      if (underline != null) item.isUnderline = underline;
      if (clearColor) {
        item.textColor = null;
      } else if (textColor != null) {
        item.textColor = textColor;
      }
      if (clearHighlight) {
        item.highlightColor = null;
      } else if (highlight != null) {
        item.highlightColor = highlight;
      }
    });
    widget.onChanged();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    for (final n in _nodes.values) n.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _cleanup();
    for (final item in widget.items) {
      _ensureControllers(item);
      // Keep controller text in sync if item text changed externally
      final ctrl = _ctrls[item.id]!;
      if (ctrl.text != item.text) {
        ctrl.text = item.text;
      }
    }

    if (widget.items.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.items.length, (i) {
        final item = widget.items[i];
        final ctrl = _ctrls[item.id]!;
        final node = _nodes[item.id]!;
        final isFocused = _focusedId == item.id;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox
              GestureDetector(
                onTap: () {
                  setState(() => item.isChecked = !item.isChecked);
                  widget.onChanged();
                },
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: item.isChecked ? widget.checkColor : Colors.transparent,
                    border: Border.all(
                      color: item.isChecked ? widget.checkColor : widget.borderColor,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: item.isChecked
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ),

              // Text field
              Expanded(
                child: KeyboardListener(
                  focusNode: FocusNode(skipTraversal: true),
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                        _addItem(i);
                      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
                        if (ctrl.text.isEmpty && widget.items.length > 1) {
                          _removeItem(i);
                        }
                      }
                    }
                  },
                  child: Container(
                    color: item.highlightColor?.withOpacity(0.25),
                    child: TextField(
                      controller: ctrl,
                      focusNode: node,
                      style: TextStyle(
                        color: item.textColor ?? widget.textColor,
                        fontSize: widget.fontSize,
                        height: 1.5,
                        fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
                        fontStyle: item.isItalic ? FontStyle.italic : FontStyle.normal,
                        decoration: item.isChecked
                            ? TextDecoration.lineThrough
                            : item.isUnderline
                                ? TextDecoration.underline
                                : TextDecoration.none,
                        decorationColor: (item.textColor ?? widget.textColor).withOpacity(0.7),
                      ),
                      decoration: InputDecoration(
                        hintText: isFocused ? 'List item' : '',
                        hintStyle: TextStyle(
                          color: widget.hintColor,
                          fontSize: widget.fontSize,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.done,
                    ),
                  ),
                ),
              ),

              // Delete
              GestureDetector(
                onTap: () => _removeItem(i),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.close,
                    color: widget.textColor.withOpacity(0.3),
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}